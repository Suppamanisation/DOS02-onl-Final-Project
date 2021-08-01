variable "region" {
  default = "eu-central-1"
}

variable "web_server_ports" {
  description = "Web Server opened ports"
  default     = ["80"]
}

variable "lb_ports" {
  description = "Load Balancer opened ports"
  default     = ["80", "443"]
}

variable "db_ports" {
  description = "Data Base opened ports"
  default     = ["3306"]
}

variable "web_server_ami" {
  default = "ami-05f7491af5eef733a"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "env" {
  default = "dev"
}

variable "public_subnet_cidrs" {
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24"
  ]
}

variable "ecs_for_ec2_service_role_name" {
  default = ""
}

variable "ecs_service_role_name" {
  default = ""
}

variable "ami_id" {
  default = "ami-0114eb74b66592f8b"
}

variable "ami_owners" {
  default = ["self", "amazon", "aws-marketplace"]
}

variable "lookup_latest_ami" {
  default = false
}

variable "root_block_device_type" {
  default = "gp2"
}

variable "root_block_device_size" {
  default = "8"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "cpu_credit_specification" {
  default = "standard"
}

variable "detailed_monitoring" {
  default = false
}

variable "key_name" {
  default = "key name"
}

# variable "cloud_config_content" {}

# variable "cloud_config_content_type" {
#   default = "text/cloud-config"
# }
