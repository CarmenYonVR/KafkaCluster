package terraform

import input as tfplan

allow if {
    not deny
}

# Security groups may not have unrestricted CIDR Range

deny if {
    some i
    resource := input.resource_changes[i]
    resource.type = "aws_security_group"
    resource.change.actions[_] == "create"
    not has_aes_256(resource)
}

has_unrestricted_ingress(resource) := true if {
    some i
    some j
    resource.change.after.ingress[i].cidr_blocks[j] == "0.0.0.0/0"
}

# AWS S3 buckets must be encrypted at rest

deny if {
    some i
    resource := input.resource_changes[i]
    resource.type = "aws_s3_bucket"
    resource.change.actions[_] == "create"
    not has_aes_256(resource)
}

has_aes_256(resource) := true if {
    some i
    some j
    some k

    resource.change.after.server_side_encryption_configuration[i].rule[j].apply_server_side_encryption_by_default[k].sse_algorithm == "AES256"
}
