resource "aws_ecs_cluster" "frontend" {
  name = "${local.name}-ecs"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    "app.tier" = "frontend"
  }
}

resource "aws_ecs_cluster_capacity_providers" "default" {
  cluster_name = aws_ecs_cluster.frontend.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_ecs_task_definition" "nginx" {
  family                   = "${local.name}-nginx"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  runtime_platform {
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode(
    [
      {
        name : "nginx"
        image : "nginx:alpine"
        essential : true
        cpu : 256
        memory : 256
        portMappings : [
          {
            containerPort : 80,
            protocol : "tcp"
          }
        ],
      }
    ]
  )
}

resource "aws_ecs_service" "nginx" {
  name            = "${local.name}-nginx"
  cluster         = aws_ecs_cluster.frontend.arn
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 2
  propagate_tags  = "SERVICE"

  deployment_maximum_percent         = "200"
  deployment_minimum_healthy_percent = "33"
  enable_ecs_managed_tags            = "true"

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = "1"
  }

  network_configuration {
    assign_public_ip = true
    security_groups  = [module.ecs_nginx_sg.security_group_id]
    subnets          = module.vpc.private_subnets
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_frontend.arn
    container_name   = "nginx"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    "network.scope" = "public"
    "app.tier"      = "frontent"
  }
}

resource "aws_lb_target_group" "ecs_frontend" {
  name        = "${local.name}-ecs-frontend"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_lb" "ecs_frontend" {
  name               = "${local.name}-ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.ecs_alb_sg.security_group_id]
  subnets            = module.vpc.public_subnets

  tags = {
    "network.scope" = "public"
    "app.tier"      = "frontend"
  }
}

resource "aws_lb_listener" "ecs_frontend" {
  load_balancer_arn = aws_lb.ecs_frontend.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_frontend.arn
  }
}

module "ecs_alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.5"

  name        = "${local.name}-ecs-frontend-alb-sg"
  description = "Security group for ${local.name} ECS frontend ALB."
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp"]
  egress_rules        = ["all-all"]
}

module "ecs_nginx_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.5"

  name        = "${local.name}-ecs-nginx-sg"
  description = "Security group for ${local.name} ECS nginx containers."
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.ecs_alb_sg.security_group_id
    }
  ]
  egress_rules = ["all-all"]
}

## IAM
# Two roles are defined: the task execution role used during initialization,
# and the task role which is assumed by the container(s).

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.name}-ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.name}-ecsTaskRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}
