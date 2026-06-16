terraform {
  required_version = ">= 1.9.0"

  cloud {
    organization = "steve-weaver-demo-org"
  }

  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.28" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.38" }
    vault      = { source = "hashicorp/vault", version = "~> 4.0" }
    random     = { source = "hashicorp/random", version = "~> 3.5" }
    time       = { source = "hashicorp/time", version = "~> 0.9" }
    tls        = { source = "hashicorp/tls", version = "~> 4.0" }
    cloudinit  = { source = "hashicorp/cloudinit", version = "~> 2.3" }
    null       = { source = "hashicorp/null", version = "~> 3.2" }
  }
}

# Dynamic credentials: HCP Terraform injects short-lived AWS credentials via
# workspace env vars (TFC_AWS_PROVIDER_AUTH, TFC_AWS_RUN_ROLE_ARN). No static
# keys, no assume_role block needed here.
provider "aws" {
  region = var.region

  default_tags { tags = var.default_tags }
}

provider "kubernetes" {
  host                   = module.cluster.cluster_url
  cluster_ca_certificate = module.cluster.cluster_ca
  token                  = module.auth.token
}

# Dynamic credentials: HCP Terraform injects the Vault address/namespace and
# a short-lived JWT via the tfc_vault_dynamic_credentials variable. No static
# Vault token, no auth_login_jwt block needed here.
provider "vault" {
  skip_child_token = true
  address          = var.tfc_vault_dynamic_credentials.default.address
  namespace        = var.tfc_vault_dynamic_credentials.default.namespace

  auth_login_token_file {
    filename = var.tfc_vault_dynamic_credentials.default.token_filename
  }
}

provider "random" {}
provider "time" {}
provider "tls" {}
provider "cloudinit" {}
provider "null" {}
