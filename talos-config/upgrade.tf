# In-place Talos upgrades. The provider has no upgrade resource (config-apply
# does NOT trigger an install), so version/extension changes are driven here via
# `talosctl upgrade`. One instance per node; each is idempotent (skips a node
# already on target) and gates on cluster health before returning. Run applies
# with `-parallelism=1` (see README) so the instances execute one node at a time
# and etcd quorum on the control plane is never at risk.
resource "terraform_data" "upgrade" {
  for_each = var.nodes

  depends_on = [talos_machine_configuration_apply.this]

  triggers_replace = [
    talos_image_factory_schematic.this.id,
    var.talos_version,
  ]

  provisioner "local-exec" {
    environment = {
      IP        = each.value.ip
      IMAGE     = local.installer_image
      VERSION   = var.talos_version
      SCHEMATIC = talos_image_factory_schematic.this.id
    }
    command = <<-EOT
      set -eu
      cur_ver=$(talosctl version -n "$IP" --json | jq -r .version.tag)
      cur_sch=$(talosctl get extensions -n "$IP" -o json \
        | jq -r 'select(.spec.metadata.name=="schematic").spec.metadata.version')
      if [ "$cur_ver" = "$VERSION" ] && [ "$cur_sch" = "$SCHEMATIC" ]; then
        echo "==> $IP already on $VERSION ($SCHEMATIC) — skipping"
        exit 0
      fi
      talosctl upgrade -n "$IP" --image "$IMAGE" --timeout 30m
      talosctl health -n "$IP" --wait-timeout 60m
    EOT
  }
}

locals {
  k8s_upgrade_node = sort([for n in var.nodes : n.ip if n.machine_type == "controlplane"])[0]
}

resource "terraform_data" "upgrade_k8s" {
  count = var.kubernetes_version == null ? 0 : 1

  depends_on = [terraform_data.upgrade]

  triggers_replace = [var.kubernetes_version]

  provisioner "local-exec" {
    environment = {
      NODE    = local.k8s_upgrade_node
      VERSION = var.kubernetes_version
    }
    command = <<-EOT
      set -eu
      talosctl upgrade-k8s -n "$NODE" --to "$VERSION"
    EOT
  }
}
