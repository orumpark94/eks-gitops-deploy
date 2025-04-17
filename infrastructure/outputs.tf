# ✅ VPC ID
output "vpc_id" {
  value = aws_vpc.eks_vpc.id
}

# ✅ EKS 클러스터 정보
output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

# ✅ (선택) Node Group 이름
output "eks_node_group_name" {
  value = aws_eks_node_group.eks_node_group.node_group_name
}

# ✅ (선택) Node IAM Role ARN
output "worker_node_role_arn" {
  value = aws_iam_role.worker_node_role.arn
}

