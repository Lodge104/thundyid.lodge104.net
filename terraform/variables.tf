# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Short project name used as prefix for resource names"
  type        = string
  default     = "thundyid"
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs (at least 2 for EKS)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# -----------------------------------------------------------------------------
# DNS / Domain
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "Application FQDN"
  type        = string
  default     = "thundyid.lodge104.net"
}

variable "route53_zone_name" {
  description = "Existing Route53 hosted zone name (parent domain)"
  type        = string
  default     = "lodge104.net"
}

# -----------------------------------------------------------------------------
# EKS
# -----------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.32"
}

# -----------------------------------------------------------------------------
# Aurora PostgreSQL
# -----------------------------------------------------------------------------

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "16.6"
}

variable "aurora_min_capacity" {
  description = "Minimum Aurora Serverless v2 ACU"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum Aurora Serverless v2 ACU"
  type        = number
  default     = 4
}

variable "aurora_database_name" {
  description = "Name of the database to create in Aurora"
  type        = string
  default     = "zitadel"
}

variable "aurora_master_username" {
  description = "Master (admin) username for Aurora"
  type        = string
  default     = "zitadeladmin"
}

# -----------------------------------------------------------------------------
# ElastiCache (Valkey)
# -----------------------------------------------------------------------------

variable "valkey_node_type" {
  description = "ElastiCache node type for Valkey"
  type        = string
  default     = "cache.t4g.micro"
}

variable "valkey_engine_version" {
  description = "Valkey engine version"
  type        = string
  default     = "7.2"
}

# -----------------------------------------------------------------------------
# Zitadel
# -----------------------------------------------------------------------------

variable "zitadel_chart_version" {
  description = "Zitadel Helm chart version"
  type        = string
  default     = "9.2.0"
}

variable "zitadel_namespace" {
  description = "Kubernetes namespace for Zitadel"
  type        = string
  default     = "zitadel"
}

variable "zitadel_admin_username" {
  description = "Initial admin username for Zitadel"
  type        = string
  default     = "admin"
}

variable "zitadel_admin_email" {
  description = "Initial admin email for Zitadel"
  type        = string
  default     = "admin@lodge104.net"
}

variable "zitadel_admin_first_name" {
  description = "Initial admin first name"
  type        = string
  default     = "Zitadel"
}

variable "zitadel_admin_last_name" {
  description = "Initial admin last name"
  type        = string
  default     = "Admin"
}

variable "zitadel_admin_password" {
  description = "Initial admin password for Zitadel (change on first login)"
  type        = string
  sensitive   = true
  default     = "ThundyId-Ch4ng3Me!"
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
