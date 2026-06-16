terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 6.28" }
  }
}

variable "cluster_name" { type = string }

# Token is valid for ~15 minutes — approve the plan promptly so apply
# doesn't run against a stale token.
data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

output "token" {
  value     = data.aws_eks_cluster_auth.this.token
  sensitive = true
}
