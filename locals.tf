locals {
  cluster_name                  = "ecs${title(var.env)}Cluster"
  autoscaling_group_name        = "asg${title(var.env)}ContainerInstance"
  security_group_name           = "sgContainerInstance"
  ecs_for_ec2_service_role_name = "${var.env}ContainerInstanceProfile"
  ecs_service_role_name         = "ecs${title(var.env)}ServiceRole"
}