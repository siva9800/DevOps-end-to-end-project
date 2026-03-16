variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the runner will be launched"
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID for the runner"
  type        = string
}

variable "aws_region" {
  description = "AWS region — needed for SSM token fetch at boot"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the runner"
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size" {
  description = "Root volume size in GB (needs space for Docker images)"
  type        = number
  default     = 30
}

variable "github_runner_url" {
  description = "GitHub repository or organization URL for the runner"
  type        = string
}

variable "github_runner_token" {
  description = "GitHub runner registration token — stored in SSM, never hardcoded"
  type        = string
  sensitive   = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

