provider "aws" {
  region = "ap-northeast-2"
}

# ✅ VPC (존재하면 import, 없으면 생성)
resource "aws_vpc" "eks_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "eks-vpc"
  }
}

# ✅ 퍼블릭 서브넷 A (AZ: 2a)
resource "aws_subnet" "public_subnet_a" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "eks-public-a"
  }
}

# ✅ 퍼블릭 서브넷 C (AZ: 2c)
resource "aws_subnet" "public_subnet_c" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "eks-public-c"
  }
}

# ✅ EC2 워커 노드용 보안 그룹
resource "aws_security_group" "eks_worker_sg" {
  name        = "eks-worker-sg"
  description = "Allow EKS worker node communication"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.eks_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-worker-sg"
  }
}

# ✅ 이미 존재하는 EKS Cluster IAM Role 참조
data "aws_iam_role" "eks_cluster_role" {
  name = "eksClusterRole"
}

# ✅ 정책 연결 (필요 시)
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
      aws_subnet.public_subnet_a.id,
      aws_subnet.public_subnet_c.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}
