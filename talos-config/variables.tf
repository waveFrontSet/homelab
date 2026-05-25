variable "cluster_name" {
  type    = string
  default = "trinity-processor"
}

variable "cluster_endpoint" {
  type    = string
  default = "https://192.168.2.19:6443"
}

variable "talos_version" {
  description = "Talos version contract and installer image tag, e.g. v1.9.5. Bump this to upgrade."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to render into the machine config (null = provider default)."
  type        = string
  default     = null
}

variable "talos_schematic_id" {
  description = "Image Factory schematic ID for bare-metal.yaml. Regenerate with: curl -X POST --data-binary @../bare-metal.yaml https://factory.talos.dev/schematics"
  type        = string
}

variable "nodes" {
  description = "Cluster nodes keyed by name. install_disk and interface handle per-node hardware differences."
  type = map(object({
    ip           = string
    install_disk = string
    interface    = optional(string, "enp1s0")
    machine_type = optional(string, "controlplane")
  }))

  validation {
    condition     = alltrue([for n in var.nodes : contains(["controlplane", "worker"], n.machine_type)])
    error_message = "machine_type must be \"controlplane\" or \"worker\"."
  }
}

variable "secrets_file" {
  description = "Path to the SOPS-encrypted Talos secrets bundle."
  type        = string
  default     = "secrets.sops.yaml"
}

variable "talosconfig_path" {
  description = "Path to a talosconfig holding admin client credentials. Used only to authenticate to nodes; never written to state."
  type        = string
  default     = "~/.talos/config"
}

variable "apply_mode" {
  description = "Apply mode: auto, reboot, no_reboot, staged, or staged_if_needing_reboot. The default never reboots a node on its own — reboot-requiring changes are staged for your next manual reboot."
  type        = string
  default     = "staged_if_needing_reboot"
}

variable "dump_dir" {
  description = "If set, terraform_data.dump writes each node's exact pre-apply config + per-node patch here so you can run `talosctl apply-config --dry-run` against the live node first. Leave null for normal applies. Render-only (cluster untouched): terraform apply -target=terraform_data.dump -var dump_dir=./dryrun"
  type        = string
  default     = null
}
