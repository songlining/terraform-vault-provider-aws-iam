# Terraform Vault Provider AWS IAM Auth Demo

This directory contains a sample Terraform configuration that demonstrates:
1. Using the Vault provider
2. Authenticating to Vault using AWS IAM role binding
3. Retrieving secrets from Vault
4. Outputting secret values

## Overview

This sample configuration will be automatically deployed to the `server-tf-cli` EC2 instance. It demonstrates how Terraform can authenticate to Vault using AWS IAM credentials without needing to manually manage Vault tokens.

## How It Works

The Terraform Vault provider uses the AWS IAM instance profile attached to the EC2 instance to authenticate with the Vault server. The authentication flow is:

1. Terraform provider reads AWS IAM credentials from instance metadata
2. Provider authenticates to Vault using the AWS auth method
3. Vault validates the IAM credentials against the bound role
4. Vault returns a token with policies assigned to the `terraform-cli` role
5. Provider uses the token to read secrets from the KV v2 secrets engine
6. Secret values are available as Terraform data source outputs

## Usage on server-tf-cli

After the infrastructure is deployed and you SSH into `server-tf-cli`:

1. Navigate to the sample directory:
   ```bash
   cd /home/ec2-user/sample-terraform
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Run the plan to see what will happen:
   ```bash
   terraform plan
   ```

4. Apply the configuration to retrieve secrets:
   ```bash
   terraform apply
   ```

5. View the outputs (note that sensitive values are hidden by default):
   ```bash
   terraform output
   ```

6. To see sensitive output values:
   ```bash
   terraform output -json
   ```

## Configuration Details

### Provider Configuration

The Vault provider uses `auth_login_aws` block to configure AWS IAM authentication:

```hcl
provider "vault" {
  address = "https://VAULT_SERVER_DNS:8200"
  skip_tls_verify = true  # Only for demo with self-signed certs

  auth_login_aws {
    role = "terraform-cli"
    header_value = "https://VAULT_SERVER_DNS:8200"
  }
}
```

### Secret Retrieval

Secrets are read using the `vault_kv_secret_v2` data source:

```hcl
data "vault_kv_secret_v2" "myapp" {
  mount = "secret"
  name  = "myapp"
}
```

### Sample Secret

The Vault server is pre-configured with a sample secret at `secret/myapp`:
- `username`: demouser
- `password`: demopassword
- `environment`: production

## Security Notes

- This demo uses `skip_tls_verify = true` because self-signed certificates are used
- In production, use proper TLS certificates and set `skip_tls_verify = false`
- Sensitive outputs are marked with `sensitive = true` to prevent accidental exposure
- The IAM role binding ensures only EC2 instances with the correct role can authenticate
