# Ep4 bridge: VPC and subnets consumed by the ep4-vm-prod workspace via remote state.
output "network" {
  description = "VPC and subnet IDs for downstream workspaces (consumed by Ep4)"
  value = {
    vpc_id            = module.network.vpc_id
    public_subnet_ids = module.network.public_subnet_ids
  }
}

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
