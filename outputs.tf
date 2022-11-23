output "bastion_hostname" {
  description = "Public hostname of the bastion instance."
  value       = aws_instance.bastion.public_dns
}

output "frontend_url" {
  description = "URL of the frontend load balancer."
  value       = "https://${aws_lb.ecs_frontend.dns_name}"
}

output "eks_endpoint" {
  description = "API endpoint of the EKS cluster."
  value       = aws_eks_cluster.backend.endpoint
}

output "asset_bucket_name" {
  description = "Name of the S3 bucket for app assets."
  value       = aws_s3_bucket.assets.bucket
}

output "log_bucket_name" {
  description = "Name of the logging bucket."
  value = aws_s3_bucket.logs.bucket
}