# --------------------------------------------------------------------------
# These are the values you'll actually edit day-to-day. Fill them in via
# terraform.tfvars (copy terraform.tfvars.example) — never edit the
# defaults below for a real environment.
# --------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region the Jenkins fleet runs in"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix/tag every resource this project creates"
  type        = string
  default     = "jenkins-monitoring"
}

variable "jenkins_master_instance_id" {
  description = "Instance ID of the Jenkins master EC2 instance. ASSUMPTION: treated as a Linux host (uses the Linux CloudWatch Agent config) — if the master actually runs Windows, move it into windows_agent_instance_ids instead and adjust ssm-association.tf."
  type        = string
}

variable "linux_agent_instance_ids" {
  description = "Instance IDs of the Linux Jenkins build agents (4 today)"
  type        = list(string)

  validation {
    condition     = length(var.linux_agent_instance_ids) > 0
    error_message = "Provide at least one Linux agent instance ID."
  }
}

variable "windows_agent_instance_ids" {
  description = "Instance IDs of the Windows Jenkins build agents (2 today)"
  type        = list(string)

  validation {
    condition     = length(var.windows_agent_instance_ids) > 0
    error_message = "Provide at least one Windows agent instance ID."
  }
}
