
output "instance_id" {
  description = "The ID of the EC2 instance."
  value       = aws_instance.web_server.id
}

output "public_ip" {
  description = "The public IP address of the EC2 instance."
  value       = aws_instance.web_server.public_ip
}

output "public_dns" {
  description = "The public DNS name of the EC2 instance."
  value       = aws_instance.web_server.public_dns
}

output "security_group_id" {
  description = "The ID of the security group attached to the EC2 instance."
  value       = aws_security_group.ec2_sg.id
}



output "s3_bucket_id" {
  description = "The ID (name) of the S3 bucket."
  value       = aws_s3_bucket.example_bucket.id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket."
  value       = aws_s3_bucket.example_bucket.arn
}

output "s3_bucket_region" {
  description = "The AWS region where the S3 bucket is located."
  value       = aws_s3_bucket.example_bucket.region
}

output "s3_bucket_domain_name" {
  description = "The domain name of the S3 bucket."
  value       = aws_s3_bucket.example_bucket.bucket_domain_name
}