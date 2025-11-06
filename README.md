# Terraform Vault Provider with AWS IAM Authentication Demo

**Status: ✅ Working and Tested**

This repository demonstrates a fully working implementation of the Terraform Vault provider with AWS IAM role binding authentication. It sets up a complete environment with a Vault server and a Terraform CLI instance that authenticates to Vault using AWS IAM credentials.

The implementation has been tested and verified to successfully:
- Deploy Vault server with AWS auth method configured
- Configure Terraform CLI with AWS IAM authentication
- Authenticate and retrieve secrets from Vault using IAM credentials
- Work with the `skip_child_token = true` setting for better token management

## Architecture

This module deploys the following resources in AWS:

- **VPC Infrastructure**: VPC with public subnet, internet gateway, and route table
- **Two EC2 Instances**:
  - `server-vault`: Runs HashiCorp Vault server with AWS auth method enabled
  - `server-tf-cli`: Runs Terraform CLI configured to authenticate via AWS IAM
- **Security Groups**: Configured for SSH access and Vault API communication
- **IAM Roles**:
  - `vault-server-role`: Allows Vault to validate IAM authentication
  - `terraform-cli-role`: Used by Terraform to authenticate to Vault
- **SSH Key Pairs**: Automatically generated for secure access

## Authentication Flow

```
Terraform CLI (server-tf-cli)
  ↓ Uses IAM instance profile credentials
  ↓ Authenticates to Vault via AWS IAM auth method
Vault Server (server-vault)
  ↓ Validates IAM credentials
  ↓ Returns Vault token with assigned policies
Terraform Provider
  ↓ Uses token to access secrets
  ↓ Retrieves secret data from KV v2 engine
```

## Prerequisites

- Terraform 1.10.5 or later
- AWS account with appropriate permissions
- AWS CLI configured with valid credentials

## Quick Start

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd terraform-vault-provider-aws-iam
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review and customize variables in `variables.tf` (optional):
   - `aws_region`: AWS region (default: ap-southeast-2)
   - `instance_type`: EC2 instance type (default: t4g.small)
   - `vault_version`: Vault version (default: 1.19.3)
   - `terraform_version`: Terraform version (default: 1.10.5)

4. Deploy the infrastructure:
   ```bash
   terraform apply
   ```

5. Note the outputs:
   - `vault_addr`: Vault server HTTPS address
   - `ssh_command_vault`: Command to SSH into Vault server
   - `ssh_command_tf_cli`: Command to SSH into Terraform CLI server

## Testing the Demo

After deployment completes (allow 5-10 minutes for initialization):

1. SSH into the Terraform CLI server:
   ```bash
   # Use the output from terraform apply
   ssh -i server-tf-cli-key.pem ec2-user@<TERRAFORM_CLI_PUBLIC_IP>
   ```

2. Navigate to the sample Terraform configuration:
   ```bash
   cd /home/ec2-user/sample-terraform
   ```

3. Initialize and apply the sample configuration:
   ```bash
   terraform init
   terraform apply
   ```

4. View the retrieved secrets:
   ```bash
   terraform output
   terraform output -json  # To see sensitive values
   ```

## What Gets Deployed

### Vault Server Configuration

The Vault server (`server-vault`) is automatically configured with:

- **HTTPS enabled** with self-signed certificates
- **AWS auth method** configured for IAM role binding
- **KV v2 secrets engine** mounted at `secret/`
- **Sample secret** at `secret/myapp`:
  - username: demouser
  - password: demopassword
  - environment: production
- **Policy** allowing Terraform CLI role to read secrets
- **Audit logging** enabled

### Terraform CLI Configuration

The Terraform CLI server (`server-tf-cli`) includes:

- **Latest Terraform CLI** (configurable version)
- **Sample Terraform configuration** at `/home/ec2-user/sample-terraform`
- **Environment variables** pre-configured:
  - `VAULT_ADDR`: Points to Vault server
  - `VAULT_SKIP_VERIFY`: Set for self-signed certs
- **Documentation** in README.md

### IAM Configuration

- **vault-server-role**: Has `iam:GetRole` permission to validate authentication
- **terraform-cli-role**: Has `ec2:DescribeInstances` permission required for AWS auth
- **Instance profiles**: Attached to respective EC2 instances

## Files and Structure

```
.
├── README.md                          # This file
├── instructions.md                    # Implementation plan
├── main.tf                            # Main infrastructure definition
├── variables.tf                       # Input variables
├── outputs.tf                         # Output values
├── scripts/
│   ├── vault_server_setup.sh         # Vault server initialization script
│   └── terraform_cli_setup.sh        # Terraform CLI setup script
└── sample-terraform/
    ├── main.tf                        # Sample Terraform configuration
    └── README.md                      # Sample usage documentation
```

## Vault Provider Configuration

The sample Terraform configuration uses the Vault provider with AWS IAM authentication:

```hcl
provider "vault" {
  address = "https://VAULT_SERVER_DNS:8200"
  skip_tls_verify = true
  skip_child_token = true  # Recommended for better token management

  auth_login_aws {
    role = "terraform-cli"
    header_value = "https://VAULT_SERVER_DNS:8200"
  }
}
```

Key points:
- No manual token management required
- Uses EC2 instance IAM role automatically
- Authenticates via AWS auth method
- Token is automatically renewed
- `skip_child_token = true` prevents unnecessary child token creation

## Outputs

| Name | Description |
|------|-------------|
| vault_server_public_ip | Public IP of Vault server |
| vault_server_private_ip | Private IP of Vault server |
| vault_server_public_dns | Public DNS name of Vault server |
| terraform_cli_public_ip | Public IP of Terraform CLI server |
| vault_addr | Complete Vault address (HTTPS) |
| ssh_command_vault | SSH command for Vault server |
| ssh_command_tf_cli | SSH command for Terraform CLI server |
| server_vault_key_file | Path to Vault server SSH key |
| server_tf_cli_key_file | Path to Terraform CLI SSH key |

## Security Considerations

- **TLS**: This demo uses self-signed certificates. In production, use proper CA-signed certificates.
- **SSH Keys**: Private keys are stored locally. Protect these files appropriately.
- **Security Groups**: SSH is open to 0.0.0.0/0 for demo purposes. Restrict in production.
- **IAM Policies**: Follow principle of least privilege for production deployments.
- **Vault Tokens**: The root token is stored on the Vault server. In production, secure this properly.
- **Auto-unseal**: Consider using AWS KMS auto-unseal for production.

## Troubleshooting

### Vault not accessible
- Wait 5-10 minutes after `terraform apply` for initialization
- Check security group allows port 8200
- Verify Vault service is running: `systemctl status vault`

### Terraform authentication fails
- Verify IAM instance profile is attached to EC2 instance
- Check Vault AWS auth role configuration
- Review Vault audit logs: `/var/log/vault_audit.log`

### SSH connection issues
- Ensure private key has correct permissions (0600)
- Verify security group allows SSH from your IP
- Check instance is in running state

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

This will remove:
- Both EC2 instances
- VPC and networking components
- Security groups
- IAM roles and policies
- SSH key pairs (local .pem files will remain)

## References

- [Vault AWS Auth Method](https://developer.hashicorp.com/vault/docs/auth/aws)
- [Terraform Vault Provider](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)
- [Vault KV v2 Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2)

## License

This project is licensed under the Mozilla Public License 2.0.
