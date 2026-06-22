# Synthetics API Test Module

This module creates a Splunk Synthetics API test that emits custom AWS integration health metrics to Splunk Observability Cloud.

## Overview

The test implements the three-step flow described in `synthetics/README.md`:

1. **GET /v2/integration**: Fetch all integrations from the Splunk Observability Cloud API
2. **JavaScript step**: Parse the response and build a metric payload using `build_metric_payload.js`
3. **POST /v2/datapoint**: Send the custom datapoint payload to the ingest API

The custom metrics emitted are:

- `custom.aws.integration.enabled` (0 or 1, per integration)
- `custom.aws.integration.inventory.present` (1, per integration found)

These metrics are consumed by the AWS integration health detector to alert on disabled integrations and integration inventory presence.

## Provider Compatibility

The module uses the `splunkdev/synthetics` provider and the `synthetics_create_api_test_v2` resource.

**Version Requirement**: `splunkdev/synthetics ~> 1.2`

### If V2 API test resource is unavailable

If the Synthetics provider does not expose `synthetics_create_api_test_v2` or equivalent, you have two options:

1. **Use the external Python poller**: Set `var.enable_synthetics = false` in the root module and deploy the poller from `poller/aws_integration_health_poller.py` on a schedule (Lambda, Kubernetes CronJob, etc.).

2. **Implement a V1 API test manually**: Create the test through the Synthetics UI or use a `synthetics_api_v1_check` resource (if available) and manually configure the three-step workflow.

Both alternatives are documented in the root `terraform/README.md`.

## Requirements

- Splunk Observability Cloud realm (e.g., `us0`, `us1`, `eu0`)
- API token with permissions to read `/v2/integration` endpoint
- Ingest token with permissions to write to `/v2/datapoint` endpoint
- At least one configured Synthetics location
- JavaScript payload builder file (`synthetics/build_metric_payload.js`)

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | string | `"AWS integration health - Synthetic API test"` | Test name |
| `realm` | string | — | **Required**. Splunk realm (e.g., `us0`) |
| `o11y_api_token` | string (sensitive) | — | **Required**. API token for reading integrations |
| `o11y_ingest_token` | string (sensitive) | — | **Required**. Ingest token for posting datapoints |
| `frequency_minutes` | number | `5` | Test frequency in minutes (1-1440) |
| `locations` | list(string) | `["aws-us-east-1"]` | Synthetics location IDs |
| `enabled` | bool | `true` | Enable or disable the test |
| `tags` | list(string) | `[]` | Tags to apply |
| `javascript_file_path` | string | — | **Required**. Path to `build_metric_payload.js` (via `file()`) |

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `test_id` | string | The ID of the created test |
| `test_name` | string | The name of the test |
| `frequency_minutes` | number | The test frequency in minutes |

## Locations

The `locations` variable expects a list of Synthetics location IDs. Common examples:

- `aws-us-east-1` — AWS US East (N. Virginia)
- `aws-us-west-2` — AWS US West (Oregon)
- `aws-eu-west-1` — AWS EU (Ireland)
- `gcp-us-central1` — Google Cloud US Central
- `azure-eastus` — Azure East US

To find the location IDs for your Synthetics account, log into Splunk Observability Cloud, navigate to **Synthetics** > **Locations**, and note the location IDs.

## Token Permissions

### API Token (read integrations)

Minimum permissions:

- Read access to `/v2/integration` endpoint
- Organization-level read permission or specific integration read access

### Ingest Token (post datapoints)

Minimum permissions:

- Write access to `/v2/datapoint` endpoint
- Ingest scope: `ingest`

For least-privilege configuration, create separate tokens:

1. One API token dedicated to reading integrations (used in the test's first step)
2. One ingest token dedicated to posting datapoints (used in the test's third step)

## Test Behavior

When the test runs at the configured frequency:

1. It fetches the full integration inventory from `/v2/integration`
2. The JavaScript step filters to AWS integrations only and extracts:
   - Integration ID
   - Integration name
   - AWS account ID (if present or extractable from IAM role ARN)
   - Enabled status (boolean)
3. It builds a gauge metric payload with two metrics per AWS integration:
   - `custom.aws.integration.enabled` (value 0 or 1)
   - `custom.aws.integration.inventory.present` (value always 1)
4. It POSTs the payload to `/v2/datapoint`

The detector subscribes to these custom metrics and alerts based on their values and trends.

## Troubleshooting

### Test fails at step 1 (GET /v2/integration)

- Verify the `o11y_api_token` is valid and not expired
- Confirm the token has read access to `/v2/integration`
- Check that the realm is correct (e.g., `us0`, not `us-0`)

### Test passes step 1 but fails at step 3 (POST /v2/datapoint)

- Verify the `o11y_ingest_token` is valid and not expired
- Confirm the token has write access to `/v2/datapoint` with ingest scope
- Ensure the metric payload is valid JSON (the JavaScript step should produce this)

### Custom metrics are not appearing in the detector

- Check that the test is running successfully (green status in Synthetics UI)
- Verify the test has run at least once since the detector was created
- Confirm the detector is subscribed to `custom.aws.integration.enabled` metric
- Check the metric namespace in Splunk Observability Cloud (Metrics > Custom)

## Example Usage

See `../../examples/minimal/main.tf` for a complete example.

## Notes

- The JavaScript payload builder (`synthetics/build_metric_payload.js`) is loaded at plan time via `file()` and embedded in the test definition.
- The test does not make HTTP requests from JavaScript — it only transforms the response from step 1.
- Handlebars template syntax (`{{custom.integrationsResponse}}`, `{{custom.metricPayload}}`) is preserved and expanded by Synthetics at runtime.
