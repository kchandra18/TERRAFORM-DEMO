# =============================================================================
# FILE: terraform/modules/ec2/outputs.tf
# PURPOSE: Exposes attributes of resources created in this module so the
#          ROOT module (and ultimately the operator) can consume them.
#
# Rule of thumb: export every attribute the caller might plausibly need.
# It is cheap to add an output; it is breaking-change work to add one later
# because callers may have already written scripts that don't expect it.
# =============================================================================

output "instance_id" {
  description = "The EC2 instance ID (e.g., i-0abc1234def56789a)"
  # aws_instance.this.id → the unique identifier assigned by AWS on creation.
  # "this" is just the resource label we chose in main.tf — it has no special
  # meaning in Terraform; we use "this" by convention for the primary resource
  # in a module that manages a single resource of each type.
  value = aws_instance.this.id
}

output "public_ip" {
  description = "Public IPv4 address assigned to the instance (empty string if in a private subnet)"
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "Private IPv4 address of the instance within the VPC"
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "ID of the Security Group attached to the instance"
  value       = aws_security_group.instance_sg.id
}

output "iam_role_arn" {
  description = "ARN of the IAM Role attached to the instance via the instance profile"
  value       = aws_iam_role.ec2_ssm_role.arn
}

output "ami_id" {
  description = "AMI ID that was used to launch the instance — stored for audit purposes"
  value       = aws_instance.this.ami
}
