terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

# Configure Vault provider to use AWS IAM authentication
# This will be deployed on server-tf-cli and use its IAM instance profile
provider "vault" {
  # This will be replaced with actual DNS during deployment
  address = "https://ec2-3-27-81-180.ap-southeast-2.compute.amazonaws.com:8200"
  skip_tls_verify = true
  skip_child_token = true  # Don't create child tokens - not needed for this use case

  auth_login_aws {
    role = "terraform-cli"
    # Header value should match the Vault address
    header_value = "https://ec2-3-27-81-180.ap-southeast-2.compute.amazonaws.com:8200"
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
