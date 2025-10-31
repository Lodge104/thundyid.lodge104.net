variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Base domain name (e.g., thundyid.lodge104.net)"
  type        = string
  default     = "thundyid.lodge104.net"
}

variable "media_subdomain" {
  description = "Media subdomain (e.g., media.thundyid.lodge104.net)"
  type        = string
  default     = "media.thundyid.lodge104.net"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for media files"
  type        = string
  default     = "thundyid-lodge104-media"
}

variable "iam_username" {
  description = "IAM username for media access"
  type        = string
  default     = "media-access-user"
}
