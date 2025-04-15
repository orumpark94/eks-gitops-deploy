terraform {
  backend "s3" {
    bucket         = "eks-gitops-tfstate-20250415
    key            = "eks/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
  }
}
