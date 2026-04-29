import aws_cdk as core
import aws_cdk.assertions as assertions

from cdk_kafka_cluster.cdk_kafka_cluster_stack import CdkKafkaClusterStack

# example tests. To run these tests, uncomment this file along with the example
# resource in cdk_kafka_cluster/cdk_kafka_cluster_stack.py
def test_sqs_queue_created():
    app = core.App()
    stack = CdkKafkaClusterStack(app, "cdk-kafka-cluster")
    template = assertions.Template.from_stack(stack)

#     template.has_resource_properties("AWS::SQS::Queue", {
#         "VisibilityTimeout": 300
#     })
