provider "aws" {
  region = "ap-northeast-2"
}

# ✅ 기존 VPC 및 EKS 클러스터 상태 불러오기
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "eks-gitops-tfstate-20250415"
    key    = "eks/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ✅ Role 이름 및 존재 여부 체크
locals {
  worker_node_role_name = "eks-worker-node-role"
}

data "aws_iam_roles" "existing" {
  name_regex = "^${local.worker_node_role_name}$"
}

locals {
  use_existing_role = length(data.aws_iam_roles.existing.names) > 0
}

# ✅ 기존 Role의 ARN (존재 시만 조회)
data "aws_iam_role" "existing_worker_role" {
  count = local.use_existing_role ? 1 : 0
  name  = local.worker_node_role_name
}

# ✅ Role 생성 (없을 때만 생성)
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

# ✅ 필요한 정책 부착 (역할 새로 만든 경우만)
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  count      = local.use_existing_role ? 0 : 1
  role       = local.worker_node_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  count      = local.use_existing_role ? 0 : 1
  role       = local.worker_node_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
  count      = local.use_existing_role ? 0 : 1
  role       = local.worker_node_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  count      = local.use_existing_role ? 0 : 1
  role       = local.worker_node_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ✅ 최종적으로 사용할 Role ARN 선택
locals {
  worker_node_role_arn = coalesce(
    try(data.aws_iam_role.existing_worker_role[0].arn, null),
    try(aws_iam_role.worker_node_role[0].arn, null)
  )
}

# ✅ Managed NodeGroup 생성
resource "aws_eks_node_group" "worker_node_group" {
  cluster_name    = data.terraform_remote_state.vpc.outputs.eks_cluster_name
  node_group_name = "eks-managed-node-group"
  node_role_arn   = local.worker_node_role_arn

  subnet_ids = [
    data.terraform_remote_state.vpc.outputs.public_subnet_a_id,
    data.terraform_remote_state.vpc.outputs.public_subnet_c_id
  ]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.small"]

  tags = {
    Name = "eks-managed-node-group"
  }

  depends_on = [
    aws_iam_role.worker_node_role
  ]
}
