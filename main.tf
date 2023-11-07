# TODO: refactor to modules
# EC2 creation
module "ec2_frp" {
  source            = "./modules/aws_ec2"
  ec2_instance_name = "fast reverse proxy"
  subnet_id         = aws_subnet.public_subnet[0].id
  security_groups   = [aws_security_group.sg_cpc.id]
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# VPC creation
resource "aws_vpc" "vpc_cpc" {
  cidr_block           = "10.0.0.0/16" # Define the IP address range for your VPC
  enable_dns_support   = true
  enable_dns_hostnames = true
}

## subnets
resource "aws_subnet" "public_subnet" {
  count                   = 1
  vpc_id                  = aws_vpc.vpc_cpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet" {
  count             = 1
  vpc_id            = aws_vpc.vpc_cpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1b"
}

resource "aws_subnet" "isolated_subnet" {
  count             = 1
  vpc_id            = aws_vpc.vpc_cpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-central-1c"
}

# security group
resource "aws_security_group" "sg_cpc" {
  name        = "example-security-group"
  description = "Example security group for instances in the VPC"

  // Define your security group rules here for inbound and outbound traffic.
  // For example, allow SSH access, HTTP, and HTTPS.
  ingress {
    description = "instance ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "doska-dominik"
    from_port   = 6000
    to_port     = 6000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "range for cpc devices"
    from_port   = 6100
    to_port     = 6300
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "frp server"
    from_port   = 7000
    to_port     = 7000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
