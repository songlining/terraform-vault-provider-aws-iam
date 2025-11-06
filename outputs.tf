output "vault_server_public_ip" {
  description = "Public IP address of the Vault server"
  value       = aws_instance.server_vault.public_ip
}

output "vault_server_private_ip" {
  description = "Private IP address of the Vault server"
  value       = aws_instance.server_vault.private_ip
}

output "vault_server_public_dns" {
  description = "Public DNS name of the Vault server"
  value       = aws_instance.server_vault.public_dns
}

output "terraform_cli_public_ip" {
  description = "Public IP address of the Terraform CLI server"
  value       = aws_instance.server_tf_cli.public_ip
}

output "terraform_cli_private_ip" {
  description = "Private IP address of the Terraform CLI server"
  value       = aws_instance.server_tf_cli.private_ip
}

output "vault_addr" {
  description = "Complete VAULT_ADDR for accessing the Vault server via HTTPS"
  value       = "https://${aws_instance.server_vault.public_dns}:8200"
}

output "server_vault_key_file" {
  description = "Path to the private key file for server-vault"
  value       = local_file.server_vault_private_key.filename
}

output "server_tf_cli_key_file" {
  description = "Path to the private key file for server-tf-cli"
  value       = local_file.server_tf_cli_private_key.filename
}

output "ssh_command_vault" {
  description = "SSH command to connect to Vault server"
  value       = "ssh -i ${local_file.server_vault_private_key.filename} ec2-user@${aws_instance.server_vault.public_ip}"
}

output "ssh_command_tf_cli" {
  description = "SSH command to connect to Terraform CLI server"
  value       = "ssh -i ${local_file.server_tf_cli_private_key.filename} ec2-user@${aws_instance.server_tf_cli.public_ip}"
}
