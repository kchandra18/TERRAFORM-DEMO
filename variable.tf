# =============================================================================
# FILE: terraform/modules/ec2/variables.tf
# PURPOSE: Input variables for the EC2 module.
#          All values MUST be supplied by the calling module (root main.tf)
#          unless a default is provided here.
# =============================================================================

variable "instance_name" {
  description = "Name tag value and name-prefix for all resources created by this module"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type — controls CPU and RAM (e.g., t3.micro, m6i.large)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID to launch the instance from — passed from the data source in root main.tf"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the EC2 instance will be placed"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — required to attach the Security Group to the correct network"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod) — used in resource names and tags"
  type        = string
}

variable "key_pair_name" {
  description = "Optional EC2 Key Pair name for SSH access. Set to null to disable SSH (use SSM instead)"
  type        = string
  default     = null
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed inbound on port 80/443"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Additional tags to apply to all resources in this module — merged with resource-specific tags"
  # type = map(string) means a key-value map where every key AND value is a string.
  # AWS tags are always string-to-string maps, so this is the correct type.
  type    = map(string)
  default = {}
}
