
variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "ap-south-1" 
}

variable "project_name" {
  description = "A unique name for your project, used for resource naming."
  type        = string
  default     = "my-terraform-ec2"
}

variable "instance_type" {
  description = "The EC2 instance type."
  type        = string
  default     = "t2.micro" 
}
variable "key_pair_name" {
  description = "The name of an existing EC2 Key Pair to use for SSH access."
  type        = string
  default     = "sever"
}



variable "project_name2" {
  description = "A unique name for your project, used for resource naming."
  type        = string
  default     = "my-terraform-s3"
}

variable "s3_bucket_name" {
  description = "The globally unique name for the S3 bucket."
  type        = string
  default     = "my-1234bucket"
}

variable "enable_versioning" {
  description = "Whether to enable versioning on the S3 bucket."
  type        = bool
  default     = true
}

variable "s3_logging_bucket_name_prefix" {
  description = "A prefix for the globally unique name of the S3 logging bucket."
  type        = string
  default     = "my-s3-logs-bucket2418" # A unique prefix, account ID will be appended
}