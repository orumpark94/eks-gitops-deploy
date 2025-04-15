provider "aws" {
    region = "ap-northeast-2"
  }
  
  # ✅ 기존 VPC 재사용
  data "aws_vpc" "eks_vpc" {
    filter {
      name   = "tag:Name"
      values = ["eks-vpc"]
    }
  }
  
  # ✅ 기존 Subnet 재사용 (각 AZ)
  data "aws_subnet" "public_subnet_a" {
    filter {
      name   = "tag:Name"
      values = ["eks-public-a"]
    }
  
    filter {
      name   = "vpc-id"
      values = [data.aws_vpc.eks_vpc.id]
    }
  }
  
  data "aws_subnet" "public_subnet_c" {
    filter {
      name   = "tag:Name"
      values = ["eks-public-c"]
    }
  
    filter {
      name   = "vpc-id"
      values = [data.aws_vpc.eks_vpc.id]
    }
  }
  
  # ✅ 이미 존재하는 EKS Cluster IAM Role 참조
  data "aws_iam_role" "eks_cluster_role" {
    name = "eksClusterRole"
  }
  
  # ✅ (선택) 정책 연결 - 이미 붙어 있다면 생략 가능
  resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
    role       = data.aws_iam_role.eks_cluster_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  }
  
  # ✅ EKS Cluster 생성
  resource "aws_eks_cluster" "eks_cluster" {
    name     = "eks-gitops-cluster"
    role_arn = data.aws_iam_role.eks_cluster_role.arn
  
    vpc_config {
      subnet_ids = [
        data.aws_subnet.public_subnet_a.id,
        data.aws_subnet.public_subnet_c.id
      ]
    }
  
    depends_on = [
      aws_iam_role_policy_attachment.eks_cluster_policy
    ]
  }
  