# One shared IAM role for every Jenkins instance (master + all agents,
# Linux and Windows alike) — they all need exactly the same two things:
# permission to publish CloudWatch metrics, and to be managed by SSM (so we
# can push the CloudWatch Agent config to them without SSH/RDP or any custom
# install script). No reason to keep per-OS roles separate.

resource "aws_iam_role" "cwagent" {
  name = "${var.project_name}-cwagent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = var.project_name
  }
}

# AWS-managed policy — exactly what the CloudWatch Agent needs
# (PutMetricData, read its own EC2 tags, write its own logs). No custom
# policy to write, review, or keep in sync.
resource "aws_iam_role_policy_attachment" "cwagent" {
  role       = aws_iam_role.cwagent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Lets Systems Manager manage the instance (required for the SSM
# Association in ssm-association.tf that installs/configures the agent).
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.cwagent.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "cwagent" {
  name = "${var.project_name}-cwagent-profile"
  role = aws_iam_role.cwagent.name
}

# NOTE: this only creates the role/profile. It does NOT attach it to your
# existing instances — Terraform isn't managing those EC2 instances (they
# already exist, deliberately kept out of this project's state to avoid the
# risk of Terraform touching production Jenkins hosts). Attach it once,
# per instance, with the AWS CLI command in README.md ("First-time setup").
