output "machine_configuration_hashes" {
  description = "Per-node hash of the applied machine configuration."
  value       = { for k, r in talos_machine_configuration_apply.this : k => r.machine_configuration_hash }
}

output "schematic_id" {
  value = talos_image_factory_schematic.this.id
}

output "extensions" {
  value = data.talos_image_factory_extensions_versions.this.extensions_info
}

