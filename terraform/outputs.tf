output "public_ip" {
  value = aws_eip.mirror.public_ip
}

output "url" {
  value = "https://${var.domain}"
}

output "ssh_admin" {
  value = "ssh -i ${var.ssh_pubkey_path} ec2-user@${aws_eip.mirror.public_ip}"
}

output "mirror_command" {
  value = "mirror 3000  # after configuring ~/.config/mirror/config"
}
