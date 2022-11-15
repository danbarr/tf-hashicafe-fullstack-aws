# hashicafe-fullstack-aws

Terraform repo for larger-scale AWS demos.

Currently includes the following services:

- VPC
- IAM
- EC2 (with HCP Packer used for AMI references)
- S3
- ECS
- EKS
- ELB
- DynamoDB

The main branch is flat - some public modules are used, but mostly direct resource references, and intentionally minimal security/compliance hardening so IaC scanning tools can be demonstrated with a fair number of issues to find.

The security-fix branch shows the same resources but with security findings fixed (currently based on Checkov scans).

Over time I'll add more branches to show refactoring into local, then TFC private modules.

## Using

To use in your own environment, update main.tf to change the Terraform Cloud organization and workspace selection to your own.
