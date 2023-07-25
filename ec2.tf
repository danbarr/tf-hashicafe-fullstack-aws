## EC2 resources

data "hcp_packer_image" "base" {
  bucket_name    = var.bastion_packer_bucket
  channel        = var.bastion_packer_channel
  cloud_provider = "aws"
  region         = var.region
}

resource "aws_instance" "bastion" {
  ami                         = data.hcp_packer_image.base.cloud_image_id
  instance_type               = var.bastion_instance_type
  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [module.bastion_sg.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name

  root_block_device {
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
  }

  tags = {
    Name            = "${local.name}-bastion"
    "network.scope" = "public"
    "app.tier"      = "bastion"
  }

  volume_tags = {
    Name = "${local.name}-bastion"
  }
}

moved {
  from = module.bastion_instance.aws_instance.this[0]
  to   = aws_instance.bastion
}

module "bastion_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.1"

  name        = "${local.name}-bastion-sg"
  description = "Security group for ${local.name} bastion instance."
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]
  egress_rules        = ["all-all"]
}

resource "aws_iam_role" "bastion" {
  name_prefix = "${local.name}-bastion-"
  description = "IAM role for ${local.name} bastion instance."

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

moved {
  from = module.bastion_instance.aws_iam_role.this[0]
  to   = aws_iam_role.bastion
}

resource "aws_iam_instance_profile" "bastion" {
  name_prefix = "${local.name}-bastion-"
  role        = aws_iam_role.bastion.name
}

moved {
  from = module.bastion_instance.aws_iam_instance_profile.this[0]
  to   = aws_iam_instance_profile.bastion
}
