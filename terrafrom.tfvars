# =============================================================================
# FILE: terraform/environments/dev/terraform.tfvars
# PURPOSE: Supplies concrete VALUES for the root module's variables when
#          deploying the "dev" environment.
#
# Why separate tfvars per environment?
#   Keeping one .tfvars per environment (dev/staging/prod) in their own
#   subdirectory means:
#   1. A developer can `cd environments/dev && terraform apply` without
#      accidentally affecting prod.
#   2. Git history shows exactly what changed and in which environment.
#   3. You can restrict GitHub Actions so only the `main` branch can
#      apply to prod, while feature branches apply to dev only.
#
# HOW TO USE:
#   terraform -chdir=terraform apply -var-file=environments/dev/terraform.tfvars
#   OR navigate here and run: terraform apply (Terraform auto-loads *.tfvars)
# =============================================================================

# aws_region: Deploy all resources to US East (N. Virginia).
# us-east-1 is chosen for dev because it has the most AZs and cheapest prices.
aws_region = "us-east-1"

# environment: Tag and name all resources as "dev" to distinguish from prod.
environment = "dev"

# project_name: Short lowercase identifier prepended to all resource names.
# Keep it short (< 10 chars) to avoid hitting AWS name-length limits.
project_name = "myapp"

# instance_type: t3.micro is the cheapest general-purpose instance.
# It is eligible for the AWS Free Tier (750 hours/month for 12 months).
# Dev doesn't need production-grade capacity.
instance_type = "t3.micro"

# root_volume_size: 20 GiB is plenty for OS + Apache + logs in dev.
root_volume_size = 20

# allowed_cidr_blocks: Allow HTTP from any IP in dev for easy browser testing.
# In prod, this would be restricted to a specific office IP range or removed
# entirely (traffic would go through a Load Balancer instead).
allowed_cidr_blocks = ["0.0.0.0/0"]
