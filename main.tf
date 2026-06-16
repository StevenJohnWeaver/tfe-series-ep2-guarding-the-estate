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

module "auth" {
  source = "./modules/app_auth"

  cluster_name = module.cluster.cluster_name
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
