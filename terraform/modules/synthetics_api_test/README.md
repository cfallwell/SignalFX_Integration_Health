# Synthetics API Test Module

This module creates a Splunk Synthetics API check that emits custom AWS integration health metrics to Splunk Observability Cloud.

## Overview

The test implements the two-step flow described in `synthetics/README.md`:

1. **Request 1 — GET /v2/integration**: Fetch all integrations from the Splunk Observability Cloud API
   - Setup step: Save the response body as `integrationsResponse`
   - Setup step: Run JavaScript payload builder to parse and transform the response
   - Validation: Assert HTTP 200 status
2. **Request 2 — POST /v2/datapoint**: Send the custom datapoint payload to the ingest API
   - Validation: Assert HTTP 200 status

The custom metrics emitted are:

- `custom.aws.integration.enabled` (0 or 1, per integration)
- `custom.aws.integration.inventory.present` (1, per integration found)

These metrics are consumed by the AWS integration health detector to alert on disabled integrations and integration inventory presence.

## Provider Compatibility

The module uses the `splunk/synthetics` provider and the `synthetics_create_api_check_v2` resource.

**Version Requirement**: `splunk/synthetics ~> 2.0`

### If V2 API check resource is unavailable

If the Synthetics provider does not expose `synthetics_create_api_check_v2` or equivalent, you have two options:

1. **Use the external Python poller**: Set `var.enable_synthetics = false` in the root module and deploy the poller from `poller/aws_integration_health_poller.py` on a schedule (Lambda, Kubernetes CronJob, etc.).

2. **Implement via Synthetics UI**: Create the test through the Synthetics UI manually and configure the two-request workflow.

Both alternatives are documented in the root `terraform/README.md`.

## Requirements

- Splunk Observability Cloud realm (e.g., `us0`, `us1`, `eu0`)
- API token with permissions to read `/v2/integration` endpoint
- Ingest token with permissions to write to `/v2/datapoint` endpoint
- At least one configured Synthetics location
- Valid Synthetics device ID for your organization (typically 1; verify with your Splunk account)
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
| `device_id` | number | `1` | Splunk Synthetics device ID (must be valid in your realm; typically 1) |
| `scheduling_strategy` | string | `"round_robin"` | Scheduling strategy for the test |
| `custom_properties` | map(string) | `{}` | Custom key-value properties for the test |
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
- `aws-ap-southeast-2` — AWS Asia Pacific (Sydney)
- `gcp-us-central1` — Google Cloud US Central
- `azure-eastus` — Azure East US

To find the location IDs for your Synthetics account, log into Splunk Observability Cloud, navigate to **Synthetics** > **Locations**, and note the location IDs.

## Device ID

The `device_id` parameter is required by the Splunk Synthetics provider. Most organizations have a default device with ID `1`. To verify the correct device ID for your organization:

1. Log into Splunk Observability Cloud
2. Navigate to **Synthetics** > **Devices**
3. Note the device ID for the device you wish to use
4. Pass this ID in the `device_id` variable

If you are unsure, contact your Splunk Observability Cloud account representative.

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

1. One API token dedicated to reading integrations (used in the test's first request)
2. One ingest token dedicated to posting datapoints (used in the test's second request)

## Test Behavior

When the test runs at the configured frequency:

1. **Request 1 (GET /v2/integration)**:
   - Fetches the full integration inventory from `/v2/integration`
   - Saves the response body into a custom variable `integrationsResponse`
   - Runs the JavaScript payload builder to parse and transform the response
   - The builder filters to AWS integrations only and extracts:
     - Integration ID
     - Integration name
     - AWS account ID (if present or extractable from IAM role ARN)
     - Enabled status (boolean)
   - Builds a gauge metric payload with two metrics per AWS integration:
     - `custom.aws.integration.enabled` (value 0 or 1)
     - `custom.aws.integration.inventory.present` (value always 1)
   - Asserts HTTP 200 response code

2. **Request 2 (POST /v2/datapoint)**:
   - POSTs the metric payload to `/v2/datapoint`
   - Asserts HTTP 200 response code

The detector subscribes to these custom metrics and alerts based on their values and trends.

## Troubleshooting

### Test fails at request 1 (GET /v2/integration)

- Verify the `o11y_api_token` is valid and not expired
- Confirm the token has read access to `/v2/integration`
- Check that the realm is correct (e.g., `us0`, not `us-0`)

### Test passes request 1 but fails at request 2 (POST /v2/datapoint)

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
- The JavaScript step only transforms the response from request 1; it does not make additional HTTP requests.
- Handlebars template syntax (`{{response.body}}`, `{{metricPayload}}`) is preserved and expanded by Synthetics at runtime.
- The `custom_properties` map allows you to attach custom metadata key-value pairs to the test for filtering and organization.
