# TASK:
# Write an infrastructure deployment automation script using a selected Terraform technology on the AWS platform.
# The task is meant to simulate a real scenario where developers created a node.js HTTP service/app which requires a relational database to work and needs to be accessible from the internet. 

# Some components which the infrastructure should include:
# -A load balancer.
# -At least one server instance responds to HTTP requests made to the load balancer created in point 1. (It would be nice if as part of point 2. you would deploy a real HTTP server e.g. nginx, apache with a default configuration that responds to requests.).
# -A relational database to which we can connect from the server instances created in point 2. (To simulate a real-life scenario where backend code connects to the database).

# Define the provider and the region
provider "aws" {
  region = "eu-central-1"
}

# Create a VPC with a CIDR block of 10.0.0.0/16
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"

 tags = {
    Name = "production"
  }
}
# Create an internet gateway and attach it to the VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

}
# Create a route table for the VPC and add a default route to the internet gateway
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  # Add a default IPv6 route to the internet gateway
  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}
# Create two subnets in different availability zones
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"

  availability_zone = "eu-central-1a"

  tags = {
    Name = "prod-subnet1"
  }
}

resource "aws_subnet" "subnet-2" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.2.0/24"

  availability_zone = "eu-central-1b"

  tags = {
    Name = "prod-subnet2"
  }
}
# Associate the route table with the subnets
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}
# Create a security group that allows inbound HTTP, HTTPS, and SSH traffic
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

    ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

    ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# Provision an AWS network interface for the web server
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Provision an Elastic IP address and associate it with the network interface
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  #depends_on = [aws_internet_gateway.gw]
}

# Provision an EC2 instance
resource "aws_instance" "web-server-instance" {
  ami           = "ami-0ec7f9846da6b0f61"
  instance_type = "t3.micro"
  availability_zone = "eu-central-1a"
  key_name = "main-key"
  
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  # Configure the EC2 instance to run an Apache web server
user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF

   tags = {
    Name = "web-server"
  }
}

# Create an elastic load balancer
resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web.id]

  subnet_mapping {
    subnet_id = aws_subnet.subnet-1.id
  }

    subnet_mapping {
    subnet_id = aws_subnet.subnet-2.id
  }

  tags = {
    Environment = "dev"
  }
}

# Create a target group for the load balancer
resource "aws_lb_target_group" "example" {
  name = "tf-example-lb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.prod-vpc.id
}

# Attach an instance to the target group
resource "aws_lb_target_group_attachment" "example" {
  target_group_arn = aws_lb_target_group.example.arn
  target_id        = aws_instance.web-server-instance.id
  port             = 80
}

# Create a listener for the load balancer
resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.example.arn
    type             = "forward"
  }
}
# Create an AWS RDS database instance with the following configuration
resource "aws_db_instance" "default" {
  allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "foo"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}
# Create a security group rule that allows inbound traffic to the database instance
resource "aws_security_group_rule" "example_ingress" {
  type        = "ingress"
  from_port   = 3306
  to_port     = 3306
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_web.id
}



