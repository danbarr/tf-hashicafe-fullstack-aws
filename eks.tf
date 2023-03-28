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
    yor_trace  = "615d62e5-b24e-442f-be0e-f85185d37dc0"
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
    yor_trace = "62fed762-6963-4927-9275-e205f6ca2029"
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
    yor_trace  = "2cdef661-ab69-4b0e-b63c-ead2884a2734"
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
    yor_trace = "961cbc84-98df-4e3b-a20e-59a23c8f68d7"
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
    yor_trace = "1494f158-3b6e-487e-bba5-c547e06231c1"
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
    yor_trace = "17d0b1e5-f42a-46dc-9bfe-3d65b472424b"
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
    yor_trace = "b559fd4d-ccf5-4a57-830c-8fb5bb8ba458"
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
    yor_trace = "e5980f99-9f24-4ed7-bd64-aebc2c006109"
  }
}
