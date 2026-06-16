# Ep2→Ep5 bridge: stable infrastructure facts for the Ansible handshake in Episode 5.
output "config_facts" {
  description = "Stable infrastructure metadata for downstream configuration (AAP, Ep5)"
  value = {
    cluster_endpoint = module.cluster.cluster_url
    environment      = var.environment
    region           = var.region
    vault_secret_ver = module.secrets.secret_version
  }
}
