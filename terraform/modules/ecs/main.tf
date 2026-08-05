resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "wallet_service" {
  name              = "/ecs/${var.environment}-wallet-service"
  retention_in_days = 7

  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "compliance_service" {
  name              = "/ecs/${var.environment}-compliance-service"
  retention_in_days = 7

  tags = {
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "wallet_service" {
  family                   = "${var.environment}-wallet-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.task_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "wallet-service"
      image     = var.wallet_service_image
      essential = true
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.wallet_service.name
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "compliance_service" {
  family                   = "${var.environment}-compliance-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.task_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "compliance-service"
      image     = var.compliance_service_image
      essential = true
      portMappings = [
        {
          containerPort = 8001
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.compliance_service.name
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Environment = var.environment
  }
}


resource "aws_ecs_service" "wallet_service" {
  name            = "${var.environment}-wallet-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.wallet_service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [var.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  depends_on = [var.alb_listener_arn]

  load_balancer {
    target_group_arn = var.wallet_service_target_group_arn
    container_name   = "wallet-service"
    container_port   = 8000
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_ecs_service" "compliance_service" {
  name            = "${var.environment}-compliance-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.compliance_service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [var.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  tags = {
    Environment = var.environment
  }
}
