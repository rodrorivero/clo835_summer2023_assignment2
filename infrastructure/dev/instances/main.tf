

#----------------------------------------------------------
# ACS730 - Week 3 - Terraform Introduction
#
# Build EC2 Instances
#
#----------------------------------------------------------

#  Define the provider
provider "aws" {
  region = "us-east-1"
}

# Data source for AMI id
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_caller_identity" "current" {}

# Data source for availability zones in us-east-1
data "aws_availability_zones" "available" {
  state = "available"
}

# Data block to retrieve the default VPC id
data "aws_vpc" "default" {
  default = true
}

# Define tags locally
locals {
  default_tags = merge(module.globalvars.default_tags, { "env" = var.env })
  prefix       = module.globalvars.prefix
  name_prefix  = "${local.prefix}-${var.env}"
}

# Retrieve global variables from the Terraform module
module "globalvars" {
  source = "../../modules/globalvars"
}

# Adding SSH key to Amazon EC2
resource "aws_key_pair" "my_key" {
  key_name   = local.name_prefix
  public_key = file("${local.name_prefix}.pub")
}

# Security Group
resource "aws_security_group" "my_sg" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description      = "SSH from everywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  ingress {
    description      = "HTTP for APP1"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  ingress {
    description      = "Allow ping"
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP for APP2"
    from_port        = 8081
    to_port          = 8081
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  ingress {
    description      = "HTTP for APP3"
    from_port        = 8082
    to_port          = 8082
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-sg"
    }
  )
}


# Elastic IP
resource "aws_eip" "static_eip" {
  instance = aws_instance.my_amazon.id
  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-eip"
    }
  )
}

resource "null_resource" "docker_login" {
  provisioner "local-exec" {
    command = "aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 456965715091.dkr.ecr.us-east-1.amazonaws.com"
    environment = {
    aws_account_id = "${data.aws_caller_identity.current.account_id}"
    }
  }
}

resource "aws_instance" "my_amazon" {
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = lookup(var.instance_type, var.env)
  key_name                    = aws_key_pair.my_key.key_name
  vpc_security_group_ids             = [aws_security_group.my_sg.id]
  associate_public_ip_address = false

  lifecycle {
    create_before_destroy = true
  }
  
  user_data  =<<-EOF
                   #!/bin/bash
                   mkdir /root/.aws
                   echo -en '[default]\naws_access_key_id=ASIAWUZKHOSJSNPGNWZT\naws_secret_access_key=Uy3orQtY6DOE6BYY7godCCyvbYyreNhdqEkwBsUM\naws_session_token=FwoGZXIvYXdzEOD//////////wEaDCweAnr31//fWGxg0SLRAaiEyknJ7DVjeESbzqET2/2YSV1OpUzgXA7RiGcY6zKkv7KvLEQUwFRhOUuQeUXKq8ENuFCrjKVUuIwT54i1Lrzleut784u0DUInwlYLQUIneZKZ/k8SLEEZekh3trc1CoygcIdU5PmNC/vi0aP93uSaET/tlW7QbByPgNimOQ3eDK6astb3GBvaAiwj57LTYSgjljCpFB1b9qxaFX6fETEdcIkGFu0eBUXcAi8Vr9PRJpNxhxNBfPXr8JGxPMbhwFzcjemOcpey1YpnBTqggV2fKOTG8qMGMi1wFQPXi1osLkZPGYHdURzMbGcVAGrKzX65Rt7OpArEOE532AZWP8kpWrdLGgU=' > /root/.aws/credentials
                   yum install -y docker
                   export DBHOST=172.17.0.2
                   export DBPORT=3306
                   export DBUSER=root
                   export DATABASE=employees
                   export DBPWD=pw
                   service docker start
                   usermod -a -G docker ec2-user
                   chkconfig docker on
                   whoami
                   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 456965715091.dkr.ecr.us-east-1.amazonaws.com
                   docker run -d -e MYSQL_ROOT_PASSWORD=pw 456965715091.dkr.ecr.us-east-1.amazonaws.com/my-db:latest
                   docker run -d -p 8080:8080  -e DBHOST=$DBHOST -e DBPORT=$DBPORT -e  DBUSER=$DBUSER -e DBPWD=$DBPWD -e APP_COLOR="blue" --name instance1 456965715091.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
                   docker run -d -p 8081:8080  -e DBHOST=$DBHOST -e DBPORT=$DBPORT -e  DBUSER=$DBUSER -e DBPWD=$DBPWD -e APP_COLOR="pink" --name instance2 456965715091.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
                   docker run -d -p 8082:8080  -e DBHOST=$DBHOST -e DBPORT=$DBPORT -e  DBUSER=$DBUSER -e DBPWD=$DBPWD -e APP_COLOR="lime" --name instance3 456965715091.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
                 EOF


  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-Amazon-Linux"
    }
  )
  
  depends_on = [null_resource.docker_login]

}