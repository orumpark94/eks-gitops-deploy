provider "aws" {
  region = "ap-northeast-2"
}

# IAM Role for NodeGroup
resource "aws_iam_role" "worker_node_role" {
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

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
  role       = aws_iam_role.worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# NodeGroup 정의
resource "aws_eks_node_group" "worker_group" {
  cluster_name    = "eks-gitops-cluster"
  node_group_name = "worker-group"
  node_role_arn   = aws_iam_role.worker_node_role.arn

  subnet_ids = [
  aws_subnet.public_subnet_a.id,
  aws_subnet.public_subnet_c.id
  ]

  instance_types = ["t3.medium"]

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
