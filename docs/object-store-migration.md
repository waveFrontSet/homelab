# MinIO to Garage migration

## Decision

Use Garage for the in-cluster S3 backup endpoint. This is a deliberately
small, single-node deployment on the existing NAS-backed NFS storage; it
replaces the current single-node MinIO fault domain and does not add pretend
HA.

### Garage

- **Pros:** established S3 core; path-style S3, SigV4, multipart, and the
  required list/get/put/delete operations; one server and two bucket-scoped
  keys match this workload.
- **Cons:** AGPLv3 and no bucket versioning, object lock, or IAM policy API.

### RustFS

- **Pros:** Apache-2.0, a broader S3/IAM/versioning/object-lock feature set,
  and a more MinIO-like console.
- **Cons:** more than this workload needs; its Helm defaults to a distributed
  4-pod/16-PVC topology, while its documentation still describes pre-1.0
  releases and defaults to `latest`.

Garage's missing versioning/object lock features do not block CNPG Barman or
Longhorn. The independent S3 copy, when selected, is where immutable retention
belongs.

## What this change deploys

`infrastructure/garage/` defines one Garage StatefulSet, a 150 GiB NAS-backed
`nfs` PVC, internal S3 (`garage.garage:3900`) and admin services, and an
idempotent bootstrap Job. The job creates:

- `cnpg-backups` with a CNPG-only read/write key;
- `longhorn-backups` with a Longhorn-only read/write key.

The S3 API has no Ingress. The Garage administrative endpoint is only
ClusterIP and is used by the bootstrap Job. Garage uses SQLite metadata with
`metadata_fsync` and `data_fsync` enabled plus six-hour metadata snapshots,
favoring recovery safety over throughput.

## Cutover

1. Reconcile the `garage` Flux Kustomization and wait for its StatefulSet and
   `garage-bootstrap` Job to be healthy.
2. Run the validation checklist below. Do not change CNPG or Longhorn until it
   passes.
3. Reconcile the commit that switches CNPG and Longhorn endpoints/credentials
   to Garage. The existing MinIO Kustomization stays enabled, so old backups
   remain available.
4. Trigger or await a successful CNPG base backup, confirm WAL archiving, and
   create a fresh Longhorn backup.
5. Run the isolated CNPG restore in [the recovery playbook](cnpg-recovery.md).
   Record the result.
6. Keep MinIO in place until all checks pass. Removing `infrastructure/minio/`
   and its Flux Kustomization is a separate reviewed change.

No backup objects are copied. The fresh backup on Garage is the acceptance
point; MinIO remains the recovery source for the old retention window until
retirement.

## Validation checklist

Run after Flux has created Garage, from an ephemeral pod using the CNPG key
against the empty `cnpg-backups` bucket:

```sh
aws --endpoint-url http://garage.garage:3900 --region garage \
  s3api list-objects-v2 --bucket cnpg-backups
aws --endpoint-url http://garage.garage:3900 --region garage \
  s3 cp /etc/hosts s3://cnpg-backups/validation/hosts
aws --endpoint-url http://garage.garage:3900 --region garage \
  s3 cp s3://cnpg-backups/validation/hosts /tmp/hosts
cmp /etc/hosts /tmp/hosts
aws --endpoint-url http://garage.garage:3900 --region garage s3 rm s3://cnpg-backups/validation/hosts
```

Also test a multipart upload (`aws s3 cp` of a file larger than the CLI
multipart threshold), list it, download it, compare its checksum, and delete
it. Repeat the object operations using the Longhorn key and
`longhorn-backups`. Confirm each key is denied access to the other bucket.

Record the date, deployed Garage image digest, S3 endpoint, region `garage`,
path-style addressing, and each operation/result in the quarterly drill record.
The repository does not claim this validation has occurred until the operator
records it.

## Rollback

If either CNPG or Longhorn cannot access Garage, restore its existing MinIO
endpoint/secret in Git and reconcile it. Because no old backup objects were
moved and MinIO remains deployed, this changes only the active target. Do not
delete Garage data during rollback; keep it for diagnosis.

## NAS-loss protection is deferred

Garage and MinIO both use the same NAS storage. They cannot recover NAS loss,
deletion, or a site-wide incident. A managed S3 provider is intentionally not
selected yet. Once it is selected, add a daily append-only `rclone copy` job
with a remote credential that cannot delete objects, enable provider-side
versioning or object lock when available, and test a CNPG restore from that
remote copy. Use `copy`, never `sync`.
