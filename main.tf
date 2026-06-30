module "network" {
  source   = "./modules/network"
  name     = var.cluster_name
  vpc_cidr = var.vpc_cidr
}

module "cluster" {
  source = "./modules/cluster"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.public_subnet_ids
}

# Buffer for EKS access entry propagation. module.auth's data source only
# depends on cluster_name — it doesn't transitively wait for the
# cluster_creator access entry (a sibling resource inside module.cluster) to
# finish propagating through the EKS control plane. Without this, a fresh
# cluster create/replace can hand out a Kubernetes auth token for an access
# entry that isn't enforced yet, and module.app fails with Unauthorized.
resource "time_sleep" "eks_access_entry_propagation" {
  depends_on      = [module.cluster]
  create_duration = "30s"
}

module "auth" {
  source = "./modules/app_auth"

  cluster_name = module.cluster.cluster_name

  depends_on = [time_sleep.eks_access_entry_propagation]
}

module "app" {
  source = "./modules/app"

  providers = {
    kubernetes = kubernetes
  }
}

# Zero Static Secrets — Vault dynamic credentials demonstration.
# Reads a KV secret via the workspace's Vault dynamic credentials.
module "secrets" {
  source = "./modules/secrets"

  providers = {
    vault = vault
  }

  environment = var.environment
}
