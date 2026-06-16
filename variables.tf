variable "region" { type = string }
variable "default_tags" { type = map(string) }
variable "cluster_name" { type = string }
variable "kubernetes_version" { type = string }
variable "vpc_cidr" { type = string }

variable "environment" {
  type        = string
  description = "Deployment environment label (dev, staging, prod)"
}

# Required by HCP Terraform when Vault dynamic credentials are enabled on
# this workspace. Values are injected automatically — do not set manually.
variable "tfc_vault_dynamic_credentials" {
  description = "HCP Terraform-injected Vault dynamic credentials configuration"
  type = object({
    default = object({
      token_filename = string
      address        = string
      namespace      = string
      ca_cert_file   = string
    })
    aliases = map(object({
      token_filename = string
      address        = string
      namespace      = string
      ca_cert_file   = string
    }))
  })
}
