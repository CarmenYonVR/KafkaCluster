# Apache Kafka cluster implemented with Terraform, CDK, and Cloudformation

## Repository Structure

Each respective folder contains an implementation of the kafka cluster. It is intended only to be deployed in us-east-1.

## Deploy

### Cloudformation

```
cd cdk

aws cloudformation create-stack --stack-name cf-kafka-cluster-stack --template-body file://KafkaCluster.yaml
```

If using an aws cli profile, append `--profile <Profilename>`

### Terraform

In order to generate properly formatted ids, the terraform implementation needs access to kafka binaries. Download and extract them into the Terraform folder with: 

```
curl -O https://dlcdn.apache.org/kafka/4.2.0/kafka_2.13-4.2.0.tgz
tar -xzf kafka_2.13-4.2.0.tgz
rm kafka_2.13-4.2.0.tgz
```


If using an aws cli profile, first run 

```
export AWS_PROFILE="LabsAdmin" 
```
then
```
terraform apply
```

### CDK

```
python3 -m venv .venv

source .venv/bin/activate

python3 -m pip install -r requirements.txt

cdk deploy
```

If using an aws cli profile, append `--profile <Profilename>`