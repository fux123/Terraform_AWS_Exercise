This code defines and provisions an AWS infrastructure that includes 
a VPC, an internet gateway, two subnets, a route table, a security group, an EC2 instance, an Elastic IP address, and an elastic load balancer.
It sets up a basic Apache web server on the EC2 instance and allows inbound HTTP, HTTPS, and SSH traffic through a security group.


To run this script, follow the steps below:

Install the AWS CLI on your local machine.
Install the Terraform on your local machine.
Configure your AWS credentials using the command `aws configure`.
Navigate to the directory containing the script.
Run `terraform init` to initialize the working directory.
Run `terraform plan` to create an execution plan.
Run `terraform apply` to apply the changes and create the infrastructure.
