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
- **Per-node disk/hardware:** set `install_disk` and `interface` per node in the
  `nodes` map. `network-config.yaml` holds only cluster-wide bits (nameservers);
  the NIC name and the control-plane VIP are layered in per node (the VIP only on
  `controlplane` nodes). Hostnames come from DHCP — the provider emits a default
  `HostnameConfig` (`auto: stable`), which conflicts with a static
  `machine.network.hostname`, so we don't set one.
- **kubeconfig:** fetch with `talosctl kubeconfig` — intentionally not managed here
  (the `talos_cluster_kubeconfig` resource would write credentials into state).

## Dry-run against a live node

Terraform has no plan-time diff against a node (the apply resource's
`Read` is a no-op), so non-reboot changes otherwise apply silently. To
see what an apply *would* change, dump the provider's exact render and
dry-run it with talosctl, which layers the per-node patch the same way
the provider does:

```sh
# cluster untouched — only renders the dump files
terraform apply -target=terraform_data.dump -var dump_dir=./dryrun
talosctl -n <ip> apply-config --dry-run \
  -f ./dryrun/<node>.yaml --config-patch @./dryrun/<node>.patch.yaml
```

Prefer this over `rendered/` from `talosctl gen`: the provider bundles
its own Talos machinery (currently v1.13.0) and may emit different
schema/defaults than your local talosctl. `dryrun/` is gitignored — the
dumped base config holds secrets.

## Notes & cautions

- **First apply on the live cluster:** there is nothing to import — this is a
  push/action resource (its `Read` is a no-op, so Terraform never reads node state
  back). An empty state means `plan` shows the resource as "to create"; applying
  just pushes the config once, which Talos reconciles idempotently. The default
  `apply_mode = "staged_if_needing_reboot"` means Terraform never reboots a
  node on its own: it applies immediately if no reboot is needed, otherwise
  stages the change for your next manual reboot. Check the `resolved_apply_mode`
  output — if it resolved to `staged`, a reboot-requiring difference existed
  (i.e. the rendered config doesn't yet perfectly match the running node). Valid
  modes: `auto` (default), `reboot`, `no_reboot`, `staged`,
  `staged_if_needing_reboot`.
- **Talos upgrades are out-of-band.** Setting `machine.install.image` tracks the
  intended version but does not upgrade a running node — the provider has no upgrade
  resource. Bump `talos_version`, `apply` to record intent, then run
  `talosctl upgrade --image …` to actually upgrade.
- **Serial updates.** `for_each` applies to all nodes in parallel; with the
  default staged mode that's safe (an apply never reboots). If you switch to
  `apply_mode = reboot`/`auto`, serialize with `terraform apply -parallelism=1`
  (or `-target` one node at a time) so you don't reboot every control-plane node
  at once. OS version bumps are already serial — run `talosctl upgrade` node by
  node.
- **No bootstrap resource.** The cluster is already bootstrapped; `talos_machine_bootstrap`
  is deliberately omitted (it is a one-time operation for new clusters).
- **install-disk.yaml is excluded** from the shared patches — the install disk
  is set per node from the `nodes` map. The old `wipe`/`diskSelector` settings
  are intentionally dropped so a re-apply can't wipe a running node.
