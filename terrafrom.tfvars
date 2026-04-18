# Terraform variable inputs for EC2 module

# Required variables
instance_name     = "my-ec2-instance"
instance_type     = "t3.micro"
ami_id            = "ami-0abcdef1234567890"  # Replace with a valid AMI ID for your region
subnet_id         = "subnet-12345678"        # Replace with your subnet ID
vpc_id            = "vpc-12345678"           # Replace with your VPC ID
environment      = "dev"

# Optional variables (with defaults)
key_pair_name     = null  # Set to a key pair name if needed for SSH access
allowed_cidr_blocks = ["0.0.0.0/0"]  # Allow all IPs; restrict in production
root_volume_size  = 20
tags = {
  Project     = "Terraform Demo"
  Environment = "Development"
  Owner       = "Your Name"
}
