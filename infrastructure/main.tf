terraform {
  required_version = ">= 1.5, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region              = "eu-west-1"
  allowed_account_ids = ["077815499909"]

  default_tags {
    tags = {
      Project   = "atu-request-tracker"
      Owner     = "Michael Turvey"
      ManagedBy = "Terraform"
    }
  }
}

# Look up the official Ubuntu 24.04 x86 image.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_instance_profile" "server" {
  name = "atu-devops-ec2-role"
}

resource "aws_security_group" "server" {
  name_prefix = "atu-request-tracker-"
  description = "Assignment server: no inbound access; managed through SSM"
  vpc_id      = "vpc-0c9b2d5568790b752"

  # No inbound rules initially.
  # Outbound access supports updates, image downloads and Systems Manager.
  egress {
    description = "Outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "atu-request-tracker"
  }
}

resource "aws_instance" "server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "c7i-flex.large"
  subnet_id     = "subnet-06a85f510471bbfa3"

  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.server.id]
  iam_instance_profile        = data.aws_iam_instance_profile.server.name

  # Require IMDSv2 and limit metadata access through network hops.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "atu-request-tracker"
  }
}

output "instance_id" {
  description = "EC2 instance used for the assignment"
  value       = aws_instance.server.id
}

output "public_ip" {
  description = "Public IP; inbound access is initially blocked"
  value       = aws_instance.server.public_ip
}