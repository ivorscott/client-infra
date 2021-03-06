terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.0.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.1.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = ">= 3.1.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "3.34.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source = "./vpc"
}

module "cluster" {
  source  = "terraform-aws-modules/eks/aws"
  # source module arguments - https://bit.ly/3sstvMO

  version = "v13.2.1"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.subnets

  cluster_name    = module.vpc.cluster_name
  cluster_version = var.kubernetes_version
  manage_aws_auth = false # Managed in ./kubernetes-config/main.tf instead.
  # This kubeconfig expires in 15 minutes, so we'll use an exec block instead.
  # See ./kubernetes-config/main.tf provider block for details.
  write_kubeconfig = false

  worker_groups = [
    {
      instance_type        = var.workers_type
      asg_desired_capacity = var.workers_count
      asg_max_size         = "10"
    },
  ]

  tags = {
    environment = "test"
  }
}

module "kubernetes-config" {
  source            = "./kubernetes-config"
  eks_node_role_arn = list(module.cluster.worker_iam_role_arn)
  cluster_ca_cert   = module.cluster.cluster_certificate_authority_data
  cluster_name      = module.cluster.cluster_id # creates dependency on cluster creation
  cluster_oidc_issuer_url = module.cluster.cluster_oidc_issuer_url # required for identity provider creation
  cluster_endpoint  = module.cluster.cluster_endpoint
  hostname = var.hostname
  hosted_zone_id = var.hosted_zone_id
}