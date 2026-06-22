# Synthetics API test setup

Use this directory when you want Splunk Synthetics to emit the custom integration-state metrics consumed by the detector.

## API test flow

### Step 1: GET all integrations

```text
Method: GET
URL: https://api.<REALM>.observability.splunkcloud.com/v2/integration
```

Headers:

```text
Accept: application/json
X-SF-TOKEN: {{env.o11y_api_token}}
```

Save the response body into this custom variable:

```text
custom.integrationsResponse
```

### Step 2: Build metric payload

Add a **Save return value from JavaScript** step. Use the JavaScript from:

```text
synthetics/build_metric_payload.js
```

Set the saved variable name to:

```text
metricPayload
```

The JavaScript reads:

```text
custom.integrationsResponse
```

and the saved return value becomes:

```text
custom.metricPayload
```

### Step 3: POST custom datapoints

```text
Method: POST
URL: https://ingest.<REALM>.observability.splunkcloud.com/v2/datapoint
```

Headers:

```text
Content-Type: application/json
X-SF-TOKEN: {{env.o11y_ingest_token}}
```

Body:

```handlebars
{{custom.metricPayload}}
```

## Metric contract

The payload builder emits:

```text
custom.aws.integration.enabled
custom.aws.integration.inventory.present
```

The important dimensions are:

```text
primaryId       = integrationId
primaryIdType   = integrationId
integrationId   = actual AWS integration ID
integrationName = AWS integration name, or unknown
awsAccountId    = AWS account ID if found, or unknown
source          = synthetic-aws-integration-health
```

## Notes

- `primaryId` is not a synthetic report ID. It is the stable object ID to show in alerts.
- The Synthetics JavaScript step only transforms the previously fetched response. It does not dynamically make additional HTTP requests.
- For dynamic per-integration validation calls, use an external poller or wrapper endpoint.
