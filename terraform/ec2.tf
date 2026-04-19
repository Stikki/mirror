data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "mirror" {
  key_name   = "mirror"
  public_key = file(var.ssh_pubkey_path)
}

resource "aws_security_group" "mirror" {
  name        = "mirror"
  description = "Mirror tunnel server"
  vpc_id      = data.aws_vpc.default.id

  # Admin SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tunnel SSH (container sshd on port 2222)
  ingress {
    from_port   = 2222
    to_port     = 2222
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "mirror" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.mirror.key_name
  vpc_security_group_ids = [aws_security_group.mirror.id]
  subnet_id                   = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/templates/userdata.sh.tpl", {
    domain                = var.domain
    mirror_tunnel_port    = var.mirror_tunnel_port
    mirror_authorized_key = var.mirror_authorized_key
  })

  tags = {
    Name = "mirror"
  }
}

resource "aws_eip" "mirror" {
  instance = aws_instance.mirror.id
  domain   = "vpc"

  tags = {
    Name = "mirror"
  }
}
