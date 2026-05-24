# Talos cluster via Terraform

Manages the Talos machine configuration of an **already-running** cluster with
the [siderolabs/talos](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs)
provider. Tracks the installed Talos version, applies config changes, and
handles per-node hardware differences (install disk).

## Design

- **No secrets in state.** The secrets bundle is decrypted with the ephemeral
  `carlpett/sops` resource and fed into the ephemeral `talos_machine_configuration`
  resource; the rendered config and client credentials reach the apply resource
  only through write-only (`*_wo`) arguments. State holds node IPs, apply mode,
  and a config hash — nothing sensitive. (Requires Terraform ≥ 1.11.)
- **Secret provider = your SOPS bundle.** `../secrets.sops.yaml` stays the source
  of truth; this module never regenerates secrets.
- **Admin client cert** comes from your local `~/.talos/config` (used only to
  authenticate; never persisted).
- **State backend = MinIO** on the NAS via the `s3` backend with native locking.

## One-time setup

1. **MinIO:** create the bucket named in `backend.hcl` (default `terraform-state`).
2. **Backend config:** `cp backend.hcl.example backend.hcl` and set the `endpoints.s3`
   URL and bucket. `backend.hcl` is gitignored.
3. **Variables:** `cp terraform.tfvars.example terraform.tfvars` and fill in
   `talos_version`, `talos_schematic_id`, and the `nodes` map (one entry per node
   with its `ip` and `install_disk`).
4. **Environment:**

   ```sh
   export SOPS_AGE_KEY_FILE=../age.key            # decrypt the secrets bundle
   export AWS_ACCESS_KEY_ID=<minio-access-key>     # MinIO credentials
   export AWS_SECRET_ACCESS_KEY=<minio-secret-key>
   ```

5. **Init:**

   ```sh
   terraform init -backend-config=backend.hcl
   ```

## Day-to-day

```sh
terraform plan      # review changes — watch machine_configuration_hash diffs
terraform apply
```

- **Upgrade Talos:** bump `talos_version` (and re-POST `bare-metal.yaml` to the
  factory if extensions changed, updating `talos_schematic_id`), then apply.
- **Per-node disk/hardware:** set `install_disk` (and optional `hostname`) per node
  in the `nodes` map.
- **kubeconfig:** fetch with `talosctl kubeconfig` — intentionally not managed here
  (the `talos_cluster_kubeconfig` resource would write credentials into state).

## Notes & cautions

- **First apply on the live cluster:** the rendered config should already match
  the running nodes. Review the plan carefully; consider `apply_mode = "try"`
  (auto-reverts if not made permanent) or `"staged"` (applies on next reboot)
  for the first run.
- **No bootstrap resource.** The cluster is already bootstrapped; `talos_machine_bootstrap`
  is deliberately omitted (it is a one-time operation for new clusters).
- **install-disk.yaml is excluded** from the shared patches — the install disk
  is set per node from the `nodes` map. The old `wipe`/`diskSelector` settings
  are intentionally dropped so a re-apply can't wipe a running node.
