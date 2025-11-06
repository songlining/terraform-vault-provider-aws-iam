terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# Create AWS key pair for server-vault using module
module "server_vault_key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "2.1.0"

  key_name           = "server-vault-key"
  create_private_key = true

  tags = {
    Name = "server-vault-key"
  }
}

# Create AWS key pair for server-tf-cli using module
module "server_tf_cli_key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "2.1.0"

  key_name           = "server-tf-cli-key"
  create_private_key = true

  tags = {
    Name = "server-tf-cli-key"
  }
}

# Create a VPC for our instances
resource "aws_vpc" "vault_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vault-vpc"
  }
}

# Create a subnet in the VPC
resource "aws_subnet" "vault_subnet" {
  vpc_id                  = aws_vpc.vault_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "vault-subnet"
  }
}

# Create an internet gateway
resource "aws_internet_gateway" "vault_igw" {
  vpc_id = aws_vpc.vault_vpc.id

  tags = {
    Name = "vault-igw"
  }
}

# Create a route table
resource "aws_route_table" "vault_route_table" {
  vpc_id = aws_vpc.vault_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vault_igw.id
  }

  tags = {
    Name = "vault-route-table"
  }
}

# Associate the route table with the subnet
resource "aws_route_table_association" "vault_route_table_assoc" {
  subnet_id      = aws_subnet.vault_subnet.id
  route_table_id = aws_route_table.vault_route_table.id
}

# Create a security group for Vault server
resource "aws_security_group" "vault_server_sg" {
  name        = "vault-server-sg"
  description = "Security group for Vault server"
  vpc_id      = aws_vpc.vault_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Vault API
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Vault cluster
  ingress {
    from_port   = 8201
    to_port     = 8201
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vault-server-sg"
  }
}

# Create a security group for Terraform CLI server
resource "aws_security_group" "terraform_cli_sg" {
  name        = "terraform-cli-sg"
  description = "Security group for Terraform CLI server"
  vpc_id      = aws_vpc.vault_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-cli-sg"
  }
}

# Create IAM role for Vault server
resource "aws_iam_role" "vault_server_role" {
  name = "vault-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Add IAM policy for Vault server to validate IAM auth
resource "aws_iam_role_policy" "vault_server_get_role_policy" {
  name = "AllowGetRole"
  role = aws_iam_role.vault_server_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole"
        ]
        Resource = "arn:aws:iam::*:role/terraform-cli-role"
      }
    ]
  })
}

# Create IAM role for Terraform CLI with AWS auth method
resource "aws_iam_role" "terraform_cli_role" {
  name = "terraform-cli-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Create IAM policy for Terraform CLI to authenticate with AWS auth method
resource "aws_iam_policy" "terraform_cli_auth_policy" {
  name        = "terraform-cli-auth-policy"
  description = "Policy for Terraform CLI to authenticate with AWS auth method"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach policy to Terraform CLI role
resource "aws_iam_role_policy_attachment" "terraform_cli_auth_attachment" {
  role       = aws_iam_role.terraform_cli_role.name
  policy_arn = aws_iam_policy.terraform_cli_auth_policy.arn
}

# Create instance profiles
resource "aws_iam_instance_profile" "vault_server_profile" {
  name = "vault-server-profile"
  role = aws_iam_role.vault_server_role.name
}

resource "aws_iam_instance_profile" "terraform_cli_profile" {
  name = "terraform-cli-profile"
  role = aws_iam_role.terraform_cli_role.name
}

# Create EC2 instance for Vault server (server-vault)
resource "aws_instance" "server_vault" {
  ami                    = var.arm_ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.vault_subnet.id
  vpc_security_group_ids = [aws_security_group.vault_server_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.vault_server_profile.name
  key_name               = module.server_vault_key_pair.key_pair_name

  user_data = templatefile("${path.module}/scripts/vault_server_setup.sh", {
    vault_version  = var.vault_version
    aws_account_id = data.aws_caller_identity.current.account_id
  })

  tags = {
    Name = "server-vault"
  }
}

# Create EC2 instance for Terraform CLI (server-tf-cli)
resource "aws_instance" "server_tf_cli" {
  ami                    = var.arm_ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.vault_subnet.id
  vpc_security_group_ids = [aws_security_group.terraform_cli_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.terraform_cli_profile.name
  key_name               = module.server_tf_cli_key_pair.key_pair_name

  user_data = templatefile("${path.module}/scripts/terraform_cli_setup.sh", {
    terraform_version = var.terraform_version
    vault_server_ip   = aws_instance.server_vault.private_ip
    vault_server_dns  = aws_instance.server_vault.public_dns
  })

  tags = {
    Name = "server-tf-cli"
  }

  depends_on = [aws_instance.server_vault]
}

# Save private keys to local files
resource "local_file" "server_vault_private_key" {
  content         = module.server_vault_key_pair.private_key_pem
  filename        = "${path.module}/server-vault-key.pem"
  file_permission = "0600"
}

resource "local_file" "server_tf_cli_private_key" {
  content         = module.server_tf_cli_key_pair.private_key_pem
  filename        = "${path.module}/server-tf-cli-key.pem"
  file_permission = "0600"
}
