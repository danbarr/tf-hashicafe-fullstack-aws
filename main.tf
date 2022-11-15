## Provider configurations and shared resources

terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.20"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.35"
    }
    tls = {
      source = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  cloud {
    organization = "HashiCafe-inc"
    workspaces {
      tags = [
        "app:fullstack",
        "cloud:aws"
      ]
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      owner       = var.owner
      environment = var.env
      automation  = "terraform"
    }
  }
}

provider "hcp" {}

data "aws_default_tags" "default" {}

locals {
  name  = "${var.prefix}-hashicafe-${var.env}"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.18"

  name = "${local.name}-vpc"
  cidr = "10.0.0.0/16"

  azs              = ["${var.region}a", "${var.region}b", "${var.region}c"]
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  vpc_tags = {
    Name = "${local.name}-vpc"
  }

  public_subnet_tags = {
    "network.scope"                                   = "public"
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "network.scope"                                   = "private"
    "kubernetes.io/role/internal-elb"                 = "1"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
  }

  database_subnet_tags = {
    "network.scope" = "database"
  }
}
