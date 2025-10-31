output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.media.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.media.arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.media.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.media.domain_name
}

output "media_domain_url" {
  description = "Custom domain URL for media"
  value       = "https://${var.media_subdomain}"
}

output "iam_user_name" {
  description = "IAM user name for media access"
  value       = aws_iam_user.media_user.name
}

output "iam_access_key_id" {
  description = "IAM access key ID"
  value       = aws_iam_access_key.media_user.id
}

output "iam_secret_access_key" {
  description = "IAM secret access key"
  value       = aws_iam_access_key.media_user.secret
  sensitive   = true
}

output "route53_record_name" {
  description = "Route53 record name"
  value       = aws_route53_record.media.name
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.media_cert.arn
}
