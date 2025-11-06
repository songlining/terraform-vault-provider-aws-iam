#!/bin/bash

#set -e

# Update system packages
yum update -y

# Install necessary packages
yum install -y jq unzip

# Download and install Terraform
TERRAFORM_VERSION="${terraform_version}"
curl -O "https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_arm64.zip"
unzip "terraform_$${TERRAFORM_VERSION}_linux_arm64.zip"
mv terraform /usr/local/bin/
chmod +x /usr/local/bin/terraform

# Verify installation
terraform version

# Create directory for sample Terraform configuration
mkdir -p /home/ec2-user/sample-terraform
chown -R ec2-user:ec2-user /home/ec2-user/sample-terraform

# Create sample Terraform configuration that uses Vault provider with AWS IAM auth
cat > /home/ec2-user/sample-terraform/main.tf << 'EOF'
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

# Configure Vault provider to use AWS IAM authentication
provider "vault" {
  address = "https://${vault_server_dns}:8200"
  skip_tls_verify = true
  skip_child_token = true  # Don't create child tokens - not needed for this use case

  auth_login_aws {
    role = "terraform-cli"
    header_value = "https://${vault_server_dns}:8200"
  }
}

# Read the sample secret from Vault
data "vault_kv_secret_v2" "myapp" {
  mount = "secret"
  name  = "myapp"
}

# Output the secret data for demo purposes
output "secret_username" {
  description = "Username from Vault secret"
  value       = data.vault_kv_secret_v2.myapp.data["username"]
  sensitive   = true
}

output "secret_password" {
  description = "Password from Vault secret"
  value       = data.vault_kv_secret_v2.myapp.data["password"]
  sensitive   = true
}

output "secret_environment" {
  description = "Environment from Vault secret"
  value       = data.vault_kv_secret_v2.myapp.data["environment"]
  sensitive   = true
}

output "all_secret_data" {
  description = "All secret data retrieved from Vault"
  value       = data.vault_kv_secret_v2.myapp.data
  sensitive   = true
}
EOF

# Create a README for instructions
cat > /home/ec2-user/sample-terraform/README.md << 'EOF'
# Terraform Vault Provider AWS IAM Auth Demo

This directory contains a sample Terraform configuration that demonstrates:
1. Using the Vault provider
2. Authenticating to Vault using AWS IAM role binding
3. Retrieving secrets from Vault
4. Outputting secret values

## Usage

1. Initialize Terraform:
   ```bash
   cd /home/ec2-user/sample-terraform
   terraform init
   ```

2. Run the plan to see what will happen:
   ```bash
   terraform plan
   ```

3. Apply the configuration to retrieve secrets:
   ```bash
   terraform apply
   ```

4. View the outputs (note that sensitive values are hidden by default):
   ```bash
   terraform output
   ```

5. To see sensitive output values:
   ```bash
   terraform output -json
   ```

## How It Works

The Terraform Vault provider uses the AWS IAM instance profile attached to this EC2 instance
to authenticate with the Vault server. The authentication flow is:

1. Terraform provider reads AWS IAM credentials from instance metadata
2. Provider authenticates to Vault using the AWS auth method
3. Vault validates the IAM credentials and returns a token
4. Provider uses the token to read secrets from the KV v2 secrets engine
5. Secret values are available as Terraform data source outputs
EOF

# Set proper ownership
chown -R ec2-user:ec2-user /home/ec2-user/sample-terraform

# Add environment variables to ec2-user's .bashrc
cat >> /home/ec2-user/.bashrc << EOF
export VAULT_ADDR=https://${vault_server_dns}:8200
export VAULT_SKIP_VERIFY=true
EOF

echo "Terraform CLI setup complete!"
echo "Sample Terraform configuration available at: /home/ec2-user/sample-terraform"
echo "Connect via SSH and run 'terraform init && terraform apply' to test"
