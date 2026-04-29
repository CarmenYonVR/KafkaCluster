#!/bin/bash
yum update -y
yum install tar -y
yum install xz -y
yum install gzip -y
yum install java-17-amazon-corretto-devel -y
curl -O https://dlcdn.apache.org/kafka/4.2.0/kafka_2.13-4.2.0.tgz
tar -xzf kafka_2.13-4.2.0.tgz
cd kafka_2.13-4.2.0
sed -i 's|node.id=1|node.id=${NODE_ID}|' config/server.properties
sed -i 's|controller.quorum.bootstrap.servers=localhost:9093|controller.quorum.bootstrap.servers=Broker0.${HOSTED_ZONE_FQDN}:9093,Broker1.${HOSTED_ZONE_FQDN}:9093,Broker2.${HOSTED_ZONE_FQDN}:9093|' config/server.properties
sed -i 's|advertised.listeners=PLAINTEXT://localhost:9092,CONTROLLER://localhost:9093|advertised.listeners=PLAINTEXT://Broker${BROKER_INDEX}.${HOSTED_ZONE_FQDN}:9092,CONTROLLER://Broker${BROKER_INDEX}.${HOSTED_ZONE_FQDN}:9093|' config/server.properties
KAFKA_CLUSTER_ID='${KAFKA_CLUSTER_ID}'
bin/kafka-storage.sh format --initial-controllers '1@Broker0.${HOSTED_ZONE_FQDN}:9093:${BROKER0_ID},2@Broker1.${HOSTED_ZONE_FQDN}:9093:${BROKER1_ID},3@Broker2.${HOSTED_ZONE_FQDN}:9093:${BROKER2_ID}' --cluster-id $KAFKA_CLUSTER_ID --config config/server.properties
bin/kafka-server-start.sh config/server.properties