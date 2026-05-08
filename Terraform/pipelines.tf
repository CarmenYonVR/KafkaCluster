resource "aws_s3_bucket" "kafka_cluster_artifacts" {
  bucket = "cyon-kafka-cluster-artifacts"
}
resource "aws_iam_role" "kafka_cluster_pipeline" {
  name               = "kafka-cluster-pipeline-service-role"
  assume_role_policy = data.aws_iam_policy_document.kafka_cluster_pipeline_assume_role.json
}
resource "aws_iam_role_policy" "kafka_cluster_pipeline" {
  name   = "kafka-cluster-cloudbuild-policy"
  role   = aws_iam_role.kafka_cluster_pipeline.id
  policy = data.aws_iam_policy_document.kafka_cluster_pipeline_policy.json
}
data "aws_iam_policy_document" "kafka_cluster_pipeline_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}
data "aws_iam_policy_document" "kafka_cluster_pipeline_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject"
    ]
    resources = [
      aws_s3_bucket.kafka_cluster_artifacts.arn,
      "${aws_s3_bucket.kafka_cluster_artifacts.arn}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "codeconnections:UseConnection",
    ]
    resources = [
      aws_codestarconnections_connection.kafka_cluster.arn
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    resources = ["*"]
  }
}

resource "aws_codestarconnections_connection" "kafka_cluster" {
  name          = "kafka-cluster-github-connection"
  provider_type = "GitHub"
}


resource "aws_codepipeline" "kafka_cluster_pipeline" {
  name          = "KafkaClusterPipeline"
  role_arn      = aws_iam_role.kafka_cluster_pipeline.arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.kafka_cluster_artifacts.id
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.kafka_cluster.arn
        FullRepositoryId = "CarmenYonVR/KafkaCluster"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Plan"

    action {
      name             = "Terraform-Plan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform_plan.name
      }
    }
  }

  stage {
    name = "Approval"

    action {
      name     = "ManualApproval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        CustomData = "Please review the build output and approve deployment to production."
      }
    }
  }

  stage {
    name = "Apply"

    action {
      name             = "Terraform-Apply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["build_output"]
      output_artifacts = ["apply_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform_apply.name
      }
    }
  }
}

# CodeBuild Project for plan
resource "aws_iam_role" "kafka_cluster_codebuild_role" {
  name               = "kafka-cluster-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.kafka_cluster_cloudbuild_assume_role.json
}
resource "aws_iam_role_policy" "kafka_cluster_cloudbuild_policy" {
  name = "kafka-cluster-cloudbuild-policy"
  role = aws_iam_role.kafka_cluster_codebuild_role.id

  policy = data.aws_iam_policy_document.kafka_cluster_cloudbuild.json
}
data "aws_iam_policy_document" "kafka_cluster_cloudbuild" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetObjectVersion",
    ]
    resources = [
      "arn:aws:s3:::cyon-kafka-cluster-terraform-state",
      "arn:aws:s3:::cyon-kafka-cluster-terraform-state/*"
    ]
  }
  # TODO: restrict
  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.kafka_cluster_artifacts.arn,
      "${aws_s3_bucket.kafka_cluster_artifacts.arn}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:us-east-1::parameter/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
    ]
  }
  # Allow terraform to fully manage the kafka_cluster_ids secret
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:*"
    ]
    resources = [
      aws_secretsmanager_secret.kafka_cluster_ids.arn
    ]
  }
  # Allow terraform to fully manage the roles defined in this repo
  statement {
    effect  = "Allow"
    actions = ["iam:*"]
    resources = [
      aws_iam_role.kafka_broker_role.arn,
      aws_iam_role.kafka_cluster_pipeline.arn,
      aws_iam_role.kafka_cluster_codebuild_role.arn,
      aws_iam_instance_profile.broker_instance_profile.arn
    ]
  }
  statement {
    effect    = "Allow"
    actions   = ["route53:*"]
    resources = [aws_route53_zone.kafka_zone.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["codeconnections:*", "codestar-connections:*"]
    resources = [aws_codestarconnections_connection.kafka_cluster.arn]
  }
  # TODO: I don't like this, should restrict 
  statement {
    effect    = "Allow"
    actions   = ["ec2:*"]
    resources = ["*"]
  }
  statement {
    effect  = "Allow"
    actions = ["codebuild:*"]
    resources = [
      aws_codebuild_project.terraform_apply.arn,
      aws_codebuild_project.terraform_plan.arn
    ]
  }
  statement {
    effect  = "Allow"
    actions = ["codepipeline:*"]
    resources = [
      aws_codepipeline.kafka_cluster_pipeline.arn,
      "${aws_codepipeline.kafka_cluster_pipeline.arn}/*"
    ]
  }
}
data "aws_iam_policy_document" "kafka_cluster_cloudbuild_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}
resource "aws_codebuild_project" "terraform_plan" {
  name         = "terraform_plan"
  description  = "Run terraform plan"
  service_role = aws_iam_role.kafka_cluster_codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux-x86_64-standard:6.0"
    privileged_mode = false
  }

  logs_config {
    cloudwatch_logs {
      group_name = "kafka-cluster-terraform-plan-logs"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<EOF
version: 0.2

phases:
  install:
    commands:
      - sudo dnf install -y dnf-plugins-core
      - sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
      - sudo dnf -y install terraform
  pre_build:
    commands:
      terraform --version
  build:
    commands:
      - cd Terraform
      - terraform init -input=false
      - terraform plan -input=false -out=tfplan
  post_build:
    commands: 
      - echo "Completed Terraform plan phase"
  
artifacts:
  files: 
    - tfplan
    - .terraform/**/*
    - "**/*"
EOF
  }
}

resource "aws_codebuild_project" "terraform_apply" {
  name         = "terraform-apply"
  description  = "Run terraform apply"
  service_role = aws_iam_role.kafka_cluster_codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux-x86_64-standard:6.0"
    privileged_mode = false
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<EOF
version: 0.2

phases:
  install:
    commands:
      - sudo dnf install -y dnf-plugins-core
      - sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
      - sudo dnf -y install terraform
  pre_build:
    commands:
      - terraform --version
  build:
    commands:
      - cd Terraform
      - terraform init -input=false
      - terraform apply -input=false tfplan
  post_build:
    commands: 
      - echo "Completed Terraform apply phase"
  
artifacts:
  files: 
    - "**/*"
EOF
  }
}
