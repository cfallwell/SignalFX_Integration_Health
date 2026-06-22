# AWS Integration Health for Splunk Observability Cloud - Terraform Deployment

This directory contains Terraform configuration to deploy the AWS integration health monitoring stack to Splunk Observability Cloud.

## What gets created

1. **SignalFlow detector** with five alert rules:
   - AWS integration auth failure
   - AWS integration disabled
   - AWS integration stale / no datapoints
   - AWS API exceptions - org scoped
   - Logs stopped by token

2. **Synthetics API test** (optional, enabled by default) that:
   - Fetches AWS integrations from the API
   - Processes them with a JavaScript payload builder
   - Posts custom integration-state metrics to the ingest API

3. **Alert message templates** for each rule, with customer-configurable notification recipients and severity levels.

## Prerequisites

1. **Splunk Observability Cloud account** with:
   - Realm identified (e.g., `us0`, `us1`, `eu0`)
   - Access token with detector-creation permissions
   - API token with `/v2/integration` read access
   - Ingest token with `/v2/datapoint` write access

2. **Terraform** >= 1.0

3. **Synthetics locations** (if using Synthetics; see Location IDs section below)

## Provider Versions

- **splunk-terraform/signalfx**: ~> 9.14
- **splunkdev/synthetics**: ~> 1.2

These are pinned in `versions.tf` to ensure reproducible deployments.

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Set variables

Create a `terraform.tfvars` file in the `terraform/` directory with your configuration:

```hcl
realm              = "us0"
auth_token         = "your-detector-auth-token"
o11y_api_token     = "your-api-token"
o11y_ingest_token  = "your-ingest-token"

# Optional: customize detector name
detector_name = "AWS integration health"

# Optional: add notification recipients (see format below)
rule_notifications = {
  "AWS integration auth failure" = [
    "Email,sre@example.com"
  ]
  "AWS integration disabled" = [
    "Email,sre@example.com"
  ]
  # ... other rules ...
}

# Optional: customize Synthetics test
synthetics_frequency_minutes = 5
synthetics_locations = ["aws-us-east-1"]
enable_synthetics = true
```

### 3. Plan and apply

```bash
terraform plan
terraform apply
```

Terraform will create the detector and (optionally) the Synthetics test, outputting their IDs and URLs.

## Configuration Guide

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `realm` | string | Splunk Observability Cloud realm (e.g., `us0`, `us1`) |
| `auth_token` | string | API token for detector creation |
| `o11y_api_token` | string | API token for reading integrations |
| `o11y_ingest_token` | string | Ingest token for posting datapoints |

### Optional Variables

#### Detector Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `detector_name` | string | `"AWS integration health"` | Name of the detector |
| `detector_description` | string | See default | Full description |
| `detector_tags` | list(string) | `[]` | Tags applied to detector |
| `detector_teams` | list(string) | `[]` | Teams with view access |
| `detector_authorized_writer_teams` | list(string) | `[]` | Teams with edit access |
| `detector_authorized_writer_users` | list(string) | `[]` | Users with edit access |
| `detector_time_zone` | string | `"UTC"` | Detector time zone |
| `detector_max_delay` | number | `900` | Max delay in seconds (10-15 min recommended) |
| `detector_min_delay` | number | `null` | Min delay in seconds (optional) |

#### Alert Rules

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rule_notifications` | map(list(string)) | `{}` (no notifications) | Notification recipients per rule |
| `rule_severity_overrides` | map(string) | Default severities | Override rule severity levels |

#### Synthetics Test Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_synthetics` | bool | `true` | Enable/disable Synthetics test |
| `synthetics_test_name` | string | `"AWS integration health - Synthetic API test"` | Test name |
| `synthetics_frequency_minutes` | number | `5` | Test frequency (1-1440 minutes) |
| `synthetics_locations` | list(string) | `["aws-us-east-1"]` | Location IDs for test execution |
| `synthetics_enabled` | bool | `true` | Enable/disable the test |
| `synthetics_tags` | list(string) | `[]` | Tags applied to test |

## Notification Recipients

The `rule_notifications` variable controls which channels receive alerts for each rule. Format:

```hcl
rule_notifications = {
  "AWS integration auth failure" = [
    "Email,sre@example.com",
    "Slack,#aws-alerts"
  ]
  "AWS integration disabled" = [
    "Email,ops@example.com",
    "Webhook,https://example.com/webhook"
  ]
  "AWS integration stale / no datapoints" = []  # No notifications
  # ... other rules ...
}
```

Leave a rule's list empty (`[]`) to disable notifications for that rule.

Supported notification formats depend on your Splunk Observability Cloud configuration. Common formats:

- `Email,recipient@example.com`
- `Slack,#channel-name`
- `Webhook,https://example.com/webhook`
- `PagerDuty,integration-key`
- (Consult Splunk documentation for additional formats)

## Severity Levels

The `rule_severity_overrides` variable allows you to customize the severity of each rule:

```hcl
rule_severity_overrides = {
  "AWS integration auth failure" = "Critical"
  "AWS integration disabled" = "Critical"
  "AWS integration stale / no datapoints" = "Major"
  "AWS API exceptions - org scoped" = "Major"
  "Logs stopped by token" = "Major"
}
```

Valid severity values:

- `Critical`
- `Major`
- `Minor`
- `Warning`
- `Info`

Default severities are provided by the detector module; override only the rules you want to change.

## Token Management

### Creating tokens with minimum privileges

#### API Token (for reading integrations)

In Splunk Observability Cloud:

1. Go to **Settings** > **Access Tokens**
2. Click **Create Token**
3. Set the scope:
   - **Scope**: `ingest` (read access to organization data)
4. **Name**: e.g., `terraform-aws-integration-api-read`
5. Copy the token value and save it securely (e.g., in a `.env` file, not in version control)

#### Ingest Token (for posting datapoints)

1. Go to **Settings** > **Access Tokens**
2. Click **Create Token**
3. Set the scope:
   - **Scope**: `ingest` (write access to ingest API)
4. **Name**: e.g., `terraform-aws-integration-ingest`
5. Copy the token value and save it securely

#### Detector Auth Token

1. Go to **Settings** > **Access Tokens**
2. Click **Create Token**
3. Set the scope:
   - **Scope**: `admin` (to create/edit detectors)
4. **Name**: e.g., `terraform-detector-auth`
5. Copy the token value and save it securely

### Using environment variables

Instead of committing tokens to `terraform.tfvars`, use environment variables:

```bash
export TF_VAR_realm="us0"
export TF_VAR_auth_token="<token>"
export TF_VAR_o11y_api_token="<token>"
export TF_VAR_o11y_ingest_token="<token>"

terraform plan
terraform apply
```

## Location IDs for Synthetics

The `synthetics_locations` variable expects a list of location IDs where the test runs. Common AWS locations:

- `aws-us-east-1` — N. Virginia
- `aws-us-west-2` — Oregon
- `aws-eu-west-1` — Ireland
- `aws-ap-southeast-1` — Singapore
- `aws-ap-northeast-1` — Tokyo

To find your account's available locations:

1. Log into Splunk Observability Cloud
2. Go to **Synthetics**
3. Navigate to **Locations**
4. Note the location IDs

Or use the Splunk CLI or API to list locations.

## Deployment Options

### Option 1: Synthetics Test (Recommended)

The default configuration deploys a Synthetics API test that emits custom metrics every 5 minutes.

**Pros:**
- Self-contained within Splunk Observability Cloud
- No external infrastructure required
- Fully managed by Terraform

**Cons:**
- Requires Synthetics subscription
- Costs per test execution

To use this option, leave `enable_synthetics = true` in your variables.

### Option 2: External Python Poller

If you prefer not to use Synthetics, set `enable_synthetics = false` and deploy the Python poller:

```bash
export SFX_REALM="us0"
export SFX_API_TOKEN="<api-token>"
export SFX_INGEST_TOKEN="<ingest-token>"

python3 ../poller/aws_integration_health_poller.py
```

Deploy the poller on a schedule using:

- AWS Lambda (with CloudWatch Events)
- Kubernetes CronJob
- Cron (Linux/macOS)
- GitHub Actions
- Other job schedulers

The poller will emit the same custom metrics as the Synthetics test, and the detector will work identically.

## Upgrading

To upgrade to a new version of the detector or Synthetics test:

1. Edit `terraform.tfvars` with any new configuration
2. Run `terraform plan` to review changes
3. Run `terraform apply` to deploy

Terraform will handle updates to the detector rules, message templates, and Synthetics test configuration.

## Troubleshooting

### `terraform plan` fails with "Invalid API URL"

Ensure your realm is correct (e.g., `us0`, not `US0` or `us-0`). Realm format is lowercase letters followed by digits.

### Provider authentication fails

- Verify tokens are valid and not expired
- Confirm token permissions (API tokens for integrations, ingest tokens for datapoints)
- Check realm matches the token's realm

### Synthetics test doesn't run

- Confirm `enable_synthetics = true` and `synthetics_enabled = true`
- Check Synthetics location IDs are valid for your account
- Verify the test shows a green status in the Synthetics UI

### Custom metrics not appearing in detector

- Ensure the Synthetics test has run at least once (check test history in UI)
- Confirm the test is posting metrics successfully (check test response)
- Verify the detector is subscribing to `custom.aws.integration.enabled` metric
- Check the metric namespace in **Metrics** > **Custom**

## File Structure

```
terraform/
├── README.md                           # This file
├── versions.tf                         # Provider versions
├── providers.tf                        # Provider configuration
├── variables.tf                        # Root variables
├── locals.tf                           # Message templates
├── main.tf                             # Module calls
├── outputs.tf                          # Root outputs
├── modules/
│   ├── detector/                       # Reusable detector module
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── synthetics_api_test/            # Reusable Synthetics module
│       ├── versions.tf
│       ├── variables.tf
│       ├── main.tf
│       ├── outputs.tf
│       └── README.md
└── examples/
    └── minimal/                        # Minimal working example
        ├── README.md
        ├── main.tf
        ├── versions.tf
        └── terraform.tfvars.example
```

## State Management

Terraform state files (`.tfstate`, `.tfstate.backup`, `.terraform/`) should **not** be committed to version control.

A `.gitignore` file should already cover these; if not, add:

```
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.*
*.tfvars
!terraform.tfvars.example
```

For production, consider storing state remotely using Terraform Cloud or an S3 backend.

## Support and Documentation

- **Detector module**: See `modules/detector/README.md`
- **Synthetics module**: See `modules/synthetics_api_test/README.md`
- **Example**: See `examples/minimal/README.md`
- **Root repo**: See `../README.md`

For issues or questions, consult:

- [Splunk Observability Cloud documentation](https://docs.splunk.com/Observability)
- [Splunk Terraform provider documentation](https://registry.terraform.io/providers/splunk-terraform/signalfx/latest/docs)
- [Splunk Synthetics provider documentation](https://registry.terraform.io/providers/splunkdev/synthetics/latest/docs)
