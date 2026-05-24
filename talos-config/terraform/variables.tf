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
  description = "Cluster nodes keyed by name. install_disk handles per-node hardware differences."
  type = map(object({
    ip           = string
    install_disk = string
    machine_type = optional(string, "controlplane")
    hostname     = optional(string)
  }))

  validation {
    condition     = alltrue([for n in var.nodes : contains(["controlplane", "worker"], n.machine_type)])
    error_message = "machine_type must be \"controlplane\" or \"worker\"."
  }
}

variable "secrets_file" {
  description = "Path to the SOPS-encrypted Talos secrets bundle."
  type        = string
  default     = "../secrets.sops.yaml"
}

variable "talosconfig_path" {
  description = "Path to a talosconfig holding admin client credentials. Used only to authenticate to nodes; never written to state."
  type        = string
  default     = "~/.talos/config"
}

variable "apply_mode" {
  description = "Apply mode: auto, reboot, no_reboot, staged, or try."
  type        = string
  default     = "auto"
}
