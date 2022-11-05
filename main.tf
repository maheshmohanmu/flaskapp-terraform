provider "aws" {
  region  = "ap-northeast-2"
  access_key= var.access_key
  secret_key= var.secret_key
}

resource "aws_ecr_repository" "ecr-repo-mahesh" {
  name = "ecr-repo-mahesh"
}

resource "aws_ecs_cluster" "flaskapp-cluster" {
  name = "flaskapp-cluster2"
}

# Below code is not used to provision ECS Task definitions. 
# Instead Task definitions are created using json file from repo using Gitbub Actions 

resource "aws_ecs_task_definition" "flaskapp-task" {
  family                   = "flaskapp-img2"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "flaskapp-img2",
      "image": "flaskapp-img2",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 5000,
          "hostPort": 5000
        }
      ],
      "memory": 512,
      "cpu": 256,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "flaskapplogsgrp",
          "awslogs-region": "ap-northeast-2",
          "awslogs-stream-prefix": "flaskapplogs"
            }
          }
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = data.aws_iam_role.task_ecs.arn
}

resource "aws_ecs_service" "flaskapp-service" {
  name            = "flaskapp-servic2"                             # Naming our first service
  cluster         = "${aws_ecs_cluster.flaskapp-cluster.id}"             # Referencing our created Cluster
  task_definition = flaskappfam-img3 #"${aws_ecs_task_definition.flaskapp-task.id}" # Referencing the task our service will spin up
  launch_type     = "FARGATE"
  desired_count   = 2 # Setting the number of containers we want to be deployed to 2

  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # Referencing our target group
    container_name   = "${aws_ecs_task_definition.flaskapp-task.family}"
    container_port   = 5000 # Specifying the container port
  }

  network_configuration {
    subnets          = data.aws_subnet_ids.subnets.ids #Refer subnets from default vpc datasource
    assign_public_ip = true # Create public ip for containers
  }
}

# Security group for ECS service to allow traffic from LB security group
resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allow incoming traffic from the load balancer security group
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0 # Allow any incoming port
    to_port     = 0 # Allow any outgoing port
    protocol    = "-1" # Allow any outgoing protocol
    cidr_blocks = ["0.0.0.0/0"] # Allow outgoing traffic to all IP
  }
}

resource "aws_alb" "application_load_balancer" {
  name               = "flaskapp-ecs-lb"
  load_balancer_type = "application"
  subnets = data.aws_subnet_ids.subnets.ids #Refer subnets from default vpc datasource
  # Referencing the LB security group
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

# Security group for the load balancer
resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 80 #Allow incoming traffic from port 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #Allow incoming traffic from everywhere
  }

  egress {
    from_port   = 0 # Allow any incoming port
    to_port     = 0 # Allow any outgoing port
    protocol    = "-1" # Allow any outgoing protocol
    cidr_blocks = ["0.0.0.0/0"] # Allow outgoing traffic to all IP addresses
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "flaskapp-ecs-lb-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${data.aws_vpc.default_vpc.id}" # Referencing the default VPC
  health_check {
    matcher = "200,301,302"
    path = "/"
    timeout = 110
    interval = 120
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.application_load_balancer.arn}" # Referencing our load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # Referencing our target group
  }
}

data "aws_vpc" "default_vpc" { #Reference data source for default vpc (not terraform managed)
  default = true
}

data "aws_subnet_ids" "subnets" { #Reference data source for subnets from default vpc (not terraform managed)
  vpc_id = data.aws_vpc.default_vpc.id
}

data "aws_iam_role" "task_ecs" {
  name = "ecsTaskExecutionRole"
}
