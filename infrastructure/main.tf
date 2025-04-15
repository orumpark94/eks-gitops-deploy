provider "aws" {
    region = "ap-northeast-2"
  }
  
  # ✅ 새 VPC 생성
  resource "aws_vpc" "eks_vpc" {
    cidr_block           = "10.0.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true
  
    tags = {
      Name = "eks-vpc"
    }
  }
  
  # ✅ 퍼블릭 서브넷 2개 생성 (다른 AZ에 배포)
  resource "aws_subnet" "public_subnet_a" {
    vpc_id            = aws_vpc.eks_vpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "ap-northeast-2a"
  
    tags = {
      Name = "eks-public-a"
    }
  }
  
  resource "aws_subnet" "public_subnet_c" {
    vpc_id            = aws_vpc.eks_vpc.id
    cidr_block        = "10.0.2.0/24"
    availability_zone = "ap-northeast-2c"
  
    tags = {
      Name = "eks-public-c"
    }
  }
  
  # ✅ IAM Role for EKS Cluster
  data "aws_iam_role" "eks_cluster_role" {
    name = "eksClusterRole"
  
    assume_role_policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Principal = {
            Service = "eks.amazonaws.com"
          },
          Action = "sts:AssumeRole"
        }
      ]
    })
  }
  
  resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
    role       = aws_iam_role.eks_cluster_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  }
  
  # ✅ EKS Cluster
  resource "aws_eks_cluster" "eks_cluster" {
    name     = "eks-gitops-cluster"
    role_arn = aws_iam_role.eks_cluster_role.arn
  
    vpc_config {
      subnet_ids = [
        aws_subnet.public_subnet_a.id,
        aws_subnet.public_subnet_c.id
      ]
    }
  
    depends_on = [
      aws_iam_role_policy_attachment.eks_cluster_policy
    ]
  }
  