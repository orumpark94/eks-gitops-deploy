provider "aws" {
  region = "ap-northeast-2"
}

# ✅ 기존 subnet이 정의된 상태파일에서 ID 가져오기
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "eks-gitops-tfstate-20250415"
    key    = "eks/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ✅ 기존 IAM Role 조회 (존재할 경우)
data "aws_iam_role" "existing_worker_role" {
  name = "eks-worker-node-role"
  # 존재하지 않으면 오류가 나므로, 아래 error_handling 기능 사용 필요 (Terraform >= 1.3 이상)
  # optional
  # lifecycle {
  #   ignore_errors = true
  # }
}

# ✅ Role 생성 (존재하지 않을 경우에만 생성)
resource "aws_iam_role" "worker_node_role" {
  count = can(data.aws_iam_role.existing_worker_role.arn) ? 0 : 1

  name = "eks-worker-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# ✅ 실제 사용할 role의 ARN (기존 or 새로 생성된 것 중에서)
locals {
  worker_node_role_arn = can(data.aws_iam_role.existing_worker_role.arn)
    ? data.aws_iam_role.existing_worker_role.arn
    : aws_iam_role.worker_node_role[0].arn
}

# ✅ 정책 연결 (조건부 리소스)
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  count      = can(data.aws_iam_role.existing_worker_role.arn) ? 0 : 1
  role       = aws_iam_role.worker_node_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  count      = can(data.aws_iam_role.existing_worker_role.arn) ? 0 : 1
  role       = aws_iam_role.worker_node_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
  count      = can(data.aws_iam_role.existing_worker_role.arn) ? 0 : 1
  role       = aws_iam_role.worker_node_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ✅ NodeGroup 정의
resource "aws_eks_node_group" "worker_group" {
  cluster_name    = "eks-gitops-cluster"
  node_group_name = "worker-group"
  node_role_arn   = local.worker_node_role_arn

  subnet_ids = [
    data.terraform_remote_state.vpc.outputs.public_subnet_a_id,
    data.terraform_remote_state.vpc.outputs.public_subnet_c_id
  ]

  instance_types = ["t3.micro"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  ami_type = "AL2_x86_64"

  tags = {
    Name = "eks-worker-group"
  }
}
