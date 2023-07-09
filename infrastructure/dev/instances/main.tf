

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
    description      = "HTTP for APP"
    from_port        = 30000
    to_port          = 30000
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
  provisioner "file" {
    source      = "/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/my_app.yaml"
    destination = "/home/ec2-user/my_app.yml"  # Replace with the destination path on the EC2 instance
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/assignment2-dev")  # Path to your private key file
      host        = aws_instance.my_amazon.public_ip
    }
    
  }
    provisioner "file" {
    source      = "/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/my_db.yaml"
    destination = "/home/ec2-user/my_db.yml"  # Replace with the destination path on the EC2 instance
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/assignment2-dev")  # Path to your private key file
      host        = aws_instance.my_amazon.public_ip
    }
  }
    provisioner "file" {
    source      = "/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/service_app.yml"
    destination = "/home/ec2-user/service_app.yml"  # Replace with the destination path on the EC2 instance
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/assignment2-dev")  # Path to your private key file
      host        = aws_instance.my_amazon.public_ip
    }
  }
    provisioner "file" {
    source      = "/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/service_db.yml"
    destination = "/home/ec2-user/service_db.yml"  # Replace with the destination path on the EC2 instance
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/assignment2-dev")  # Path to your private key file
      host        = aws_instance.my_amazon.public_ip
    } 
    provisioner "file" {
    source      = "/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/replicaset_db.yml"
    destination = "/home/ec2-user/replicaset_db.yml"  # Replace with the destination path on the EC2 instance
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/assignment2-dev")  # Path to your private key file
      host        = aws_instance.my_amazon.public_ip
    }  
    provisioner "file" {
    source      = "/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/replicaset_app.yml"
    destination = "/home/ec2-user/replicaset_app.yml"  # Replace with the destination path on the EC2 instance
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/assignment2-dev")  # Path to your private key file
      host        = aws_instance.my_amazon.public_ip
    }  
    provisioner "file" {
    source      = "/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/app-deployment.yml"
    destination = "/home/ec2-user/app-deployment.yml"  # Replace with the destination path on the EC2 instance
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/assignment2-dev")  # Path to your private key file
      host        = aws_instance.my_amazon.public_ip
    }  
    provisioner "file" {
    source      = "/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/db-deployment.yml"
    destination = "/home/ec2-user/db-deployment.yml"  # Replace with the destination path on the EC2 instance
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("/home/ec2-user/environment/assignment2/clo835_summer2023_assignment2/infrastructure/dev/instances/assignment2-dev")  # Path to your private key file
      host        = aws_instance.my_amazon.public_ip
    }      
    }

  lifecycle {
    create_before_destroy = true
  }
  
  user_data  =<<-EOF
                   #!/bin/bash
                   mkdir /home/ec2-user/.aws
                   echo -en 'kind: Cluster\napiVersion: kind.x-k8s.io/v1alpha4\nnodes:\n- role: control-plane\n  image: kindest/node:v1.19.11@sha256:07db187ae84b4b7de440a73886f008cf903fcf5764ba8106a9fd5243d6f32729\n  extraPortMappings:\n  - containerPort: 30000\n    hostPort: 30000\n  - containerPort: 30001\n    hostPort: 30001\n' > /home/ec2-user/kind.yml                 
                   echo -en '[default]\naws_access_key_id=ASIAWUZKHOSJR6JKKBHR\naws_secret_access_key=AkCSUbQPOS/K2ZhlZdb2HkaJtu7gf5NgCk6uBHZY\naws_session_token=FwoGZXIvYXdzECwaDFwea/DMzbgGomMAISLRAZxM+zNWWh6PjMdCnoSSADZOfMzOjMQI0bdRTmG7GAl/824wQX5AghmQsIfXJXDLC5NGy2Uc8PodAlYpS0vXTNVD21B2qRFQhQiQSFPiTCe0YOV+FQC9roTbSKXLrhUVtFdnOq0CbfWPhCIbBZ6diPmGPRgHoiaqN/KqlrufLbtNQHcRDe9o9XTYP1mC7JUXvXzUHoIuBkuu9rAKKDZTgqdasRgNk7gcVoYp30o1HmfTjhId23sUw7bDuhj2S9T3wFnprG8QvIYEUe2xXk5ks7EPKNb9q6UGMi11gQTptOSh+jLDSdn91jtTzzR8vBleJLrkY5I1YBgxcD2ho68t/h4gSN1ZPOk=' > /home/ec2-user/.aws/credentials
                   et -ex
                   sudo yum update -y
                   sudo yum install docker -y
                   sudo systemctl start docker
                   sudo usermod -a -G docker ec2-user
                   curl -sLo kind https://kind.sigs.k8s.io/dl/v0.11.0/kind-linux-amd64
                   sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
                   rm -f ./kind
                   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
                   rm -f ./kubectl
                   sudo su - ec2-user
                   kind create cluster --config /home/ec2-user/kind.yml
                   sudo su - ec2-user
                   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 456965715091.dkr.ecr.us-east-1.amazonaws.com
                   kubectl create secret generic ecr-credentials --from-file=.dockerconfigjson=$HOME/.docker/config.json --type=kubernetes.io/dockerconfigjson
            EOF


  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-Amazon-Linux"
    }
  )
  
  depends_on = [null_resource.docker_login]

}