# ════════════════════════════════════════════════════════════════
# AstroNova — Terraform Variables
# ════════════════════════════════════════════════════════════════

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type for Kubernetes nodes"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of the SSH key pair to use for EC2 instances"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04 LTS — find via aws ec2 describe-images"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instances"
  type        = string
  default     = "0.0.0.0/0"
}

variable "project_name" {
  description = "Project name used for tagging resources"
  type        = string
  default     = "astronova"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}
