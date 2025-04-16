# ✅ 서브넷 ID 출력 (기존 유지)
output "public_subnet_a_id" {
  value = aws_subnet.public_subnet_a.id
}

output "public_subnet_c_id" {
  value = aws_subnet.public_subnet_c.id
}

# ✅ VPC ID 출력
output "vpc_id" {
  value = aws_vpc.eks_vpc.id
}

# ✅ 워커 노드용 Security Group ID 출력
output "worker_security_group_id" {
  value = aws_security_group.eks_worker_sg.id
}

# ✅ EKS 클러스터 정보 (kubeadm join 등에 사용)
output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_cluster_ca" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}
