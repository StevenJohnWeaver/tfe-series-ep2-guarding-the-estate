terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

variable "environment" {
  description = "Deployment environment label (dev, staging, prod)"
  type        = string
}

data "vault_kv_secret_v2" "app_config" {
  mount = "secret"
  name  = "ep2-demo/${var.environment}/app-config"
}

output "secret_path" {
  description = "Vault KV path where the app config secret was read from"
  value       = "secret/ep2-demo/${var.environment}/app-config"
}

output "secret_version" {
  description = "Vault KV version retrieved (confirms dynamic read, not cached)"
  value       = data.vault_kv_secret_v2.app_config.version
}
