variable "region" {
  description = "AWS region."
  type        = string
  validation {
    condition     = can(regex("^(?:eu-|us-)", var.region))
    error_message = "Only US or EU regions are allowed."
  }
}

variable "env" {
  description = "Environment for this deployment."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "test", "prod"], var.env)
    error_message = "The env must be one of \"dev\", \"test\", or \"prod\"."
  }
}

variable "owner" {
  description = "Name of the person responsible for this deployment."
  type        = string
}

variable "prefix" {
  description = "A prefix for resource names. Will be combined with `env` to generate unique names."
  type        = string
}

variable "bastion_packer_bucket" {
  description = "The HCP Packer bucket name for the bastion instance."
  type        = string
}

variable "bastion_packer_channel" {
  description = "The HCP Packer channel name for the bastion instance."
  type        = string
  default     = "development"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion instance."
  type        = string
  default     = "t3.micro"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for the EKS nodes."
  type        = string
  default     = "t3.medium"
}
