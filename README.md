# AWS Integration Health for Splunk Observability Cloud

This repository contains a repo-ready implementation for monitoring AWS integrations in Splunk Observability Cloud.

It includes:

- A complete SignalFlow detector program.
- Alert message templates for each detector rule.
- A Synthetics API test JavaScript payload builder for custom integration-state metrics.
- A runnable external Python poller that can be used instead of Synthetics.
- A Terraform-managed namespace coverage chart that the API exceptions alert deep-links to.
- Example payloads and test fixtures.
- A project plan documenting the MVP scope and the roadmap.

## Roadmap

The current release is the **MVP (Phase 1)**: full coverage of AWS integrations.

A **future release (Phase 2)** will extend the same detector pattern to **GCP and Azure** integrations in Splunk Observability Cloud, using the same architecture (native org metrics + Synthetics/poller producer + Terraform-managed detector and chart). See [`project_plan.md`](project_plan.md) for the Phase 2 design questions and implementation steps.

## What this monitors

The detector covers five alert rules:

1. `AWS integration auth failure`
   - Native metric: `sf.org.num.awsServiceAuthErrorCount`
   - Reports `integrationId`.

2. `AWS integration disabled`
   - Custom metric: `custom.aws.integration.enabled`
   - Emitted by the Synthetics API test or external poller.
   - Reports `primaryId`, which is the integration ID for this rule.

3. `AWS integration stale / no datapoints`
   - Native metric: `sf.org.datainventory.latestTimestamp`
   - Reports `integrationId`.

4. `AWS API exceptions - org scoped`
   - Native metric: `sf.org.num.awsServiceCallCountExceptions`
   - Reports `namespace`, `method`, and `location`.
   - This native metric does not include `integrationId`.

5. `Logs stopped by token`
   - Native metric: `sf.org.log.grossMessagesReceivedByToken`
   - Reports `tokenId` because native log org metrics are token-scoped rather than AWS-integration scoped.
   - This is the fallback identifier when integration ID is unavailable.

## Repository layout

```text
.
├── README.md
├── project_plan.md
├── config.example.env
├── detectors/
│   └── aws_integration_health_detector.signalflow
├── detector_messages/
│   ├── all_message_templates.md
│   ├── aws_api_exceptions_org_scoped.md
│   ├── aws_integration_auth_failure.md
│   ├── aws_integration_disabled.md
│   ├── aws_integration_stale_no_datapoints.md
│   └── logs_stopped_by_token.md
├── synthetics/
│   ├── README.md
│   └── build_metric_payload.js
├── poller/
│   └── aws_integration_health_poller.py
├── tests/
│   ├── test_poller.py
│   └── fixtures/
│       └── integrations_response.json
├── examples/
│   └── datapoint_payload_example.json
└── scripts/
    └── run_poller_dry_run.sh
```

## Deployment options

### Option A: Terraform (Recommended)

Use Terraform to deploy the entire stack as code:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This creates:
- The SignalFlow detector with all five rules and message templates
- (Optionally) the Synthetics API test for emitting custom metrics
- Notification channels and alert routes

See [terraform/README.md](terraform/README.md) for full documentation, including:
- Provider versions and configuration
- Required and optional variables
- Token management
- Troubleshooting

This is the **recommended path** for customers who want repeatable, version-controlled deployments.

### Option B: Splunk Synthetics API test

Use the Synthetics API test to:

1. `GET https://api.<REALM>.observability.splunkcloud.com/v2/integration`
2. Save the response body as `custom.integrationsResponse`.
3. Run `synthetics/build_metric_payload.js` as a **Save return value from JavaScript** step and name the saved variable `metricPayload`.
4. `POST {{custom.metricPayload}}` to `https://ingest.<REALM>.observability.splunkcloud.com/v2/datapoint`.

This is the most self-contained option inside Splunk Observability Cloud but requires manual UI steps. Terraform automates this process (see Option A above).

### Option C: External poller

Run the Python poller on a schedule using Lambda, Kubernetes CronJob, cron, GitHub Actions, or another scheduler.

```bash
export SFX_REALM="us0"
export SFX_API_TOKEN="<api-token>"
export SFX_INGEST_TOKEN="<ingest-token>"

python3 poller/aws_integration_health_poller.py --dry-run
python3 poller/aws_integration_health_poller.py
```

The poller queries all integrations, filters AWS integrations, builds custom datapoints, and posts them to `/v2/datapoint`. This is a good alternative if you prefer not to use Synthetics.

## Detector install

Create a detector in Splunk Observability Cloud, open **Edit SignalFlow**, and paste:

```text
detectors/aws_integration_health_detector.signalflow
```

Then add the alert messages from:

```text
detector_messages/all_message_templates.md
```

Recommended detector settings:

```text
Resolution: 1 minute
Max delay: 10-15 minutes
```

## Important behavior

`primaryId` is not a synthetic report ID. It is the stable affected-object ID used for alerting.

For integration-derived metrics:

```text
primaryId = integrationId
primaryIdType = integrationId
```

For log metrics, native org data does not include an AWS integration ID, so the detector reports:

```text
tokenId
```

This matches the desired behavior: report the integration ID when available, and use the token ID only when the integration ID is unavailable.
