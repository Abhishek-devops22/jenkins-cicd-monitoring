# Infra view (architecture.md §5.3, #1): per-node CPU/mem/disk, grouped
# Linux vs Windows, plus EC2 status checks. Pipeline view (build
# success/failure, queue depth, stuck builds) is Phase 2 — it needs the
# jenkins-health-poller Lambda to exist first, so it isn't here yet.
#
# Uses SEARCH() expressions (matching on Namespace/MetricName/InstanceId)
# rather than exact metric+dimension tuples, because the CloudWatch Agent
# adds a few extra dimensions of its own per-metric (e.g. disk adds
# "path"/"fstype"/"device") that aren't worth hardcoding here. SEARCH finds
# the metric regardless. First time you open the dashboard after applying,
# give the agent a few minutes to report before expecting data.

locals {
  linux_instance_ids   = concat([var.jenkins_master_instance_id], var.linux_agent_instance_ids)
  windows_instance_ids = var.windows_agent_instance_ids

  linux_metric_widget = {
    cpu    = { metric_name = "cpu_usage_active", label = "CPU %" }
    memory = { metric_name = "mem_used_percent", label = "Memory %" }
    disk   = { metric_name = "used_percent", label = "Disk %" }
  }

  windows_metric_widget = {
    cpu    = { metric_name = "% Processor Time", label = "CPU %" }
    memory = { metric_name = "% Committed Bytes In Use", label = "Memory %" }
    disk   = { metric_name = "% Free Space", label = "Disk % Free" }
  }
}

resource "aws_cloudwatch_dashboard" "infra" {
  dashboard_name = "${var.project_name}-infra"

  dashboard_body = jsonencode({
    widgets = concat(
      [{
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# Jenkins Infra Health — Phase 1\nCPU / memory / disk per node, grouped Linux vs Windows, plus EC2 status checks. Build/queue/agent-connectivity metrics are added in Phase 2 (jenkins-health-poller Lambda)."
        }
      }],
      [
        for i, key in ["cpu", "memory", "disk"] : {
          type   = "metric"
          x      = 0
          y      = 2 + i * 6
          width  = 12
          height = 6
          properties = {
            title  = "Linux Fleet — ${local.linux_metric_widget[key].label}"
            view   = "timeSeries"
            region = var.aws_region
            metrics = [
              for id in local.linux_instance_ids : [{
                expression = "SEARCH('Namespace=\"Jenkins/Infra\" MetricName=\"${local.linux_metric_widget[key].metric_name}\" InstanceId=\"${id}\"', 'Average', 300)"
                id         = "linux_${key}_${replace(id, "-", "_")}"
                label      = id
              }]
            ]
          }
        }
      ],
      [
        for i, key in ["cpu", "memory", "disk"] : {
          type   = "metric"
          x      = 12
          y      = 2 + i * 6
          width  = 12
          height = 6
          properties = {
            title  = "Windows Fleet — ${local.windows_metric_widget[key].label}"
            view   = "timeSeries"
            region = var.aws_region
            metrics = [
              for id in local.windows_instance_ids : [{
                expression = "SEARCH('Namespace=\"Jenkins/Infra\" MetricName=\"${local.windows_metric_widget[key].metric_name}\" InstanceId=\"${id}\"', 'Average', 300)"
                id         = "win_${key}_${replace(id, "-", "_")}"
                label      = id
              }]
            ]
          }
        }
      ],
      [{
        type   = "metric"
        x      = 0
        y      = 20
        width  = 24
        height = 6
        properties = {
          title  = "EC2 Status Checks — All 7 Instances (1 = failing)"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Maximum"
          period = 300
          metrics = [
            for id in concat(local.linux_instance_ids, local.windows_instance_ids) :
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", id, { label = id }]
          ]
        }
      }]
    )
  })
}
