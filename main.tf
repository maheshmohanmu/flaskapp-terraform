provider "aws" {
  region  = "ap-northeast-2"
  access_key= var.access_key
  secret_key= var.secret_key
}

resource "aws_ecr_repository" "ecr-repo-mahesh" {
  name = "ecr-repo-mahesh"
}

resource "aws_ecs_cluster" "flaskapp-cluster" {
  name = "flaskapp-cluster"
}

resource "aws_ecs_task_definition" "flaskapp-task" {
  family                   = "flaskapp-task"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "flaskapp-img",
      "image": "flaskapp-img",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 5000,
          "hostPort": 5000
        }
      ],
      "memory": 512,
      "cpu": 256
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
  name            = "flaskapp-servic"                             # Naming our first service
  cluster         = "${aws_ecs_cluster.flaskapp-cluster.id}"             # Referencing our created Cluster
  task_definition = "${aws_ecs_task_definition.flaskapp-task.id}" # Referencing the task our service will spin up
  launch_type     = "FARGATE"
  desired_count   = 2 # Setting the number of containers we want to be deployed to 2
  network_configuration {
    subnets          = data.aws_subnet_ids.subnets.ids #Refer subnets from default vpc datasource
    assign_public_ip = true # Create public ip for containers
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
