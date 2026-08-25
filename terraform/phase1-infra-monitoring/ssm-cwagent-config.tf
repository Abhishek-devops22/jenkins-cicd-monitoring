# The CloudWatch Agent configs live as plain JSON files (see
# cloudwatch-agent-configs/) instead of inline HCL, on purpose: it's the
# exact format AWS's own docs use, so it's easy to look up "how do I add
# metric X" without needing to know Terraform at all — just edit the JSON,
# then `terraform apply`.

resource "aws_ssm_parameter" "cwagent_config_linux" {
  name  = "/${var.project_name}/cwagent-config/linux"
  type  = "String"
  value = file("${path.module}/cloudwatch-agent-configs/linux-config.json")

  tags = {
    Project = var.project_name
  }
}

resource "aws_ssm_parameter" "cwagent_config_windows" {
  name  = "/${var.project_name}/cwagent-config/windows"
  type  = "String"
  value = file("${path.module}/cloudwatch-agent-configs/windows-config.json")

  tags = {
    Project = var.project_name
  }
}
