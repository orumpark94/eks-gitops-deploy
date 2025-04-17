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

output "eks_node_group_name" {
  value = var.create_nodegroup ? aws_eks_node_group.eks_node_group[0].node_group_name : "skipped"
}

# ✅ (선택) Node IAM Role ARN (data로 변경됨)
output "worker_node_role_arn" {
  value = data.aws_iam_role.worker_node_role.arn
}
