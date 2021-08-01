provider "aws" {
  shared_credentials_file = "/home/nikita/.aws/terraform"
  region                  = var.region
}

terraform {
  backend "s3" {
    bucket         = "tf-state-dos02-final-project"
    key            = "terraform/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform"
  }
}

#
# VPC resources
#

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.env}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-igw"
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.env}-public-${count.index + 1}"
  }
}

resource "aws_route_table" "public_subnets" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.env}-route-public-subnets"
  }
}

resource "aws_route_table_association" "public_routes" {
  count          = length(aws_subnet.public_subnets[*].id)
  route_table_id = aws_route_table.public_subnets.id
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
}

#
# Security Group resources
#

resource "aws_security_group" "my_ecs_tf" {
  name        = "ECS Instance Security Group"
  description = "My SecurityGroup"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.web_server_ports
    content {
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      cidr_blocks     = ["${var.vpc_cidr}"]
      security_groups = [aws_security_group.my_alb_tf.id]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name  = "${var.env} Web Server SecurityGroup"
    Owner = "Nikita Marinets"
  }
}

resource "aws_security_group" "my_alb_tf" {
  name        = "Load Balancer Security Group"
  description = "My SecurityGroup"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.lb_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name  = "${var.env} Load Balancer SecurityGroup"
    Owner = "Nikita Marinets"
  }
}

resource "aws_security_group" "my_rds_sg" {
  name        = "Data Base Security Group"
  description = "My SecurityGroup"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.db_ports
    content {
      from_port       = ingress.value
      to_port         = ingress.value
      protocol        = "tcp"
      cidr_blocks     = ["${var.vpc_cidr}"]
      security_groups = [aws_security_group.my_ecs_tf.id]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#
# Container Instance IAM resources
#

data "aws_iam_policy_document" "container_instance_ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "container_instance_ec2" {
  name               = coalesce(var.ecs_for_ec2_service_role_name, local.ecs_for_ec2_service_role_name)
  assume_role_policy = data.aws_iam_policy_document.container_instance_ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ec2_service_role" {
  role       = aws_iam_role.container_instance_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "container_instance" {
  name = aws_iam_role.container_instance_ec2.name
  role = aws_iam_role.container_instance_ec2.name
}

#
# ECS Service IAM permissions
#

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_service_role" {
  name               = coalesce(var.ecs_service_role_name, local.ecs_service_role_name)
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_service_role" {
  role       = aws_iam_role.ecs_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

data "aws_iam_policy_document" "ecs_autoscale_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["application-autoscaling.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# data "template_cloudinit_config" "container_instance_cloud_config" {
#   gzip          = true
#   base64_encode = true

#   part {
#     content_type = "text/cloud-config"
#     content = templatefile("/cloud-config/base-container-instance.yml.tmpl", {
#       ecs_cluster_name = aws_ecs_cluster.ecs_cluster.name
#     })
#   }

#   part {
#     content_type = var.cloud_config_content_type
#     content      = var.cloud_config_content
#   }
# }


# data "aws_ssm_parameter" "ecs_image_id" {
#   name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
# }

# data "aws_ami" "ecs_ami" {
#   owners = var.ami_owners

#   filter {
#     name   = "image-id"
#     values = [data.aws_ssm_parameter.ecs_image_id.value]
#   }
# }

# data "aws_ami" "user_ami" {
#   owners = var.ami_owners

#   filter {
#     name   = "image-id"
#     values = [data.aws_ssm_parameter.ecs_image_id.value]
#   }
# }

# resource "aws_launch_template" "container_instance" {
#   block_device_mappings {
#     device_name = var.lookup_latest_ami ? data.aws_ami.ecs_ami.root_device_name : data.aws_ami.user_ami.root_device_name

#     ebs {
#       volume_type = var.root_block_device_type
#       volume_size = var.root_block_device_size
#     }
#   }

#   credit_specification {
#     cpu_credits = var.cpu_credit_specification
#   }

#   disable_api_termination = false

#   name_prefix = "lt${title(var.env)}ContainerInstance-"

#   iam_instance_profile {
#     name = aws_iam_instance_profile.container_instance.name
#   }

#   image_id = var.lookup_latest_ami ? data.aws_ami.ecs_ami.image_id : data.aws_ami.user_ami.image_id

#   instance_initiated_shutdown_behavior = "terminate"
#   instance_type                        = var.instance_type
#   key_name                             = var.key_name
#   vpc_security_group_ids               = [aws_security_group.my_ecs_tf.id]
#   user_data                            = filebase64("user_data.sh")
#   monitoring {
#     enabled = var.detailed_monitoring
#   }
# }

resource "aws_launch_configuration" "ecs_launch_config" {
  name_prefix          = "${var.env}-ECS-Instance-Highly-Available-LC-"
  image_id             = var.ami_id
  iam_instance_profile = aws_iam_instance_profile.container_instance.name
  security_groups      = [aws_security_group.my_ecs_tf.id]
  user_data            = file("user_data.sh")
  instance_type        = "t2.micro"

}

resource "aws_autoscaling_group" "container_instance" {
  name = "ASG-${aws_launch_configuration.ecs_launch_config.name}"

  # launch_template {
  #   id      = aws_launch_template.container_instance.id
  #   version = "$Latest"
  # }
  launch_configuration = aws_launch_configuration.ecs_launch_config.name
  vpc_zone_identifier  = aws_subnet.public_subnets[*].id
  desired_capacity     = 2
  min_size             = 1
  max_size             = 5
  # health_check_grace_period = 300
  # health_check_type         = "EC2"
  target_group_arns = [aws_lb_target_group.tg_tf.arn]

  dynamic "tag" {
    for_each = {
      Name  = "${var.env} ECS Instance in ASG"
      Owner = "Nikita Marinets"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  subnet_ids = aws_subnet.public_subnets[*].id
}

# resource "aws_db_instance" "mysql" {
#     identifier                = "mysql"
#     allocated_storage         = 5
#     backup_retention_period   = 2
#     backup_window             = "01:00-01:30"
#     maintenance_window        = "sun:03:00-sun:03:30"
#     # multi_az                  = true
#     engine                    = "mysql"
#     engine_version            = "5.7"
#     instance_class            = "db.t2.micro"
#     name                      = "worker_db"
#     username                  = "worker"
#     password                  = "worker1234"
#     port                      = "3306"
#     db_subnet_group_name      = aws_db_subnet_group.db_subnet_group.id
#     vpc_security_group_ids    = [aws_security_group.my_rds_sg.id, aws_security_group.my_ecs_tf.id]
#     skip_final_snapshot       = true
#     final_snapshot_identifier = "worker-final"
#     publicly_accessible       = false
# }

resource "aws_lb" "alb_tf" {
  name               = "main-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_alb_tf.id]
  subnets            = aws_subnet.public_subnets[*].id

  tags = {
    Environment = "${var.env}"
  }
}
resource "aws_lb_target_group" "tg_tf" {
  name     = "my-alb-tg-tf"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb_tf.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:eu-central-1:632458184488:certificate/d7294905-4e20-45d8-b909-b0f5da5398f0"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_tf.arn
  }
}
resource "aws_lb_listener" "front_end_redirect" {
  load_balancer_arn = aws_lb.alb_tf.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

data "aws_route53_zone" "selected" {
  name         = "nikitamarinets.tk."
  private_zone = false
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "nikitamarinets.tk"
  type    = "A"

  alias {
    name                   = aws_lb.alb_tf.dns_name
    zone_id                = aws_lb.alb_tf.zone_id
    evaluate_target_health = true
  }
}

resource "aws_ecr_repository" "worker" {
  name = "my-ecs-worker"
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}
