provider "aws" {
  region= "ap-south-1"
  profile="riya"
}

//Creating our own VPC giving your own cidr block
resource "aws_vpc" "main" {
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  tags = {
    Name = "myvpc"
  }
}

//creating public subnet having public mapped to each instance launched here
resource "aws_subnet" "main1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "my_public_subnet_1a"
  }
  depends_on=[aws_vpc.main,]
}

//creating private subnet that doent have public Ip to the instances launched here
resource "aws_subnet" "main2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "my_private_subnet_1b"
  }
  depends_on=[aws_vpc.main,]
}

//creating an internet gateway so that internal routers can go outside and vice-versa
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "my_igw"
  }
  depends_on=[aws_vpc.main,]
}

//Creating a Routing Table and adding route
resource "aws_route_table" "r" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "my_routing_table_public"
  }
  depends_on=[aws_vpc.main,aws_internet_gateway.gw,]
}


//Associating the routing table to our public subnet

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main1.id
  route_table_id = aws_route_table.r.id
  depends_on=[aws_route_table.r,aws_subnet.main1,]
}

//Creating EIP for NAT gateway
resource "aws_eip" "eip" {
vpc = true
}


//Creating NAT gateway for private instances
resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.main1.id


  tags = {
    Name = "NAT-gw"
  }
depends_on=[aws_subnet.main1, aws_eip.eip]
}

//Creating a routing table for NAT gateway 
resource "aws_route_table" "r2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "my_routing_table_private"
  }
  depends_on=[aws_vpc.main,aws_internet_gateway.gw,]
}

//Associating the routing table to our private subnet

resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.main2.id
  route_table_id = aws_route_table.r2.id
  depends_on=[aws_route_table.r2,aws_subnet.main2,]
}

//Creating the security group for wordpress app
resource "aws_security_group" "sg1" {
  name        = "wp-sg"
  description = "Allow ssh and http "
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow custom tcp"
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wp-sg"
  }
  depends_on=[aws_vpc.main,]

}

//Creating security group for Bashion Host
resource "aws_security_group" "sg2" {
  name        = "bashion-sg"
  description = "Allow ssh  "
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bashion_host-sg"
  }
 depends_on=[aws_vpc.main,]
}


//Creating the security group for database
resource "aws_security_group" "sg3" {
  name        = "mysql-sg"
  description = "Allow security groups and check connectivity"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "allow wp-sg"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.sg1.id]
  }
  ingress {
    description = "allow bashion-sg"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.sg2.id]
  }
  ingress {
    description = "Allowing ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql-sg"
  }
  depends_on=[aws_vpc.main,aws_security_group.sg1,aws_security_group.sg2,]
}

//creating instance for Bashion Host
resource "aws_instance" "web" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name = "tera"
  security_groups = [aws_security_group.sg2.id]
  subnet_id = aws_subnet.main1.id
  tags = {
    Name = "bashion-host"
  }
  depends_on = [aws_security_group.sg2,aws_subnet.main1,]
}

//Creating instance for WordPress
resource "aws_instance" "web1" {
  ami           = "ami-0ebc1ac48dfd14136"
  instance_type = "t2.micro"
  key_name = "tera"
  security_groups = [aws_security_group.sg1.id]
  subnet_id = aws_subnet.main1.id
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/HP/Downloads/tera.pem")
    host     = aws_instance.web.public_ip
  }
  provisioner "remote-exec" {
    inline = [
     
     "sudo yum install docker -y",
     "sudo systemctl start docker",
     "sudo systemctl enable docker",
     "sudo docker run -dit --name web -p 81:80 wordpress",
   ]
  }

  tags = {
    Name = "Wordpress"
  }
  depends_on = [aws_security_group.sg1,aws_subnet.main1,]
}

//Creating instance for MySql
resource "aws_instance" "web2" {
  ami           = "ami-0ebc1ac48dfd14136"
  instance_type = "t2.micro"
  key_name = "tera"
  vpc_security_group_ids= [aws_security_group.sg3.id]
  subnet_id = aws_subnet.main2.id
  associate_public_ip_address = false
  user_data = <<EOF
     #! /bin/bash
     sudo yum install docker -y
     sudo systemctl start docker
     sudo docker run --name mydb -e MYSQL_ROOT_PASSWORD=redhat -e MYSQL_USER=aditi -e MYSQL_PASSWORD=redhat -e MYSQL_DATABASE=wpdb  -d mysql:5.7
  EOF
  
  tags = {
    Name = "mysql"
  }
  depends_on=[aws_security_group.sg3,aws_subnet.main2,]
}

output "mysql_private_ip" {
value=aws_instance.web2.private_ip
}

output "public_ip" {
value=aws_instance.web1.public_ip
}































































