Read the directory /Users/larry.song/work/hashicorp/terraform-aws-vault-agent-auth-role, understand how vault agent auth to vault agent using AWS IAM role binding.  Then use the same method for the following:

1. install a Vault server on server-vault
2. on another ec2 server (server-tf-cli), install the latest terraform cli.
3. create a terraform plan that
   a) uses vault provider, which authenticate to vault server on server-vault using AWS IAM role binding.
   b) retrieve a sample secret in terraform and output for demo purpose.

## Implementation Plan

Based on the reference architecture, the following will be created:

### Infrastructure Components:
1. **VPC with networking** (subnet, internet gateway, route tables)
2. **Two EC2 instances:**
   - `server-vault`: Runs HashiCorp Vault server with AWS auth method enabled
   - `server-tf-cli`: Runs Terraform CLI with sample configurations

3. **IAM Roles:**
   - `vault-server-role`: For the Vault server (needs `iam:GetRole` permission)
   - `terraform-cli-role`: For the Terraform CLI instance (needs `ec2:DescribeInstances` for AWS auth)

4. **Security Groups:**
   - Vault server: SSH (22), Vault API (8200)
   - Terraform CLI: SSH (22), outbound to Vault

### Key Files to Create:
1. **main.tf** - Infrastructure definitions (VPC, EC2, IAM roles, security groups)
2. **variables.tf** - Input variables (region, AMI, Vault version, etc.)
3. **outputs.tf** - Outputs (IPs, connection info)
4. **scripts/vault_server_setup.sh** - Installs & configures Vault server with:
   - AWS auth method enabled
   - KV secrets engine for demo
   - IAM role binding for terraform-cli-role
   - Sample secret stored in Vault

5. **scripts/terraform_cli_setup.sh** - Installs Terraform CLI
6. **sample-terraform/main.tf** - Demo Terraform config that:
   - Uses Vault provider with AWS IAM auth
   - Retrieves the sample secret
   - Outputs the secret value

### Authentication Flow:
```
Terraform CLI (server-tf-cli)
  ↓ Uses IAM instance profile credentials
  ↓ Authenticates to Vault via AWS IAM auth method
Vault Server (server-vault)
  ↓ Validates IAM credentials
  ↓ Returns Vault token
Terraform Provider
  ↓ Uses token to read secrets
  ↓ Returns secret data
```
