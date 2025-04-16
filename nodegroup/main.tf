provider "aws" {
  region = "ap-northeast-2"
}

# ✅ 기존 VPC 상태에서 서브넷 ID 및 VPC ID 가져오기
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "eks-gitops-tfstate-20250415"
    key    = "eks/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ✅ 최신 EKS 1.28 노드용 AMI 자동 조회 (서울 리전)
data "aws_ami" "eks_node" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-node-1.28-v*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["602401143452"] # EKS 공식 AMI 제공 계정
}

# ✅ 기본 Security Group 리소스 정의
resource "aws_default_security_group" "default" {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
}

# ✅ eks-worker-node-role 존재 여부 체크
data "aws_iam_roles" "all_roles" {
  name_regex = "^eks-worker-node-role$"
}

locals {
  use_existing_role     = length(data.aws_iam_roles.all_roles.names) > 0
  worker_node_role_name = "eks-worker-node-role"
}

# ✅ IAM Role 생성 (존재하지 않을 경우)
resource "aws_iam_role" "worker_node_role" {
  count = local.use_existing_role ? 0 : 1
  name  = local.worker_node_role_name

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

locals {
  existing_role_arn     = try(tolist(data.aws_iam_roles.all_roles.arns)[0], null)
  new_role_arn          = try(aws_iam_role.worker_node_role[0].arn, null)
  worker_node_role_arn  = local.use_existing_role ? local.existing_role_arn : local.new_role_arn
}

# ✅ 필요한 정책 연결 (EKS + SSM)
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

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  count      = local.use_existing_role ? 0 : 1
  role       = aws_iam_role.worker_node_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ✅ 인스턴스 프로파일
resource "aws_iam_instance_profile" "worker_node_instance_profile" {
  name = "eks-worker-instance-profile"
  role = local.worker_node_role_name
}

# ✅ EC2 인스턴스 생성 (SSM 연결 전용)
resource "aws_instance" "eks_worker" {
  ami                         = data.aws_ami.eks_node.id  # ✅ 자동 조회된 AMI 사용
  instance_type               = "t2.nano"
  subnet_id                   = data.terraform_remote_state.vpc.outputs.public_subnet_a_id
  iam_instance_profile        = aws_iam_instance_profile.worker_node_instance_profile.name
  associate_public_ip_address = false   # 내부 전용 인스턴스
  vpc_security_group_ids      = [aws_default_security_group.default.id]

  tags = {
    Name = "eks-self-managed-worker"
  }
}
