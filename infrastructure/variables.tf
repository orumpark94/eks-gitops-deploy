variable "aws_region" {
  description = "AWS region to deploy EKS"
  type        = string
}

variable "cluster_name" {
  description = "Name of EKS Cluster"
  type        = string
}

variable "cluster_role_name" {
  description = "IAM Role name for EKS (already exists)"
  type        = string
}
