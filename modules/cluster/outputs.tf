output "cluster_url" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca" {
  value = base64decode(module.eks.cluster_certificate_authority_data)
}

# Pass the name too; we’ll use it to fetch a token elsewhere.
output "cluster_name" {
  value = module.eks.cluster_name
}
