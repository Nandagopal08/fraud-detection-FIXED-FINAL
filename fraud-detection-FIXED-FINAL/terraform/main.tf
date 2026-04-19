terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

# ──────────────────────────────────────────
# DATA SOURCES
# ──────────────────────────────────────────
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ──────────────────────────────────────────
# SECURITY GROUP
# ──────────────────────────────────────────
resource "aws_security_group" "fraud_detection_sg" {
  name        = "fraud-detection-sg"
  description = "Security group for fraud detection server"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH access"
  }

  # Flask API
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Fraud Detection API"
  }

  # Portainer
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Portainer Docker UI"
  }

  # Grafana
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana Dashboards"
  }

  # Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Prometheus Metrics"
  }

  # Jenkins
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Jenkins CI/CD"
  }

  # Kubernetes API (for minikube NodePort range)
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kubernetes NodePort range"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "fraud-detection-sg"
    Project     = "fraud-detection"
    ManagedBy   = "Terraform"
  }
}

# ──────────────────────────────────────────
# EC2 INSTANCE  (matches paper: T2.medium, AWS region ap-northeast-2)
# ──────────────────────────────────────────
resource "aws_instance" "fraud_detection_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type        # t2.medium – matches paper Table 2
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.fraud_detection_sg.id]

  root_block_device {
    volume_size           = 25      # 25GB SSD – matches paper Table 2
    volume_type           = "gp2"
    delete_on_termination = true
  }

  # Minimal bootstrap: install Docker + Docker Compose
  user_data = <<-EOF
              #!/bin/bash
              set -ex
              yum update -y
              yum install -y docker git
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user

              # Docker Compose v2
              mkdir -p /usr/local/lib/docker/cli-plugins
              curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
                -o /usr/local/lib/docker/cli-plugins/docker-compose
              chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

              # Signal Ansible that the instance is ready
              echo "PROVISIONED_BY_TERRAFORM=true" >> /etc/environment
              EOF

  tags = {
    Name        = "fraud-detection-server"
    Project     = "fraud-detection"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Region      = var.aws_region
  }
}

# ──────────────────────────────────────────
# ELASTIC IP  (stable public address)
# ──────────────────────────────────────────
resource "aws_eip" "fraud_detection_eip" {
  instance = aws_instance.fraud_detection_server.id
  domain   = "vpc"

  tags = {
    Name      = "fraud-detection-eip"
    Project   = "fraud-detection"
    ManagedBy = "Terraform"
  }
}
