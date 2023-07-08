

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
                   echo -en 'kind: Cluster\napiVersion: kind.x-k8s.io/v1alpha4\nnodes:\n- role: control-plane\n  image: kindest/node:v1.19.11@sha256:07db187ae84b4b7de440a73886f008cf903fcf5764ba8106a9fd5243d6f32729\n  extraPortMappings:\n  - containerPort: 30000\n    hostPort: 30000\n  - containerPort: 30001\n    hostPort: 30001\n' > /home/ec2-user/kind.yml                 
                   echo -en '[default]\naws_access_key_id=ASIAWUZKHOSJQ3N2VUVF\naws_secret_access_key=qAx5o/zSMZUqkyhJjV0Bs5soZaM+Wr/wTkQ1TOIg\naws_session_token=FwoGZXIvYXdzEBYaDMV06OAKXLI63DQXPiLRAR50PIs3M5rMeHvnv48LC9BqB+OxdGsr6ycutAoaV89+hRK9zl8LaO4ir6FaFN7ZIQ5qLWAeosWhap8NBI9FDfnzyANlg/jjLMUQTFoBCPUzeCDSBE3kmn/FYoKsi4/6WfayDS/pSnpkiHB/Ayjlpsw3oyqXWpbbW31W3rEJSydIBWicOCca5+9EuamgOEn+7YTpco1G42RlMMiWUzj00EaJbYDBKb9rX44XTInIJ7Xyp2bE5Tph2aeIbsB7v/x7WuudiqzcbAm9ybFC9MXiRE8MKL2dp6UGMi0We/aF0kXI7CP6Vq177XXl4dd0cpZDlxTyI/I0zpXKuvZCmkNl17sNJWrvsHM=' > /root/.aws/credentials
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
                   export DBHOST=172.18.0.2
                   export DBPORT=3306
                   export DBUSER=root
                   export DATABASE=employees
                   export DBPWD=pw
            EOF


  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-Amazon-Linux"
    }
  )
  
  depends_on = [null_resource.docker_login]

}