terraform {
  backend "s3" {
    bucket         = "eks-gitops-tfstate"
    key            = "eks/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
  }
}
