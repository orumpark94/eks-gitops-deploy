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

# ✅ 모든 IAM Role 중 eks-worker-node-role이 존재하는지 조회
data "aws_iam_roles" "all_roles" {
  name_regex = "^eks-worker-node-role$"
}

# ✅ Role 존재 여부 판단
locals {
  use_existing_role     = length(data.aws_iam_roles.all_roles.names) > 0
  worker_node_role_name = "eks-worker-node-role"
}

# ✅ Role 생성 (존재하지 않을 경우에만 생성)
resource "aws_iam_role" "worker_node_role" {
  count = local.use_existing_role ? 0 : 1

  name = local.worker_node_role_name

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

# ✅ 실제 사용할 Role의 ARN (셋 → 리스트 변환 후 안전하게 인덱싱)
locals {
  existing_role_arn = try(tolist(data.aws_iam_roles.all_roles.arns)[0], null)
  new_role_arn      = try(aws_iam_role.worker_node_role[0].arn, null)

  worker_node_role_arn = local.use_existing_role ? local.existing_role_arn : local.new_role_arn
}

# ✅ 정책 연결 (Role을 새로 생성한 경우에만)
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  count      = local.use_existing_role ? 0 : 1
  role       = aws_iam_role.worker_node_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  count      = local.use_existing_role ? 0 : 1
  role       = aws_iam_role.worker_node_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
  count      = local.use_existing_role ? 0 : 1
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

  instance_types = ["t2.micro"]

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
