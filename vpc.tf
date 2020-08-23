provider "aws" {
  region     = "ap-south-1"
  profile = "rohit"
  
}
#VPC 
resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true 

  tags = {
    Name = "MyVPC"
  }
}
#subnet-1a
resource "aws_subnet" "subnet1" {
  vpc_id     =  aws_vpc.main.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "MyVPCSub-1a"
  }
}
#subnet-1b
resource "aws_subnet" "subnet2" {
  vpc_id     =  aws_vpc.main.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "MyVPCSub-1b"
  }
}
#Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "myIG"
  }
}
#Routing Table
resource "aws_route_table" "IG" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "IG"
  }
}
#Assosication
resource "aws_route_table_association" "subnet-a-ass" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.IG.id
}

#Webserver Security Group
resource "aws_security_group" "For-webserver" {
  name        = "webserver"
  description = "Allow http,ssh,ICMP"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "webserver"
  }
}


#Bastion Host Security Group
resource "aws_security_group" "For-bastion-Host" {
  name        = "BastionHost"
  description = "Allow ssh"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "BastionHost"
  }
}

#Mysql allowing only webserver
resource "aws_security_group_rule" "For-MysqlPort3306" {
  type              = "ingress"
  from_port = 3306
  to_port = 3306
  protocol = "tcp"
  security_group_id =  aws_security_group.MysqlPort3306.id
  source_security_group_id  = aws_security_group.For-webserver.id

}
resource "aws_security_group" "MysqlPort3306" {

  name        = "MysqlPort3306"
  description = "Allow 3306"
  vpc_id      = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MysqlPort3306"
  }
}
#Mysql Allowing Bastion Host security group
resource "aws_security_group_rule" "For-MysqlBastionHostSSh" {
  type              = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  security_group_id = aws_security_group.MysqlBastionHostSSh.id
  source_security_group_id  =  aws_security_group.For-bastion-Host.id

}
resource "aws_security_group" "MysqlBastionHostSSh" {

  name        = "MysqlBastionHostSSh"
  description = "Allow ssh"
  vpc_id      = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MysqlBastionHostSSh"
  }
}

#Creating Key
resource "tls_private_key" "Key_generator" {
  algorithm   = "RSA"
  rsa_bits  = "2048"
}
resource "local_file" "Store_KEY" {
    content     = tls_private_key.Key_generator.private_key_pem
    filename = "mykey.pem"
}
resource "aws_key_pair" "key" {
  key_name   = "key123"
  public_key = tls_private_key.Key_generator.public_key_openssh
}
#launching Instance
resource "aws_instance" "web" {
  depends_on = [
      aws_security_group.For-webserver,
      aws_key_pair.key
  ]
  ami           = "ami-01bca648bd8d02b3e"
  instance_type = "t2.micro"
  vpc_security_group_ids  = ["${aws_security_group.For-webserver.id}"]
  key_name  =  aws_key_pair.key.key_name
  subnet_id = aws_subnet.subnet1.id
  tags = {
    Name = "Webserver"
  }
}
resource "aws_instance" "BastionHost" {
  depends_on = [
      aws_security_group.For-bastion-Host,
      aws_key_pair.key
  ]
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  vpc_security_group_ids  = ["${aws_security_group.For-bastion-Host.id}"]
  key_name  =  aws_key_pair.key.key_name
  subnet_id = aws_subnet.subnet1.id
  tags = {
    Name = "BastionHost"
  }
 
}
resource "aws_instance" "Mysql" {
  depends_on = [
      aws_security_group.MysqlPort3306,
      aws_security_group.MysqlBastionHostSSh,
      aws_key_pair.key
  ]
  ami           = "ami-01dffa1205ae2def9"
  instance_type = "t2.micro"
  vpc_security_group_ids  = ["${aws_security_group.MysqlPort3306.id}","${aws_security_group.MysqlBastionHostSSh.id}"]
  key_name  =  aws_key_pair.key.key_name
  subnet_id = aws_subnet.subnet2.id
  tags = {
    Name = "Mysql"
  }
}
output "bastion"{
  value = aws_instance.BastionHost.public_ip
}
output "server"{
  value = aws_instance.web.public_ip
}
output "mysql"{
  value = aws_instance.Mysql.private_ip
}



resource "aws_eip" "lb" {
  vpc      = true
}
resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.lb.id
  subnet_id     = aws_subnet.subnet1.id
}
resource "aws_route_table" "sub2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.gw.id
  }
}
resource "aws_route_table_association" "subnet-NAT-ass" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.sub2.id
}