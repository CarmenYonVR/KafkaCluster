variable "aws_region" {
  description = "The AWS Region to deploy resources into"
  type = string
  default = "us-east-1"
}

# do not change
variable "terraform_state_bucket" {
    description = "The bucket to keep terraform state in"
    type = string
    default = "cyon-kafka-cluster-terraform-state"
}