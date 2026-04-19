variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "instance_type" {
  type    = string
  default = "t3.nano"
}

variable "domain" {
  type    = string
  default = "mirror.stikki.ninja"
}

variable "ssh_pubkey_path" {
  description = "Path to the SSH public key for EC2 admin access"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "mirror_authorized_key" {
  description = "SSH public key for the mirror tunnel user (full line from .pub file)"
  type        = string
}

variable "mirror_tunnel_port" {
  type    = number
  default = 7000
}
