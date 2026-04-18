# =============================================================================
# FILE: terraform/modules/ec2/main.tf
# PURPOSE: Reusable EC2 module. Defines the actual AWS resources:
#   • aws_security_group   — firewall rules for the instance
#   • aws_instance         — the EC2 virtual machine itself
#   • aws_iam_role         — IAM role allowing SSM Session Manager access
#   • aws_iam_instance_profile — binds the IAM role to the EC2 instance
#
# Why a module?
#   A module is a folder of .tf files called as a unit. It acts like a
#   function: accepts inputs (variables), performs actions (resources),
#   returns outputs. This means dev / staging / prod can all call THIS module
#   with different variable values instead of duplicating resource code.
# =============================================================================

# -----------------------------------------------------------------------------
# RESOURCE: aws_security_group
# A Security Group (SG) is AWS's virtual firewall at the instance level.
# It is STATEFUL: if you allow inbound port 80, the response traffic is
# automatically allowed outbound — you don't need a separate outbound rule.
# All traffic is denied by default; rules ADD permissions.
# -----------------------------------------------------------------------------
resource "aws_security_group" "instance_sg" {

  # name: The SG name visible in the AWS Console.
  # Using var.instance_name makes each module instance's SG uniquely named.
  name = "${var.instance_name}-sg"

  # description: Human-readable note stored in AWS.
  # AWS requires a description; an empty string would cause an API error.
  description = "Security group for ${var.instance_name} EC2 instance"

  # vpc_id: Attaches the SG to the specified VPC.
  # An SG must belong to a VPC; it cannot be shared across VPCs.
  vpc_id = var.vpc_id

  # ---- INGRESS (inbound) rules ----

  # ingress block 1: Allow HTTP traffic from the internet.
  # HTTP (port 80) is needed if this EC2 hosts a web application.
  ingress {
    description = "HTTP from allowed CIDR blocks"
    from_port   = 80          # First port in the range (TCP ranges are from_port–to_port)
    to_port     = 80          # Same as from_port → single port (80 only)
    protocol    = "tcp"       # TCP is required for HTTP
    cidr_blocks = var.allowed_cidr_blocks # List of allowed source IP ranges
  }

  # ingress block 2: Allow HTTPS traffic.
  # Port 443 for TLS-encrypted web traffic. Best practice: terminate TLS
  # at a Load Balancer, but included here for direct-instance demos.
  ingress {
    description = "HTTPS from allowed CIDR blocks"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # ---- EGRESS (outbound) rule ----
  # By default, AWS SGs block ALL outbound traffic until you add rules.
  # This rule allows ALL outbound traffic — required so the instance can:
  #   • Pull OS package updates (yum/dnf to Amazon repos)
  #   • Reach AWS API endpoints (SSM, CloudWatch, S3)
  #   • Make any outbound API calls your application needs
  egress {
    description = "Allow all outbound traffic so the instance can reach the internet and AWS APIs"
    from_port   = 0           # 0 means "all ports"
    to_port     = 0           # 0 means "all ports"
    protocol    = "-1"        # "-1" is AWS's code for "all protocols"
    cidr_blocks = ["0.0.0.0/0"] # Anywhere on the internet
  }

  # tags: The SG needs its own Name tag because the provider's default_tags
  # block (in main.tf) sets a project-level Name; here we override it with
  # a more specific name that includes "-sg" to distinguish it from the instance.
  tags = merge(var.tags, {
    Name = "${var.instance_name}-sg"
  })

  # lifecycle.create_before_destroy: When Terraform needs to replace the SG
  # (e.g., you change the VPC), it creates the new one first, then destroys
  # the old one. Without this flag, Terraform would try to destroy first —
  # but the instance still references the old SG, causing an API dependency
  # error. This ordering prevents that brief dependency conflict.
  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# RESOURCE: aws_iam_role
# An IAM Role is an AWS identity that EC2 instances can "assume" to make
# API calls to other AWS services WITHOUT embedding access keys in the OS.
#
# Why needed here?
#   AWS Systems Manager (SSM) Session Manager lets you open a shell on an EC2
#   instance without opening SSH port 22. The SSM agent running on the instance
#   calls back to the SSM service API — for that API call to succeed, the
#   instance needs IAM permission. This role grants it.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ec2_ssm_role" {

  name = "${var.instance_name}-ssm-role"

  # assume_role_policy: A JSON policy document that controls WHICH AWS service
  # is allowed to "assume" (use) this role. This is called the "trust policy".
  # Here we say "the EC2 service (ec2.amazonaws.com) may assume this role".
  # jsonencode() converts a Terraform map/list into a JSON string — cleaner
  # than heredoc syntax and prevents JSON formatting mistakes.
  assume_role_policy = jsonencode({

    # Version: The IAM policy language version. "2012-10-17" is the ONLY
    # version AWS supports for new policies; always use this value.
    Version = "2012-10-17"

    Statement = [
      {
        # Action: "sts:AssumeRole" is the specific API call that allows a
        # service/principal to obtain temporary credentials for this role.
        Action = "sts:AssumeRole"

        # Effect: "Allow" permits the action. The alternative is "Deny".
        Effect = "Allow"

        # Principal: WHO is allowed to assume the role.
        # Service = "ec2.amazonaws.com" means the EC2 service itself
        # (i.e., any EC2 instance that has this role attached).
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# -----------------------------------------------------------------------------
# RESOURCE: aws_iam_role_policy_attachment
# Attaches an AWS-managed policy to the IAM role.
# "AmazonSSMManagedInstanceCore" is a pre-built policy maintained by AWS that
# grants all the permissions the SSM agent needs:
#   • ssm:UpdateInstanceInformation (heartbeat)
#   • ssmmessages:* (Session Manager channel)
#   • ec2messages:* (Run Command relay)
# Using AWS-managed policies means AWS keeps them updated — you don't need
# to manually add new SSM permissions as the service evolves.
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ssm_policy" {

  # role: The IAM role to attach the policy to.
  # We reference the role's name attribute (not ID) because that's what the
  # AWS API expects for this parameter.
  role = aws_iam_role.ec2_ssm_role.name

  # policy_arn: The ARN of the managed policy.
  # ARNs (Amazon Resource Names) are globally unique identifiers in AWS.
  # "arn:aws:iam::aws:policy/..." is the format for AWS-managed policies
  # (note the empty account ID section — AWS-managed = no specific account).
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -----------------------------------------------------------------------------
# RESOURCE: aws_iam_instance_profile
# An "Instance Profile" is the container that connects an IAM Role to an EC2
# instance. You cannot attach a role directly to an instance — you must wrap
# it in an instance profile first. (AWS UI hides this by auto-creating profiles,
# but Terraform requires explicit creation.)
# -----------------------------------------------------------------------------
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.instance_name}-profile"

  # role: The IAM role to include in this profile.
  role = aws_iam_role.ec2_ssm_role.name

  tags = var.tags
}

# -----------------------------------------------------------------------------
# RESOURCE: aws_instance
# The actual EC2 virtual machine. This is the primary resource of the module.
# All other resources above exist to support this one.
# -----------------------------------------------------------------------------
resource "aws_instance" "this" {

  # ami: Amazon Machine Image ID — the OS template used to launch the instance.
  # Comes from the data source in root main.tf, passed through as a variable.
  ami = var.ami_id

  # instance_type: The hardware spec (CPU + RAM) for the virtual machine.
  # t3.micro = 2 vCPU, 1 GiB RAM — cheapest option, often free-tier eligible.
  instance_type = var.instance_type

  # subnet_id: Which VPC subnet to place the instance in.
  # Subnets determine the Availability Zone and whether the instance gets
  # a public IP. Public subnets have a route to an Internet Gateway.
  subnet_id = var.subnet_id

  # vpc_security_group_ids: List of Security Group IDs to attach.
  # An instance can have multiple SGs; all their rules are evaluated together.
  # We wrap the single SG ID in a list because the API expects a list.
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  # iam_instance_profile: Grants the instance the SSM IAM permissions.
  # Without this, the SSM agent can't authenticate and Session Manager fails.
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # key_name: Optional EC2 Key Pair name for SSH access.
  # null means "no key pair" — instance is accessed via SSM only (more secure).
  key_name = var.key_pair_name

  # associate_public_ip_address: Whether to assign a public IPv4 address.
  # true for demo/dev — the instance needs a public IP to be reachable from
  # a browser. For production, set false and use a Load Balancer instead.
  associate_public_ip_address = true

  # user_data: Shell script run by cloud-init ONCE when the instance first boots.
  # Use it to install packages, configure services, etc.
  # We use a heredoc (<<-EOF ... EOF) for multi-line scripts.
  # The "-" prefix strips leading tabs for cleaner indentation in .tf files.
  user_data = <<-EOF
    #!/bin/bash
    # Update all installed packages to their latest versions.
    # "-y" auto-confirms all prompts (required for non-interactive scripts).
    dnf update -y

    # Install the Apache HTTP Server (httpd) web server.
    # Amazon Linux 2023 uses dnf (successor to yum).
    dnf install -y httpd

    # Start the httpd service immediately.
    systemctl start httpd

    # Enable httpd to start automatically on every future reboot.
    systemctl enable httpd

    # Write a simple HTML page to Apache's web root.
    # This lets you verify the deployment by visiting the instance's public IP.
    echo "<h1>Hello from ${var.instance_name} — Terraform Deployed!</h1>" > /var/www/html/index.html
  EOF

  # root_block_device: Configuration for the primary (root) EBS volume.
  root_block_device {

    # volume_size: Size in GiB. Comes from var.root_volume_size (default 20).
    volume_size = var.root_volume_size

    # volume_type: EBS volume type.
    # "gp3" is the latest general-purpose SSD — better performance and
    # lower cost than the older "gp2" type. Always prefer gp3 for new deployments.
    volume_type = "gp3"

    # encrypted: Enables AES-256 encryption at rest for the EBS volume.
    # Security best practice: encrypt all volumes, especially root volumes
    # which contain the OS, application code, and potentially secrets.
    encrypted = true

    # delete_on_termination: true means the EBS volume is automatically
    # deleted when the EC2 instance is terminated.
    # For stateless/ephemeral instances this is fine (and avoids orphaned costs).
    # For data-bearing instances, set false and manage snapshots separately.
    delete_on_termination = true
  }

  # monitoring: Enables detailed CloudWatch monitoring (1-minute granularity
  # instead of the default 5 minutes). Costs slightly more but gives better
  # visibility into CPU spikes, memory pressure events, etc.
  monitoring = true

  # tags: Merge the common tags (passed from root module) with a specific
  # Name tag that identifies this exact instance in the AWS Console.
  tags = merge(var.tags, {
    Name = var.instance_name
  })

  # lifecycle.ignore_changes: Tells Terraform to ignore changes to these
  # attributes made OUTSIDE of Terraform (e.g., by an auto-scaling group
  # or an operator manually stopping/starting the instance).
  # "user_data" is ignored because changes to user_data would require
  # replacing the instance (downtime) — we want to manage updates explicitly.
  lifecycle {
    ignore_changes = [user_data]
  }
}
