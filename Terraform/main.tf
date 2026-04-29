provider "aws" {
  region = "us-east-1"
}

variable "broker_instance_type" {
  description = "instance type for brokers"
  type        = string
  default     = "t2.medium"
}

variable "vpc_cidr" {
  description = "CIDR range of the VPC"
  type        = string
  default     = "10.192.0.0/16"
}

variable "hosted_zone_fqdn" {
  description = "Fully qualified domain name for Route53 Hosted Zone"
  type        = string
  default     = "tf-kafka-broker.com"
}

variable "kafka_cluster_id" {
  description = "Kafka cluster ID"
  type        = string
  default     = "58KYKy0VTL-31339uL9O2w"
}

variable "broker_ids" {
  description = "An array of Kafka broker IDs"
  type        = list(string)
  default     = ["WtToW5ylTEKU5Dm3TbRYwg", "ZLXjKQajSR61NZjxrljh9Q", "1rXKnBXJTZW3H32gqvCdNA"]
}

# Create VPC using module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = "tf-kafka-cluster-vpc"
  cidr = var.vpc_cidr

  azs             = ["us-east-1a"]
  private_subnets = ["10.192.10.0/24"]
  public_subnets  = ["10.192.11.0/24"]

  enable_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_ec2_instance_connect_endpoint" "tf_kc_ec2_ic_endpoint" {
  subnet_id = module.vpc.private_subnets[0]
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" 
}

# Broker security group configuration
resource "aws_security_group" "broker_security_group" {
  name        = "tf_broker_security_group"
  description = "Allow SSH and Kafka Ports within VPC"
  vpc_id      = module.vpc.vpc_id
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_kafka" {
  security_group_id = aws_security_group.broker_security_group.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 9091
  to_port           = 9093
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_within_vpc" {
  security_group_id = aws_security_group.broker_security_group.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

# Bastion Host Security Group configuration
resource "aws_security_group" "bastion_host_security_group" {
  name        = "tf_bastion_host_group"
  description = "Allow SSH from ec2 instance connect in us-east-1"
  vpc_id      = module.vpc.vpc_id
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_from_ec2_instance_connect" {
  security_group_id = aws_security_group.bastion_host_security_group.id
  prefix_list_id    = "pl-0e4bcff02b13bef1e"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_instance" "tf_bastion_host" {
  ami           = data.aws_ssm_parameter.al2023_ami.value
  instance_type = "t2.micro"

  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.bastion_host_security_group.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install tar -y
    yum install xz -y
    yum install gzip -y
    yum install java-17-amazon-corretto-devel -y
    curl -O https://dlcdn.apache.org/kafka/4.2.0/kafka_2.13-4.2.0.tgz
    tar -xzf kafka_2.13-4.2.0.tgz
  EOF

  tags = {
    Name = "TFBastionHost"
  }
}

resource "aws_instance" "tf_broker_0" {
  ami           = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.broker_instance_type

  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.broker_security_group.id]

  tags = {
    Name = "TFBroker0"
  }

  user_data = base64encode("${templatefile("${path.module}/user_data.sh", {
    NODE_ID          = 1
    BROKER_INDEX     = 0
    KAFKA_CLUSTER_ID = var.kafka_cluster_id
    HOSTED_ZONE_FQDN = var.hosted_zone_fqdn
    BROKER0_ID       = var.broker_ids[0]
    BROKER1_ID       = var.broker_ids[1]
    BROKER2_ID       = var.broker_ids[2]
  })}")
}

resource "aws_instance" "tf_broker_1" {
  ami           = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.broker_instance_type

  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.broker_security_group.id]

  tags = {
    Name = "TFBroker1"
  }

  user_data = base64encode("${templatefile("${path.module}/user_data.sh", {
    NODE_ID          = 2
    BROKER_INDEX     = 1
    KAFKA_CLUSTER_ID = var.kafka_cluster_id
    HOSTED_ZONE_FQDN = var.hosted_zone_fqdn
    BROKER0_ID       = var.broker_ids[0]
    BROKER1_ID       = var.broker_ids[1]
    BROKER2_ID       = var.broker_ids[2]
  })}")
}

resource "aws_instance" "tf_broker_2" {
  ami           = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.broker_instance_type

  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.broker_security_group.id]

  tags = {
    Name = "TFBroker2"
  }

  user_data = base64encode("${templatefile("${path.module}/user_data.sh", {
    NODE_ID          = 3
    BROKER_INDEX     = 2
    KAFKA_CLUSTER_ID = var.kafka_cluster_id
    HOSTED_ZONE_FQDN = var.hosted_zone_fqdn
    BROKER0_ID       = var.broker_ids[0]
    BROKER1_ID       = var.broker_ids[1]
    BROKER2_ID       = var.broker_ids[2]
  })}")
}

resource "aws_route53_zone" "kafka_zone" {
  name = var.hosted_zone_fqdn

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}
resource "aws_route53_record" "broker0" {
  zone_id = aws_route53_zone.kafka_zone.zone_id
  name    = "Broker0.${var.hosted_zone_fqdn}"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.tf_broker_0.private_ip]
}
resource "aws_route53_record" "broker1" {
  zone_id = aws_route53_zone.kafka_zone.zone_id
  name    = "Broker1.${var.hosted_zone_fqdn}"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.tf_broker_1.private_ip]
}
resource "aws_route53_record" "broker2" {
  zone_id = aws_route53_zone.kafka_zone.zone_id
  name    = "Broker2.${var.hosted_zone_fqdn}"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.tf_broker_2.private_ip]
}
