# CNPG recovery playbook

This restores a **new** CNPG cluster from the physical backups and WAL archive
in `cnpg-backups`. CNPG does not restore in place. Do not delete the source
cluster, change application connections, or remove MinIO/Garage until the
restored cluster has passed validation.

> **Scope:** Local recovery requires the NAS-backed S3 service to be healthy.
> A NAS-loss recovery requires the deferred independent S3 copy; it is not
> implemented yet.

## Record the incident

1. Record the incident and requested recovery point in UTC, including an
   offset: `2026-04-02T10:14:00Z`.
2. Freeze writes in affected applications. Scale their workloads to zero or put
   them in maintenance mode. Do not stop the object store.
3. Check the source archive before changing anything:

   ```sh
   kubectl -n cnpg-cluster get cluster cnpg-cluster -o yaml
   kubectl -n cnpg-cluster get backup
   kubectl -n cnpg-cluster get scheduledbackup
   kubectl -n garage get pods,job,pvc
   ```

   Confirm the last successful base backup and that WAL archiving was
   successful after the desired restore point. The weekly base backup is not
   the RPO: archived WAL is.

4. Suspend reconciliation only when performing a production replacement; do
   **not** suspend it for the isolated rehearsal:

   ```sh
   flux suspend kustomization cnpg-extras -n flux-system
   ```

## Restore into an isolated cluster first

Create a temporary manifest outside Flux (for example
`/tmp/cnpg-restore.yaml`). It must point at the S3 service which currently
holds the archive. The credentials must be a copy of the active CNPG S3 secret
in `cnpg-cluster`; do not put credentials in this file.

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cnpg-restore
  namespace: cnpg-cluster
spec:
  instances: 1
  storage:
    size: 20Gi
    storageClass: longhorn
  superuserSecret:
    name: cnpg-superuser-password
  bootstrap:
    recovery:
      source: source
      # Omit recoveryTarget for the latest consistent restore.
      # recoveryTarget:
      #   targetTime: "2026-04-02T10:14:00Z"
  externalClusters:
    - name: source
      barmanObjectStore:
        destinationPath: s3://cnpg-backups/
        endpointURL: http://garage.garage:3900
        serverName: cnpg-cluster
        s3Credentials:
          accessKeyId:
            name: cnpg-garage-secret
            key: AWS_ACCESS_KEY_ID
          secretAccessKey:
            name: cnpg-garage-secret
            key: AWS_SECRET_ACCESS_KEY
          region:
            name: cnpg-garage-secret
            key: AWS_REGION
        wal:
          maxParallel: 4
```

For point-in-time recovery, set `recoveryTarget.targetTime` with an explicit
UTC offset. CNPG chooses the newest base backup completed before that time. Set
`backupID` only when deliberately selecting a known Barman backup. Do not
select the incident timestamp itself: choose a verified safe point immediately
before the bad write.

Apply and watch recovery:

```sh
kubectl apply -f /tmp/cnpg-restore.yaml
kubectl -n cnpg-cluster get cluster cnpg-restore -w
kubectl -n cnpg-cluster get pods -l cnpg.io/cluster=cnpg-restore -w
kubectl -n cnpg-cluster wait --for=condition=Ready cluster/cnpg-restore \
  --timeout=2h
```

Recovery is complete only after the Cluster is Ready and accepts writes. A
healthy pod alone can still be replaying WAL.

## Validate before any cutover

Run these against the recovered primary:

```sh
POD=$(kubectl -n cnpg-cluster get pod \
  -l cnpg.io/cluster=cnpg-restore,role=primary \
  -o jsonpath='{.items[0].metadata.name}')
kubectl -n cnpg-cluster exec "$POD" -- \
  psql -U postgres -d postgres -c '\l'
kubectl -n cnpg-cluster exec "$POD" -- \
  psql -U postgres -d postgres -c '\du'
kubectl -n cnpg-cluster exec "$POD" -- \
  psql -U postgres -d immichdb \
  -c "SELECT extname FROM pg_extension WHERE extname IN \
  ('vector', 'cube', 'earthdistance') ORDER BY 1;"
```

Confirm every database exists and is reachable: `authentikdb`, `immichdb`,
`paperlessdb`, `mealiedb`, `blockydb`, and `scrapydb`. Check a known recent
record in each affected application, confirm the PITR boundary has the intended
result, and record the observed recovery point and elapsed time. Do not point
an application at `cnpg-restore`; it is only a rehearsal/validation target.

Remove the rehearsal after recording the result:

```sh
kubectl -n cnpg-cluster delete cluster cnpg-restore
```

## Production cutover

Only proceed after the isolated restore is accepted.

1. Keep writes frozen and `cnpg-extras` suspended.
2. Delete or otherwise isolate the failed `cnpg-cluster`; retain its PVCs until
   the replacement is proven.
3. Create a recovery Cluster named `cnpg-cluster`, using the same
   `bootstrap.recovery` and `externalClusters` source above. Its source
   `serverName` remains `cnpg-cluster` so it reads the original archive.
4. Before resuming backups, update the Git-managed
   `Cluster.spec.backup.barmanObjectStore.serverName` to a new, dated value
   such as `cnpg-cluster-recovered-20260402`. This is mandatory: reusing the
   source archive prefix can overwrite the only recovery source or trigger
   CNPG's empty-WAL-archive protection.
5. Restore the normal instance count, wait for the Cluster to be Ready, then
   resume Flux:

   ```sh
   flux resume kustomization cnpg-extras -n flux-system
   flux reconcile kustomization cnpg-extras -n flux-system --with-source
   ```

6. Verify the stable `cnpg-cluster-rw.cnpg-cluster.svc` and
   `cnpg-pooler-rw.cnpg-cluster.svc` services, then bring applications back one
   at a time: Authentik first (OIDC), then Immich, Paperless, Mealie, Blocky,
   and Scraper. Check each application writes successfully.
7. Take a new base backup and confirm a subsequent WAL archive before deleting
   any retained failed-cluster PVCs.

## Quarterly drill

Each quarter, run the isolated procedure above against the latest backup,
without suspending Flux or stopping applications. Record:

- drill date, base-backup ID, latest archived WAL time, and achieved RPO;
- start/end time and achieved RTO;
- result of all database, extension, role, and application-connectivity checks;
- any failure and the follow-up owner.

CNPG's native `barmanObjectStore` API used here is deprecated in operator
versions 1.26 and later. Migrate to the Barman Cloud plugin only after this
runbook is proven in a drill; do not combine that API migration with an
incident recovery.
