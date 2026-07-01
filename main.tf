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

# Buffer for EKS access entry propagation. On a fresh cluster create/replace,
# the cluster_creator access entry takes a moment to propagate through the EKS
# control plane. The token can be generated freely (module.auth has no blocking
# depends_on), but Kubernetes resource creation must not start until the entry
# is enforced — so the sleep gates module.app, not module.auth. This also
# avoids deferring data.aws_eks_cluster_auth during plan when cluster resources
# change, which previously caused system:anonymous plan-phase failures.
resource "time_sleep" "eks_access_entry_propagation" {
  depends_on      = [module.cluster]
  create_duration = "30s"
}

module "auth" {
  source = "./modules/app_auth"

  cluster_name = module.cluster.cluster_name
}

module "app" {
  source = "./modules/app"

  providers = {
    kubernetes = kubernetes
  }

  depends_on = [time_sleep.eks_access_entry_propagation]
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
