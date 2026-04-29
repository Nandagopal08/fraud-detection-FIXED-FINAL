variable "aws_region" {
  description = "AWS region to deploy in (paper uses ap-northeast-2 = Seoul)"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type (paper Table 2: T2.medium, 2 vCPU, 4GB RAM)"
  type        = string
  default     = "t3.medium"
}

variable "key_pair_name" {
  description = "Name of the AWS Key Pair for SSH access"
  type        = string
  # Override in terraform.tfvars — do NOT commit actual key names to git
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
  default     = "production"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access. Set to your IP: e.g. 203.0.113.5/32"
  type        = string
  default     = "0.0.0.0/0"
}
