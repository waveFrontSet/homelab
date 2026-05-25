# Non-sensitive: a SHA256 of each node's applied config, handy for spotting drift.
output "machine_configuration_hashes" {
  description = "Per-node hash of the applied machine configuration."
  value       = { for k, r in talos_machine_configuration_apply.this : k => r.machine_configuration_hash }
}
