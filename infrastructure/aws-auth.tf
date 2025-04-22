resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = <<YAML
- groups:
  - system:bootstrappers
  - system:nodes
  rolearn: arn:aws:iam::863676520919:role/eks-worker-node-role
  username: system:node:{{EC2PrivateDNSName}}
YAML
  }

  lifecycle {
    ignore_changes = [data] # 수동 변경에 의한 충돌 방지용 (선택 사항)
  }

  depends_on = [
    aws_eks_cluster.eks_cluster
  ]
}
