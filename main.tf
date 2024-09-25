terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.5"
    }
  }
  required_version = ">= 1.7"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main_vpc"
  }
}

# Internet gateway that is associated with the main vpc
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "ig"
  }
}

# A public subnet that will host the Network interface allowing http request from the internet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "public_subnet"
  }
}

# A private management subnet that will host the Network interface allowing ssh request only from Management subnet
resource "aws_subnet" "management_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "management_subnet"
  }
}

# The route table that will allow access to the internet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }

  tags = {
    Name = "public_route_table"
  }
}

# Explicitly associating the route tabel with the public subnet
resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow http traffic through port 80"
  vpc_id      = aws_vpc.main_vpc.id

  tags = {
    Name = "allow_http"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_http" {
  security_group_id = aws_security_group.allow_http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# A security group rule which allows ssh connection from users in the management subnet
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh traffic from the management subnet through port 22"
  vpc_id      = aws_vpc.main_vpc.id

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "10.0.2.0/24"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_ssh" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# A network interface that will be hosted in the public subnet with allow_http security group attached
resource "aws_network_interface" "public_network_interface" {
  subnet_id       = aws_subnet.public_subnet.id
  private_ips     = ["10.0.1.10"]
  security_groups = [aws_security_group.allow_http.id]

  tags = {
    Name = "public_network_interface"
  }
}

# An elastic Ip to give a public ip to the public network interface
resource "aws_eip" "elastic_ip" {
  network_interface = aws_network_interface.public_network_interface.id
  vpc               = true
  depends_on        = [aws_instance.web_server]

  tags = {
    Name = "elastic_ip"
  }
}

# A network interface that will allow ssh traffic through port 22 from the management subnet 
resource "aws_network_interface" "management_network_interface" {
  subnet_id       = aws_subnet.management_subnet.id
  private_ips     = ["10.0.2.10"]
  security_groups = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "management_network_interface"
  }
}

# RSA key of size 4096 
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "TF_key" {
  key_name   = "TF_key"
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "ssh_key" {
  content  = tls_private_key.pk.private_key_openssh
  filename = "${aws_key_pair.TF_key.key_name}.pem"
}

data "aws_ami" "amazon_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

resource "aws_instance" "web_server" {
  instance_type = "t3.micro"
  ami           = data.aws_ami.amazon_ami.id
  key_name      = aws_key_pair.TF_key.key_name

  network_interface {
    network_interface_id = aws_network_interface.public_network_interface.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.management_network_interface.id
    device_index         = 1
  }

  user_data = filebase64("scripts/user_data.sh")

  tags = {
    Name = "my_server"
  }

}