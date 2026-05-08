terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  backend "s3" {
    bucket = "cyon-kafka-cluster-terraform-state" 
    key = "cyon-kafka-cluster-terraform-state/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }

  required_version = ">= 1.2"
}

