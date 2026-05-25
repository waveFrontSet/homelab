# Decrypt the Talos secrets bundle at apply time. As an ephemeral resource,
# nothing it produces is ever written to state or plan files.
ephemeral "sops_file" "secrets" {
  source_file = var.secrets_file
  input_type  = "yaml"
}

data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  exact_filters = {
    names = [
      "siderolabs/i915",
      "siderolabs/iscsi-tools",
      "siderolabs/util-linux-tools",
    ]
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info[*].name
        }
      }
    }
  )
}

locals {
  raw = yamldecode(ephemeral.sops_file.secrets.raw)

  # The bundle uses Talos' on-disk field names (crt, k8saggregator, ...), which
  # differ from the provider's machine_secrets schema (cert, k8s_aggregator, ...).
  machine_secrets = {
    certs = {
      etcd               = { cert = local.raw.certs.etcd.crt, key = local.raw.certs.etcd.key }
      k8s                = { cert = local.raw.certs.k8s.crt, key = local.raw.certs.k8s.key }
      k8s_aggregator     = { cert = local.raw.certs.k8saggregator.crt, key = local.raw.certs.k8saggregator.key }
      k8s_serviceaccount = { key = local.raw.certs.k8sserviceaccount.key }
      os                 = { cert = local.raw.certs.os.crt, key = local.raw.certs.os.key }
    }
    cluster = {
      id     = local.raw.cluster.id
      secret = local.raw.cluster.secret
    }
    secrets = {
      bootstrap_token             = local.raw.secrets.bootstraptoken
      secretbox_encryption_secret = local.raw.secrets.secretboxencryptionsecret
      aescbc_encryption_secret    = try(local.raw.secrets.aescbcencryptionsecret, null)
    }
    trustdinfo = {
      token = local.raw.trustdinfo.token
    }
  }

  # Admin client credentials, read from the local talosconfig. Consumed only by
  # the write-only client_configuration_wo argument, so it stays out of state.
  talosconfig = yamldecode(file(pathexpand(var.talosconfig_path)))
  talos_ctx   = local.talosconfig.contexts[local.talosconfig.context]
  client_configuration = sensitive({
    ca_certificate     = local.talos_ctx.ca
    client_certificate = local.talos_ctx.crt
    client_key         = local.talos_ctx.key
  })

  # Factory installer image. Bumping var.talos_version here is the tracked upgrade.
  installer_image = "factory.talos.dev/metal-installer/${talos_image_factory_schematic.this.id}:${var.talos_version}"

  # Shared patches: every patches/*.yaml except the per-node install disk.
  common_patches = [
    for f in fileset("${path.module}/patches", "*.yaml") :
    file("${path.module}/patches/${f}") if f != "install-disk.yaml"
  ]
}
