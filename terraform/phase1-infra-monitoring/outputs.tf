output "cwagent_instance_profile_name" {
  description = "Attach this instance profile to every Jenkins EC2 instance (master + all agents) once, so the CloudWatch Agent can publish metrics. See README.md, 'First-time setup'."
  value       = aws_iam_instance_profile.cwagent.name
}

output "infra_dashboard_url" {
  description = "Direct link to the Infra CloudWatch Dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.infra.dashboard_name}"
}
