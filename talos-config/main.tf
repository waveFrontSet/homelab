locals {
  # In this cluster the control-plane VIP is the host of the cluster endpoint.
  cluster_vip = regex("//([^:/]+)", var.cluster_endpoint)[0]

  # Per-node overrides layered on top of the shared, machine-type-wide config.
  # Kept as a named local so the dry-run dump renders the exact same patch.
  node_patches = {
    for k, n in var.nodes : k => yamlencode({
      machine = {
        install = {
          disk  = n.install_disk
          image = local.installer_image
        }
        # Hostnames come from DHCP; the provider's default HostnameConfig
        # (auto: stable) conflicts with a static machine.network.hostname.
        network = {
          interfaces = [merge(
            { interface = n.interface, dhcp = true },
            n.machine_type == "controlplane" ? { vip = { ip = local.cluster_vip } } : {},
          )]
        }
      }
    })
  }
}

# Render a machine config per machine_type present. Ephemeral: never in state.
ephemeral "talos_machine_configuration" "this" {
  for_each = toset([for n in var.nodes : n.machine_type])

  cluster_name       = var.cluster_name
  cluster_endpoint   = var.cluster_endpoint
  machine_type       = each.key
  machine_secrets    = local.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  config_patches     = local.common_patches
}

# Apply config to each node. Secrets travel only through the write-only (_wo)
# arguments, so the state holds just node metadata and a config hash.
resource "talos_machine_configuration_apply" "this" {
  for_each = var.nodes

  node = each.value.ip

  client_configuration_wo        = local.client_configuration
  machine_configuration_input_wo = ephemeral.talos_machine_configuration.this[each.value.machine_type].machine_configuration

  apply_mode     = var.apply_mode
  config_patches = [local.node_patches[each.key]]
}

# Optional, off by default. When var.dump_dir is set, writes each node's exact
# pre-apply inputs (provider-rendered base + per-node patch) to disk so you can
# `talosctl apply-config --dry-run` against the live node BEFORE applying. The
# secret-bearing config travels through the provisioner environment only —
# nothing rendered here lands in state. Render-only (cluster untouched):
#   terraform apply -target=terraform_data.dump -var dump_dir=./dryrun
resource "terraform_data" "dump" {
  for_each = var.dump_dir == null ? {} : var.nodes

  # Re-dump when any rendering input changes (all non-secret).
  triggers_replace = [
    local.node_patches[each.key],
    var.talos_version,
    coalesce(var.kubernetes_version, "default"),
    join("\n", local.common_patches),
  ]

  provisioner "local-exec" {
    environment = {
      BASE  = ephemeral.talos_machine_configuration.this[each.value.machine_type].machine_configuration
      PATCH = local.node_patches[each.key]
      DIR   = var.dump_dir
      NAME  = each.key
      IP    = each.value.ip
    }
    command = <<-EOT
      set -eu
      umask 077
      mkdir -p "$DIR"
      printf '%s' "$BASE"  > "$DIR/$NAME.yaml"
      printf '%s' "$PATCH" > "$DIR/$NAME.patch.yaml"
      echo "dry-run: talosctl -n $IP apply-config --dry-run -f $DIR/$NAME.yaml --config-patch @$DIR/$NAME.patch.yaml"
    EOT
  }
}
