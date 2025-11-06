variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "arm_ami_id" {
  description = "AMI ID for ARM-based Amazon Linux 2 instances"
  type        = string
  default     = "ami-0bc8d8ff75a022b42"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.small"
}

variable "vault_version" {
  description = "Version of HashiCorp Vault to install"
  type        = string
  default     = "1.19.3"
}

variable "terraform_version" {
  description = "Version of Terraform CLI to install"
  type        = string
  default     = "1.10.5"
}
