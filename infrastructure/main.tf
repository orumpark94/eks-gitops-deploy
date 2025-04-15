provider "aws" {
    region = var.aws_region
  }
  
  # Default VPC 참조
  data "aws_vpc" "default" {
    default = true
  }
  
  # Default VPC에 연결된 모든 서브넷 자동 수집
  data "aws_subnets" "selected" {
    filter {
      name   = "vpc-id"
      values = [data.aws_vpc.default.id]
    }
  }
  
  # 이미 존재하는 EKS 클러스터용 IAM Role 참조
  data "aws_iam_role" "eks_cluster_role" {
    name = var.cluster_role_name
  }
  
  # EKS 클러스터 생성
  resource "aws_eks_cluster" "eks_cluster" {
    name     = var.cluster_name
    role_arn = data.aws_iam_role.eks_cluster_role.arn
  
    vpc_config {
      subnet_ids = data.aws_subnets.selected.ids
    }
  }
  