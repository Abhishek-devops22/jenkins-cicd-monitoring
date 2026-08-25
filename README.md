# Jenkins CI/CD Monitoring

Implementation of [`architecture.md`](./architecture.md) — CloudWatch + SNS +
Slack monitoring for the Jenkins master and its 6 build agents. No
Prometheus/Grafana, no server to run and patch — everything here is
AWS-native.

This repo is being built **phase by phase** (see architecture.md §8). Right
now only **Phase 1: baseline infra monitoring** exists. Phases 2 (pipeline
poller Lambda) and 3 (alerting → Slack) are not built yet — see "What's next"
below.

## What Phase 1 gives you

- CloudWatch Agent running on all 7 EC2 instances (master + 4 Linux + 2
  Windows agents), reporting CPU / memory / disk under the `Jenkins/Infra`
  namespace.
- A CloudWatch Dashboard showing that data grouped by OS, plus EC2 status
  checks for all 7 instances.
- No alerts yet — this phase is visibility only. Nothing pages anyone.

Deployed via Terraform, no manual clicking in the AWS console required after
first-time setup.

## Repo layout

```
architecture.md                          the design doc — read this first
terraform/
  phase1-infra-monitoring/
    *.tf                                 Terraform resources (IAM, SSM, dashboard)
    cloudwatch-agent-configs/
      linux-config.json                  what metrics the Linux agents collect
      windows-config.json                what metrics the Windows agents collect
    terraform.tfvars.example             copy to terraform.tfvars, fill in instance IDs
```

**Day-to-day, you should only ever need to touch:**
- `terraform.tfvars` — add/remove an instance ID
- `cloudwatch-agent-configs/*.json` — add/remove a metric being collected
- `dashboard.tf` — add a new widget (only if you're adding a new *kind* of
  metric, not a new instance — instances already loop automatically)

Everything else is plumbing you shouldn't need to touch once it's applied.

## Prerequisites

- Terraform >= 1.5, AWS CLI, credentials with permission to manage IAM
  roles, SSM parameters/associations, and CloudWatch dashboards.
- All 7 EC2 instances must already be running and visible to Systems
  Manager. Check with:
  ```
  aws ssm describe-instance-information --query "InstanceInformationList[].InstanceId"
  ```
  If an instance is missing from that list, its SSM Agent likely isn't
  running (rare on standard Amazon Linux / Windows Server AMIs — more
  common on older or custom AMIs). Fix that before continuing.

## First-time setup

```bash
cd terraform/phase1-infra-monitoring
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your real instance IDs

terraform init
terraform plan     # review what it will create
terraform apply
```

This creates the IAM role/instance profile and the SSM automation, but it
does **not** touch your existing EC2 instances directly (they're
deliberately kept out of Terraform's state — safer than letting Terraform
manage production instances it didn't create). One manual step per instance,
once:

```bash
PROFILE=$(terraform output -raw cwagent_instance_profile_name)

for id in <master-id> <linux-agent-ids...> <windows-agent-ids...>; do
  aws ec2 associate-iam-instance-profile \
    --instance-id "$id" \
    --iam-instance-profile Name="$PROFILE"
done
```

(If any instance already has a different instance profile attached, use
`aws ec2 replace-iam-instance-profile-association` instead — check first
with `aws ec2 describe-iam-instance-profile-associations`.)

Then wait a few minutes for the SSM Association to run and the agent to
report its first data point:

```bash
aws ssm describe-association --association-id <id-from-terraform-state>
# or just check in the console: Systems Manager → State Manager
```

Open the dashboard:

```bash
terraform output infra_dashboard_url
```

## Adding or removing an instance later

1. Edit the relevant list in `terraform.tfvars`.
2. `terraform apply` — updates the SSM association target list and adds the
   instance to the dashboard automatically.
3. Attach the instance profile to the new instance (same `associate-iam-instance-profile`
   command as above, one instance).

## Adding a metric

1. Add it to `cloudwatch-agent-configs/linux-config.json` or
   `windows-config.json` (see [AWS's CloudWatch Agent config reference](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html)
   for available measurements).
2. `terraform apply` — the SSM Association re-applies within an hour (or
   force it sooner: `aws ssm start-associations-once --association-ids <id>`).
3. Add a matching widget to `dashboard.tf` if you want it visualized.

## Troubleshooting

- **No data on the dashboard**: check the agent actually started —
  `aws ssm describe-association --association-id <id>` should show
  `Status: Success`. On the instance itself, agent logs live at
  `/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log`
  (Linux) or `C:\ProgramData\Amazon\AmazonCloudWatchAgent\Logs\amazon-cloudwatch-agent.log`
  (Windows).
- **Association fails immediately**: almost always the instance profile
  from "First-time setup" wasn't attached, or SSM Agent isn't running.
- **A metric doesn't show up on a graph**: the CloudWatch Agent adds a few
  extra dimensions per metric (disk adds device/path/fstype, for example).
  The dashboard widgets use `SEARCH()` expressions specifically to avoid
  needing exact dimension matches — if you hand-write a new widget, prefer
  `SEARCH()` over a literal metric+dimension tuple for the same reason.

## Growing beyond local state

Terraform state currently lives as a local file
(`terraform/phase1-infra-monitoring/terraform.tfstate`, gitignored). That's
fine for one person applying changes. Once a second person needs to run
`terraform apply`, migrate to a shared backend:

1. Create an S3 bucket (versioning on) and a DynamoDB table with partition
   key `LockID`.
2. Add a `backend "s3" {}` block to `versions.tf` pointing at them, then run
   `terraform init -migrate-state`.

Don't do this preemptively — it's two more AWS resources to own, and not
worth it until state actually needs to be shared.

## What's next (not built yet)

- **Phase 2** — `jenkins-health-poller` Lambda: polls the Jenkins REST API
  for agent connectivity, queue depth, build results, and stuck builds;
  publishes to a `Jenkins/Pipeline` namespace; adds the Pipeline dashboard.
- **Phase 3** — CloudWatch Alarms on both namespaces, SNS topics split by
  severity, AWS Chatbot → Slack.

See `architecture.md` §8 for scope, and start a new conversation (or ask
here) when you're ready to build Phase 2 — worth doing as its own
reviewable step rather than bundling it in.
