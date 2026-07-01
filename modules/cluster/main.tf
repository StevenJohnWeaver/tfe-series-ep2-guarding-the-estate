terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.28" }
    random = { source = "hashicorp/random", version = "~> 3.5" }
  }
}

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  # Keep your existing constraint (or the exact version you had when it worked).
  # The key here is using the legacy inputs this runtime expects.
  version = "~> 21.0"

  # NOTE: Using 'name' here to match the module schema Stacks is resolving today.
  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version
  subnet_ids         = var.subnet_ids
  vpc_id             = var.vpc_id

  # Legacy endpoint args (the "cluster_endpoint_*" variants triggered 'unsupported' earlier)
  endpoint_public_access  = true
  endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  # Addons MUST be inside the module so they install after the control plane
  # but BEFORE node groups. EKS module v21 sets bootstrap_self_managed_addons = false,
  # so the VPC CNI is NOT auto-installed by AWS — without it, nodes can't register.
  addons = {
    vpc-cni = {
      before_compute              = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      before_compute              = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    coredns = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  eks_managed_node_groups = {
    demo = {
      ami_type       = "AL2_x86_64"
      desired_size   = 1
      max_size       = 1
      min_size       = 1
      instance_types = ["p3.2xlarge"]

      # Give the nodegroup more time to become healthy while the separate 'auth' component
      # writes aws-auth (if that's not immediate).
      create_timeout = "40m"
      update_timeout = "60m"
      delete_timeout = "40m"
    }
  }

  tags = { demo = "stacks" }
}
