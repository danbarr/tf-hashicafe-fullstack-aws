locals {
  eks_cluster_name = "${local.name}-eks-backend"
}

resource "aws_eks_cluster" "backend" {
  name     = local.eks_cluster_name
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    subnet_ids              = concat(module.vpc.public_subnets, module.vpc.private_subnets)
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  tags = {
    "app.tier" = "backend"
    yor_trace  = "ad116b07-1ed4-4cb6-815c-bc16c9936774"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_cluster_vpc_resource_controller,
  ]
}

resource "aws_iam_role" "eks" {
  name_prefix = "${local.name}-eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
  tags = {
    yor_trace = "2a2631c6-7def-4e5d-9fa9-be7c0972fc59"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks.name
}

resource "aws_eks_node_group" "backend" {
  cluster_name    = aws_eks_cluster.backend.name
  node_group_name = "${local.name}-backend-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = module.vpc.private_subnets
  instance_types  = [var.eks_node_instance_type]

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  scaling_config {
    desired_size = 3
    max_size     = 5
    min_size     = 1
  }

  lifecycle {
    ignore_changes       = [scaling_config[0].desired_size]
    replace_triggered_by = [aws_eks_cluster.backend.endpoint]
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    "app.tier" = "backend"
    yor_trace  = "1c5d0590-d988-4c4d-9167-a5b8ea524ebc"
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.eks_registry
  ]
}

resource "aws_launch_template" "eks_nodes" {
  update_default_version = true

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(data.aws_default_tags.default.tags,
      {
        Name            = "${local.name}-backend-eks-node"
        "app.tier"      = "backend"
        "network.scope" = "private"
    })
  }
  tags = {
    yor_trace = "9f83bb39-01b1-4c3a-888a-76ce888e24b6"
  }
}

resource "aws_iam_role" "eks_node_group" {
  name_prefix = "${local.name}-eks-node-group"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  tags = {
    yor_trace = "f9367266-e29f-44a1-a0c0-b0cd4381ebb5"
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_eks_addon" "cni" {
  cluster_name = aws_eks_cluster.backend.name
  addon_name   = "vpc-cni"
  depends_on   = [aws_eks_node_group.backend]
  lifecycle {
    replace_triggered_by = [aws_eks_cluster.backend.endpoint]
  }
  tags = {
    yor_trace = "215bb589-f4c6-41dc-9ff5-e02cea8f75fc"
  }
}

resource "aws_eks_addon" "dns" {
  cluster_name = aws_eks_cluster.backend.name
  addon_name   = "coredns"
  depends_on   = [aws_eks_node_group.backend]
  lifecycle {
    replace_triggered_by = [aws_eks_cluster.backend.endpoint]
  }
  tags = {
    yor_trace = "1a41a834-83dc-48d1-8e54-8a34c388ddb9"
  }
}

resource "aws_eks_addon" "proxy" {
  cluster_name = aws_eks_cluster.backend.name
  addon_name   = "kube-proxy"
  depends_on   = [aws_eks_node_group.backend]
  lifecycle {
    replace_triggered_by = [aws_eks_cluster.backend.endpoint]
  }
  tags = {
    yor_trace = "e6349c58-6e3d-4b3a-8c58-5471a1f2d41a"
  }
}
