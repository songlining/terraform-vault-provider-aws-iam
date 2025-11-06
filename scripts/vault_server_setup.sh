#!/bin/bash

#set -e

# Update system packages
yum update -y

# Install necessary packages
yum install -y jq unzip openssl

# Download and install Vault
VAULT_VERSION="${vault_version}"
curl -O "https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_arm64.zip"
unzip "vault_$${VAULT_VERSION}_linux_arm64.zip"
mv vault /usr/local/bin/
chmod +x /usr/local/bin/vault

# Create Vault directories
mkdir -p /etc/vault.d
mkdir -p /opt/vault/data
mkdir -p /opt/vault/tls

# Get the public DNS name of this EC2 instance
export TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_DNS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-hostname)
echo "Public DNS: $PUBLIC_DNS"

# Generate SSL certificate and private key
openssl req -x509 -newkey rsa:4096 -keyout /opt/vault/tls/vault-key.pem -out /opt/vault/tls/vault-cert.pem -days 365 -nodes -subj "/CN=$PUBLIC_DNS" -addext "subjectAltName=DNS:$PUBLIC_DNS,DNS:localhost,IP:127.0.0.1"

# Set proper permissions on certificate files
chmod 600 /opt/vault/tls/vault-key.pem
chmod 644 /opt/vault/tls/vault-cert.pem
chown root:root /opt/vault/tls/*

# Create Vault server configuration with HTTPS
cat > /etc/vault.d/vault.hcl << EOF
ui = true

storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/opt/vault/tls/vault-cert.pem"
  tls_key_file  = "/opt/vault/tls/vault-key.pem"
}

api_addr = "https://$PUBLIC_DNS:8200"
cluster_addr = "https://$PUBLIC_DNS:8201"

log_level = "debug"
EOF

# Create Vault systemd service
cat > /etc/systemd/system/vault.service << EOF
[Unit]
Description=Vault Service
Requires=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF

# Start and enable Vault service
systemctl daemon-reload
systemctl enable vault
systemctl start vault

# Wait for Vault to start
sleep 10

# Initialize Vault with HTTPS
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true
vault operator init -format=json > /root/vault-init.json

# Unseal Vault
for i in {0..2}; do
  UNSEAL_KEY=$(jq -r ".unseal_keys_b64[$i]" /root/vault-init.json)
  vault operator unseal $UNSEAL_KEY
done

# Set root token for further operations
export VAULT_TOKEN=$(jq -r .root_token /root/vault-init.json)

# Enable audit logging
vault audit enable file file_path=/var/log/vault_audit.log

# Enable KV v2 secrets engine
vault secrets enable -version=2 -path=secret kv

# Create a sample secret for demo purposes
vault kv put secret/myapp username=demouser password=demopassword environment=production

# Enable and configure AWS auth method for Terraform CLI authentication
vault auth enable aws

# Create policy for Terraform CLI to read secrets
cat > /etc/vault.d/terraform-policy.hcl << EOF
path "secret/data/myapp" {
  capabilities = ["read", "list"]
}

path "secret/metadata/myapp" {
  capabilities = ["read", "list"]
}
EOF

# Write the policy to Vault
vault policy write terraform-access /etc/vault.d/terraform-policy.hcl

# Configure AWS auth role for the Terraform CLI
vault write auth/aws/role/terraform-cli \
  auth_type=iam \
  bound_iam_principal_arn="arn:aws:iam::${aws_account_id}:role/terraform-cli-role" \
  policies=default,terraform-access \
  ttl=24h

echo "Vault server setup complete with HTTPS enabled!"
echo "Vault is accessible at: https://$PUBLIC_DNS:8200"
echo "Certificate details saved in /opt/vault/tls/"

# Add vault settings to ec2-user's .bashrc
cat >> /home/ec2-user/.bashrc << EOF
export VAULT_ADDR=https://localhost:8200
export VAULT_TOKEN=$VAULT_TOKEN
export VAULT_SKIP_VERIFY=true
EOF
