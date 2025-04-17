variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "cluster_name" {
  type = string
}

variable "cluster_role_name" {
  type = string
}

variable "create_nodegroup" {
  type    = bool
  default = true
}
