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

  apply_mode = var.apply_mode

  # Per-node overrides layered on top of the shared config.
  config_patches = [
    yamlencode({
      machine = merge(
        {
          install = {
            disk  = each.value.install_disk
            image = local.installer_image
          }
        },
        each.value.hostname == null ? {} : { network = { hostname = each.value.hostname } }
      )
    })
  ]
}
