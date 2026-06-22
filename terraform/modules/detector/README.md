# Detector Module

This module creates a Splunk Observability Cloud detector for monitoring AWS integration health.

## Overview

The detector implements five alert rules:

1. **AWS integration auth failure** (Critical by default)
   - Detects authentication failures when pulling AWS metrics
   - Metric: `sf.org.num.awsServiceAuthErrorCount`

2. **AWS integration disabled** (Critical by default)
   - Detects when an AWS integration is marked as disabled in the custom inventory
   - Metric: `custom.aws.integration.enabled`

3. **AWS integration stale / no datapoints** (Major by default)
   - Detects when AWS datapoints stop flowing or become stale
   - Metric: `sf.org.datainventory.latestTimestamp`

4. **AWS API exceptions - org scoped** (Major by default)
   - Detects AWS API call exceptions
   - Metric: `sf.org.num.awsServiceCallCountExceptions`

5. **Logs stopped by token** (Major by default)
   - Detects when log messages stop arriving for a token
   - Metric: `sf.org.log.grossMessagesReceivedByToken`

## Message Templates

Alert message templates (subject and body) are provided via the `rule_messages` input variable. Each message uses Handlebars syntax and includes:

- Detector metadata: `{{detectorName}}`, `{{ruleName}}`, `{{ruleSeverity}}`
- Signal dimensions: `{{dimensions.integrationId}}`, etc.
- Input signal values: `{{inputs.A.value}}`, `{{inputs.B.value}}`, etc.

The templates are sourced from the root `detector_messages/` directory and loaded via the `locals.tf` file in the root Terraform module.

## Requirements

- SignalFlow program text (loaded from `detectors/aws_integration_health_detector.signalflow`)
- Rule messages with subject and body (provided via variable)
- Rule severity levels (provided via variable or defaults)
- Optional notification recipients (provided via variable, defaults to empty)

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | string | `"AWS integration health"` | Detector name |
| `description` | string | See default | Detector description |
| `tags` | list(string) | `[]` | Tags to apply to detector |
| `teams` | list(string) | `[]` | Teams with access to detector |
| `authorized_writer_teams` | list(string) | `[]` | Teams authorized to edit detector |
| `authorized_writer_users` | list(string) | `[]` | Users authorized to edit detector |
| `time_zone` | string | `"UTC"` | Detector time zone |
| `max_delay` | number | `900` | Max delay in seconds (recommended 10-15 minutes) |
| `min_delay` | number | `null` | Min delay in seconds (optional) |
| `rule_messages` | map(object) | — | **Required**. Map of rule label to subject/body templates |
| `rule_severities` | map(string) | — | **Required**. Map of rule label to severity level |
| `rule_notifications` | map(list(string)) | `{}` | Map of rule label to notification recipients |
| `signalflow_file_path` | string | — | **Required**. SignalFlow program text (via `file()` function) |

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `detector_id` | string | The ID of the created detector |
| `detector_url` | string | The URL of the detector in the UI |
| `rule_label_to_name` | map(string) | Map of rule label to rule ID |

## Notification Recipients

The `rule_notifications` variable is a map where:

- **Key**: The exact rule label (e.g., `"AWS integration auth failure"`)
- **Value**: A list of notification strings in the format accepted by the signalfx provider

Examples of valid notification formats:

```hcl
rule_notifications = {
  "AWS integration auth failure" = [
    "Email,sre@example.com",
    "Slack,#aws-alerts"
  ]
  "AWS integration disabled" = [
    "Webhook,https://example.com/webhook"
  ]
  "Logs stopped by token" = []  # No notifications
}
```

Leave a rule's list empty (`[]`) to disable notifications for that rule.

## Severity Levels

Valid severity values:
- `Critical`
- `Major`
- `Minor`
- `Warning`
- `Info`

The detector module includes default severity levels, but these can be overridden via the `rule_severities` variable.

## Example Usage

See `../../examples/minimal/main.tf` for a complete example.

## Notes

- The SignalFlow program is loaded once at plan time via `file()` and reused by all five rules.
- Each rule is independent and can have different severity levels and notification recipients.
- Handlebars template syntax is preserved in the `parameterized_subject` and `parameterized_body` fields — these are expanded by Splunk Observability Cloud at alert time, not by Terraform.
