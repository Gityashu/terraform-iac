

# Create a VPC 
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}


# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a" # Example AZ, adjust as needed
  map_public_ip_on_launch = true                 # Instances in this subnet will get a public IP

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


# Create a Security Group for the EC2 instance
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow SSH, HTTP, HTTPS inbound traffic"
  vpc_id      = aws_vpc.main.id

  # Inbound rules
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# Create an IAM Role for the EC2 instance to allow CloudWatch access
resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "${var.project_name}-ec2-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = ["sts:AssumeRole"
        ],
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-cloudwatch-role"
  }
}




resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create an IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name
}

# --- EC2 Instance Creation ---

# Find the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create the EC2 instance
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_type
  key_name                    = var.key_pair_name
  subnet_id                   = aws_subnet.public.id
  security_groups             = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true # Ensure public IP is assigned
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name


  user_data = <<-EOF
              #!/bin/bash
              # Update the system
              sudo yum update -y

              # Install Apache web server and PHP
              sudo yum install -y httpd php

              # Start Apache and enable it to start on boot
              sudo systemctl start httpd
              sudo systemctl enable httpd

              # Create a simple PHP application file
              echo '<?php
              echo "<h1>Hello from my Terraform-deployed App!</h1>";
              echo "<p>This page was deployed automatically by Terraform.</p>";
              echo "<p>Current time: " . date("Y-m-d H:i:s") . "</p>";
              ?>' | sudo tee /var/www/html/index.php

              # Set correct permissions for the web server
              sudo usermod -a -G apache ec2-user
              sudo chown -R ec2-user:apache /var/www/html
              sudo find /var/www/html -type d -exec chmod 2775 {} \;
              sudo find /var/www/html -type f -exec chmod 0664 {} \;

              # Restart Apache to ensure the new PHP file is loaded
              sudo systemctl restart httpd
              EOF


  tags = {
    Name = "${var.project_name}-web-server"
  }
}
# --- CloudWatch Monitoring  ---

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "ec2_dashboard" {
  dashboard_name = "${var.project_name}-EC2-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric",
        x      = 0,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/EC2", "CPU Utilization", "Insta nceId", "aws_instance.web_server.id"]
          ],
          period = 300,
          stat   = "Average",
          region = var.aws_region,
          title  = "EC2 CPU Utilization"
        }
      }
    ]
  })
}

# CloudWatch Alarm for CPU Utilization (still works with AWS/EC2 metrics)
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "${var.project_name}-EC2-CPU-High-Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPU Utilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80 # Trigger if CPU is >= 80%
  alarm_description   = "This alarm monitors EC2 CPU utilization"
  actions_enabled     = true
  alarm_actions       = [] # Add SNS topic ARN here for notifications
  ok_actions          = [] # Add SNS topic ARN here for notifications

  dimensions = {
    InstanceId = aws_instance.web_server.id
  }

  tags = {
    Name = "${var.project_name}-EC2-CPU-High-Alarm"
  }
}


# --- S3 Main Bucket Resource ---
resource "aws_s3_bucket" "example_bucket" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = "${var.project_name2}-data-bucket"
    Environment = "Development"
  }
}

# --- Dedicated Resource for S3 Main Bucket Versioning ---
resource "aws_s3_bucket_versioning" "example_bucket_versioning" {
  bucket = aws_s3_bucket.example_bucket.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# --- Dedicated Resource for S3 Main Bucket Server-Side Encryption Configuration ---
resource "aws_s3_bucket_server_side_encryption_configuration" "example_bucket_sse" {
  bucket = aws_s3_bucket.example_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- Dedicated Resource for S3 Main Bucket Public Access Block ---
resource "aws_s3_bucket_public_access_block" "example_bucket_public_access_block" {
  bucket = aws_s3_bucket.example_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Dedicated Resource for S3 Main Bucket Ownership Controls ---
resource "aws_s3_bucket_ownership_controls" "example_bucket_ownership_controls" {
  bucket = aws_s3_bucket.example_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# --- S3 Logging Bucket Resource ---
# This bucket will store access logs for the main S3 bucket.
# It must exist before the logging configuration is applied to the main bucket.
resource "aws_s3_bucket" "logging_bucket" {
  bucket = "${var.s3_logging_bucket_name_prefix}-${data.aws_caller_identity.current.account_id}"
  #acl    = "log-delivery-write" # Special ACL for log delivery

  tags = {
    Name        = "${var.project_name2}-logging-bucket"
    Environment = "Development"
  }
}


data "aws_caller_identity" "current" {}


