provider "aws" {
  region = "ap-northeast-2"
}

# ✅ VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "eks-vpc"
  }
}

# ✅ Internet Gateway (EC2가 인터넷에 나가기 위한 출구)
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-igw"
  }
}

# ✅ 퍼블릭용 Route Table (퍼블릭 서브넷이 인터넷과 통신 가능하게 함)
resource "aws_route_table" "eks_public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = "eks-public-rt"
  }
}

# ✅ 퍼블릭 서브넷 A (AZ: 2a)
resource "aws_subnet" "public_subnet_a" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-2a"
  map_public_ip_on_launch = true # ✅ 수정됨

  tags = {
    Name = "eks-public-a"
  }
}

# ✅ 퍼블릭 서브넷 C (AZ: 2c)
resource "aws_subnet" "public_subnet_c" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2c"
  map_public_ip_on_launch = true # ✅ 수정됨

  tags = {
    Name = "eks-public-c"
  }
}

# ✅ 퍼블릭 서브넷 A와 퍼블릭 라우트 테이블 연결
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.eks_public_rt.id
}

# ✅ 퍼블릭 서브넷 C와 퍼블릭 라우트 테이블 연결
resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_subnet_c.id
  route_table_id = aws_route_table.eks_public_rt.id
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

# ✅ 이미 존재하는 워커 노드용 IAM Role 참조
data "aws_iam_role" "worker_node_role" {
  name = "eks-worker-node-role"
}

# ✅ EKS Cluster용 정책 연결
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = data.aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ✅ EKS 클러스터 생성
resource "aws_eks_cluster" "eks_cluster" {
  name     = "eks-gitops-cluster"
  role_arn = data.aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.public_subnet_a.id,
      aws_subnet.public_subnet_c.id
    ]
    security_group_ids = [aws_security_group.eks_worker_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# ✅ EKS Node Group (조건부 생성)
resource "aws_eks_node_group" "eks_node_group" {
  count         = var.create_nodegroup ? 1 : 0
  cluster_name  = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks-node-group"
  node_role_arn = data.aws_iam_role.worker_node_role.arn

  subnet_ids = [
    aws_subnet.public_subnet_a.id,
    aws_subnet.public_subnet_c.id
  ]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.small"]

  tags = {
    Name = "eks-node-group"
  }
}

# ✅ 클러스터 인증용 토큰 데이터
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks_cluster.name
}

# ✅ Kubernetes Provider (Terraform이 클러스터에 연결되도록 함)
provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}