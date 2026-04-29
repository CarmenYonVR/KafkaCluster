from aws_cdk import (
    # Duration,
    Stack,
    aws_ec2 as ec2,
    aws_route53 as route53,
    Duration,
)
from constructs import Construct


class CdkKafkaClusterStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        vpc_cidr_range = "10.193.0.0/16"
        num_brokers = 3

        # Define the VPC, don't let it create the default subnets
        vpc = ec2.Vpc(self, "CDK-Kafka-VPC", ip_addresses=ec2.IpAddresses.cidr("10.193.0.0/16"))

        hosted_zone_fqdn = "cdk-kafka-broker.local"
        zone = route53.PrivateHostedZone(
            self,
            "CDKKafkaBrokerHostedZone",
            zone_name=hosted_zone_fqdn,
            vpc=vpc,
        )

        # Broker Configuration
        broker_security_group = ec2.SecurityGroup(
            self, "BrokerSecurityGroup", vpc=vpc, description="Allow SSH and Kafka"
        )
        broker_security_group.add_ingress_rule(
            ec2.Peer.ipv4(vpc_cidr_range),
            ec2.Port.tcp_range(9091, 9093),
            "Allow Kafka ports from within VPC",
        )
        broker_security_group.add_ingress_rule(
            ec2.Peer.ipv4(vpc_cidr_range), ec2.Port.SSH, "Allow SSH from within VPC"
        )

        # Create Brokers
        brokers: list[ec2.Instance] = []
        for i in range(num_brokers):
            brokers.append(
                ec2.Instance(
                    self,
                    f"Broker{i}",
                    instance_type=ec2.InstanceType("t2.medium"),
                    machine_image=ec2.AmazonLinuxImage(
                        generation=ec2.AmazonLinuxGeneration.AMAZON_LINUX_2023
                    ),
                    vpc=vpc,
                    vpc_subnets=ec2.SubnetSelection(
                        subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS
                    ),
                    security_group=broker_security_group,
                    associate_public_ip_address=False,
                )
            )

            # Add the broker to the hosted zone attatched to the VPC so we don't have to keep track of IPs
            route53.ARecord(
                self,
                f"Broker{i}Record",
                zone=zone,
                record_name=f"Broker{i}",
                target=route53.RecordTarget.from_ip_addresses(
                    brokers[i].instance_private_ip
                ),
                ttl=Duration.seconds(30),
            )

        # must be same length as num
        broker_ids = [
            "WtToW5ylTEKU5Dm3TbRYwg",
            "ZLXjKQajSR61NZjxrljh9Q",
            "1rXKnBXJTZW3H32gqvCdNA",
        ]
        kafka_cluster_id = "58KYKy0VTL-31339uL9O2w"

        # create user data
        for i in range(num_brokers):
            brokers[i].add_user_data(
                "yum update -y",
                "yum install tar -y",
                "yum install xz -y",
                "yum install gzip -y",
                "yum install java-17-amazon-corretto-devel -y",
                "curl -O https://dlcdn.apache.org/kafka/4.2.0/kafka_2.13-4.2.0.tgz",
                "tar -xzf kafka_2.13-4.2.0.tgz",
                "cd kafka_2.13-4.2.0",
                # TODO: Clean up the construction of these strings to not use manual indexes into broker_ids etc.
                f"sed -i 's|node.id=1|node.id={i + 1}|' config/server.properties",
                f"sed -i 's|controller.quorum.bootstrap.servers=localhost:9093|controller.quorum.bootstrap.servers=Broker0.{hosted_zone_fqdn}:9093,Broker1.{hosted_zone_fqdn}:9093,Broker2.{hosted_zone_fqdn}:9093|' config/server.properties",
                f"sed -i 's|advertised.listeners=PLAINTEXT://localhost:9092,CONTROLLER://localhost:9093|advertised.listeners=PLAINTEXT://Broker{i}.{hosted_zone_fqdn}:9092,CONTROLLER://Broker{i}.{hosted_zone_fqdn}:9093|' config/server.properties",
                f"KAFKA_CLUSTER_ID='{kafka_cluster_id}'",
                f"bin/kafka-storage.sh format --initial-controllers '1@Broker0.{hosted_zone_fqdn}:9093:{broker_ids[0]},2@Broker1.{hosted_zone_fqdn}:9093:{broker_ids[1]},3@Broker2.{hosted_zone_fqdn}:9093:{broker_ids[2]}' --cluster-id $KAFKA_CLUSTER_ID --config config/server.properties",
                "bin/kafka-server-start.sh config/server.properties",
            )

        # Bastion Host Configuration
        bastion_host_security_group = ec2.SecurityGroup(
            self,
            "BastionSecurityGroup",
            vpc=vpc,
            description="Allow SSH from ec2 instance connect",
        )
        bastion_host_security_group.add_ingress_rule(
            ec2.Peer.prefix_list("pl-0e4bcff02b13bef1e"),
            ec2.Port.SSH,
            "Allow SSH ports from ec2 instance connect",
        )
        bastion_host = ec2.Instance(
            self,
            "BastionHost",
            instance_type=ec2.InstanceType("t2.micro"),
            machine_image=ec2.AmazonLinuxImage(
                generation=ec2.AmazonLinuxGeneration.AMAZON_LINUX_2023
            ),
            vpc=vpc,
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PUBLIC),
            security_group=bastion_host_security_group,
            associate_public_ip_address=True,
        )
        bastion_host.add_user_data(
            "yum update -y",
            "yum install tar -y",
            "yum install xz -y",
            "yum install gzip -y",
            "yum install java-17-amazon-corretto-devel -y",
            "curl -O https://dlcdn.apache.org/kafka/4.2.0/kafka_2.13-4.2.0.tgz",
            "tar -xzf kafka_2.13-4.2.0.tgz",
        )
