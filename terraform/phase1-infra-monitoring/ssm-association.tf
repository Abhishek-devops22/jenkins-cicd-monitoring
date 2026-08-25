# Installs + configures + starts the CloudWatch Agent on every target
# instance using AWS's own AWS-ConfigureCloudWatchAgent document. No custom
# install script, no AMI baking, no SSH/RDP needed — SSM does it, and
# re-applies on the schedule below so config drift (or someone manually
# stopping the agent) self-heals.
#
# Prerequisite: each instance needs the SSM Agent running and the instance
# profile from iam.tf attached (see README.md "First-time setup"). SSM
# Agent ships pre-installed on Amazon Linux 2/2023 and on the standard AWS
# Windows Server AMIs — nothing extra needed there.

resource "aws_ssm_association" "cwagent_linux" {
  name             = "AWS-ConfigureCloudWatchAgent"
  association_name = "${var.project_name}-cwagent-linux"

  targets {
    key    = "InstanceIds"
    values = concat([var.jenkins_master_instance_id], var.linux_agent_instance_ids)
  }

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationSource   = "ssm"
    optionalConfigurationLocation = aws_ssm_parameter.cwagent_config_linux.name
    optionalRestart               = "yes"
  }

  # How often SSM re-checks/re-applies the config on each instance.
  schedule_expression = "rate(1 hour)"
}

resource "aws_ssm_association" "cwagent_windows" {
  name             = "AWS-ConfigureCloudWatchAgent"
  association_name = "${var.project_name}-cwagent-windows"

  targets {
    key    = "InstanceIds"
    values = var.windows_agent_instance_ids
  }

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationSource   = "ssm"
    optionalConfigurationLocation = aws_ssm_parameter.cwagent_config_windows.name
    optionalRestart               = "yes"
  }

  schedule_expression = "rate(1 hour)"
}
