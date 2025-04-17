provider "aws" {
  region = "ap-northeast-2"
}

data "aws_eks_cluster" "eks" {
  name = "eks-gitops-cluster"
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.aws_eks_cluster.eks.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
