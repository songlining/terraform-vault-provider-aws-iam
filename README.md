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

## How AWS IAM Authentication Works

This implementation uses Vault's AWS auth method with IAM authentication, which allows AWS IAM principals (users, roles, or EC2 instances) to authenticate to Vault without requiring pre-shared secrets or tokens.

### Authentication Mechanism

The AWS IAM authentication method uses AWS's own cryptographic signing to verify identity:

1. **Client Side (Terraform CLI on EC2)**:
   - The Terraform Vault provider automatically retrieves AWS credentials from the EC2 instance metadata service (IMDS)
   - It creates a signed AWS API request (`sts:GetCallerIdentity`) using the instance's IAM role credentials
   - The signed request includes:
     - AWS access key ID
     - Temporary session token
     - Cryptographic signature
     - The `X-Vault-AWS-IAM-Server-ID` header (matching the `header_value` in provider config)
   - This signed request is sent to Vault's AWS auth endpoint

2. **Server Side (Vault)**:
   - Vault receives the signed AWS API request
   - Vault submits this exact signed request to AWS STS API
   - AWS validates the signature and returns the caller's identity (IAM role ARN)
   - Vault extracts the IAM principal ARN from the AWS response
   - Vault matches this ARN against configured auth roles (in this case, the `terraform-cli` role)
   - If a match is found, Vault issues a token with the policies assigned to that role

3. **Security Benefits**:
   - **No secrets to manage**: No API keys, passwords, or tokens need to be stored
   - **Cryptographic proof**: AWS validates the signature, proving the caller's identity
   - **Time-limited**: EC2 instance credentials are automatically rotated by AWS
   - **Audit trail**: Both AWS CloudTrail and Vault audit logs capture authentication attempts
   - **SSRF protection**: The `header_value` parameter prevents Server-Side Request Forgery attacks

### Key Components

#### IAM Role Binding

Vault's AWS auth is configured with **role binding** that maps the IAM role ARN to Vault policies:

```hcl
# On Vault server - configured during setup
vault write auth/aws/role/terraform-cli \
    auth_type=iam \
    bound_iam_principal_arn="arn:aws:iam::ACCOUNT_ID:role/terraform-cli-role" \
    policies="terraform-policy" \
    ttl=1h
```

This configuration:
- Creates a Vault auth role named `terraform-cli`
- Binds it specifically to the `terraform-cli-role` IAM role ARN
- Grants the `terraform-policy` Vault policy to authenticated sessions
- Sets token TTL to 1 hour (automatically renewed by the provider)

#### Required IAM Permissions

**For the Client (terraform-cli-role)**:
```json
{
  "Effect": "Allow",
  "Action": "ec2:DescribeInstances",
  "Resource": "*"
}
```
This allows Vault to retrieve instance metadata to verify the instance's IAM role attachment.

**For Vault Server (vault-server-role)**:
```json
{
  "Effect": "Allow",
  "Action": "iam:GetRole",
  "Resource": "*"
}
```
This allows Vault to retrieve IAM role information to validate the principal.

#### Header Value (SSRF Protection)

The `header_value` parameter in the Vault provider configuration serves as an additional security measure:

```hcl
auth_login_aws {
  role = "terraform-cli"
  header_value = "https://ec2-3-27-81-180.ap-southeast-2.compute.amazonaws.com:8200"
}
```

This value:
- Must match the Vault server's expected value
- Prevents attackers from reusing captured authentication requests against different Vault servers
- Protects against Server-Side Request Forgery (SSRF) attacks
- Should typically be set to the Vault server's address

### Comparison with Other Auth Methods

| Feature | AWS IAM Auth | Token Auth | AppRole Auth |
|---------|-------------|------------|--------------|
| Secret Management | None required | Token must be secured | Secret ID must be secured |
| Rotation | Automatic by AWS | Manual | Manual |
| AWS Integration | Native | None | None |
| Use Case | AWS workloads | Development/Manual | CI/CD, non-AWS apps |
| Setup Complexity | Medium | Low | Medium |

### Token Lifecycle

1. **Initial Authentication**: When Terraform runs, the provider authenticates and receives a token
2. **Token Storage**: Token is kept in memory (not persisted to disk)
3. **Automatic Renewal**: The provider automatically renews the token before expiration
4. **No Child Tokens**: With `skip_child_token = true`, the provider uses the login token directly instead of creating child tokens for each operation
5. **Session End**: Token is discarded when Terraform completes

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
