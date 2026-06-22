# Project Plan: AWS Integration Health Detector

## Objective

Build a production-ready detector package for AWS integration health in Splunk Observability Cloud. Leave room for building detector packages for all other integration types in Splunk Observability Cloud.

The goal is to alert when AWS integrations fail, are disabled, stop producing datapoints, generate AWS API exceptions, or stop receiving logs. The detector should report the AWS `integrationId`, AWSaccountId and AWSaccountName wherever the native or custom metric supports it. If the id's above are not available, the detector should report the best available fallback identifier, such as `tokenId` for log ingest.

## Architecture

### Native Splunk Observability org metrics

Use native org metrics for the signals Splunk already emits:


| Signal                         | Metric                                     | Identifier available              |
| ------------------------------ | ------------------------------------------ | --------------------------------- |
| AWS auth failures              | `sf.org.num.awsServiceAuthErrorCount`      | `integrationId`                   |
| AWS latest datapoint timestamp | `sf.org.datainventory.latestTimestamp`     | `integrationId`                   |
| AWS API exceptions             | `sf.org.num.awsServiceCallCountExceptions` | `namespace`, `method`, `location` |
| Log ingest heartbeat           | `sf.org.log.grossMessagesReceivedByToken`  | `tokenId`                         |


### Synthetic/API-derived custom metrics

Use a Synthetics API test or external poller to fill the native gap for exact disabled-state detection:


| Custom metric                              | Purpose                                                                    | Identifier available         |
| ------------------------------------------ | -------------------------------------------------------------------------- | ---------------------------- |
| `custom.aws.integration.enabled`           | Exact integration enabled/disabled state when returned reliably by the API | `primaryId`, `integrationId` |
| `custom.aws.integration.inventory.present` | Confirms the API poller saw the integration                                | `primaryId`, `integrationId` |


### Identifier standard

Use these dimensions in custom metrics:


| Dimension         | Meaning                                                            |
| ----------------- | ------------------------------------------------------------------ |
| `primaryId`       | Stable affected-object ID to show in the alert                     |
| `primaryIdType`   | Type of `primaryId`, usually `integrationId`                       |
| `integrationId`   | Actual Splunk Observability AWS integration ID                     |
| `integrationName` | Human-friendly integration name when available                     |
| `awsAccountId`    | AWS account ID when available or derivable from role ARN           |
| `source`          | Custom metric producer, default `synthetic-aws-integration-health` |


`primaryId` is not a unique report/run ID. Do not populate it with a synthetic run ID. It must be a stable entity identifier.

## Implementation phases

### Phase 1: Validate metrics and dimensions

1. In Metric Finder, confirm these native metrics are present:
  - `sf.org.num.awsServiceAuthErrorCount`
  - `sf.org.datainventory.latestTimestamp`
  - `sf.org.num.awsServiceCallCountExceptions`
  - `sf.org.log.grossMessagesReceivedByToken`
2. Confirm `integrationId` exists on the AWS auth-error and data-inventory metrics.
3. Confirm `tokenId` exists on the log metric.
4. Confirm API-exception metric dimensions are limited to API context, not integration context.

Exit criteria:

- Each native stream can be charted.
- Aggregation dimensions in the SignalFlow script match the dimensions available in the customer realm.

### Phase 2: Deploy custom integration-state producer

Choose one producer:

#### Option A: Synthetics API test

1. Create an API test.
2. Add a request to `GET /v2/integration`.
3. Save the response body as `custom.integrationsResponse`.
4. Add a Save return value from JavaScript step using `synthetics/build_metric_payload.js`.
5. Save the returned value as custom variable `metricPayload`.
6. Add a request to `POST /v2/datapoint` using `{{custom.metricPayload}}` as the body.
7. Schedule the API test every 5 minutes.

#### Option B: External poller

1. Deploy `poller/aws_integration_health_poller.py` to a scheduled runtime.
2. Configure the required environment variables:
  - `SFX_REALM`
  - `SFX_API_TOKEN`
  - `SFX_INGEST_TOKEN`
3. Run with `--dry-run` first.
4. Confirm custom datapoints appear in Metric Finder.
5. Schedule every 5 minutes.

Exit criteria:

- `custom.aws.integration.enabled` appears in Metric Finder.
- `custom.aws.integration.inventory.present` appears in Metric Finder.
- Dimensions include `primaryId`, `primaryIdType`, `integrationId`, and `integrationName`.

### Phase 3: Install detector

1. Create a new detector.
2. Paste `detectors/aws_integration_health_detector.signalflow` into the SignalFlow editor.
3. Set detector resolution to 1 minute.
4. Set max delay to 10-15 minutes.
5. Create alert rules from the `detect().publish()` labels.
6. Apply message templates from `detector_messages/all_message_templates.md`.
7. Assign severities and notification policies.

Suggested severities:


| Rule                                    | Severity          |
| --------------------------------------- | ----------------- |
| `AWS integration auth failure`          | Critical          |
| `AWS integration disabled`              | Critical          |
| `AWS integration stale / no datapoints` | Critical or Major |
| `AWS API exceptions - org scoped`       | Major             |
| `Logs stopped by token`                 | Critical or Major |


Exit criteria:

- Detector validates.
- Each rule has the correct message template.
- Alert preview shows the expected dimensions.

### Phase 4: Test scenarios

Run these test cases:

1. Disable one AWS integration intentionally.
  - Expected: `AWS integration disabled` fires with `integrationId`.
2. Break IAM trust or permissions for one AWS integration.
  - Expected: `AWS integration auth failure` fires with `integrationId`.
3. Stop datapoints by disabling import or breaking collection.
  - Expected: `AWS integration stale / no datapoints` fires with `integrationId` after threshold.
4. Force or wait for an AWS API exception.
  - Expected: `AWS API exceptions - org scoped` fires with namespace/method/location.
5. Stop one AWS log token path.
  - Expected: `Logs stopped by token` fires with `tokenId`.

Exit criteria:

- Alerts include the intended identifier.
- Alert noise is acceptable.
- Runbook links and routing are correct.

### Phase 5: Hardening

1. Store API tokens as concealed Synthetics/global variables or platform secrets.
2. Use least privilege for the API token.
3. Use a dedicated ingest token for custom metric emission.
4. Add owner/team dimensions later if needed, but avoid high-cardinality or unstable dimensions.
5. Monitor the Synthetics API test or external poller separately so stale custom state does not hide poller failures.
6. Add CI checks that validate Python code and SignalFlow file presence.

## Known limitations

1. `sf.org.num.awsServiceCallCountExceptions` does not provide `integrationId`, so the API exception alert is org/API scoped.
2. `sf.org.log.grossMessagesReceivedByToken` is token-scoped, not integration-scoped.
3. Disabled-state accuracy depends on whether the Integrations API response reliably exposes `enabled` for AWS integrations in the customer realm.
4. If the API response always returns `enabled: true`, use the custom inventory metric for enrichment and rely on the native auth/stale detectors for failure detection.
5. A native no-static-token logs rule can alert only for token streams that have existed as metric time series. It cannot infer a token that was expected but has never emitted.

## Production follow-ups

- Add a runbook that maps token IDs to AWS log forwarding paths if token ID is the only available log identifier.
- Add account aliases as custom properties or dimensions if the integration response does not include them.
- Consider a wrapper service if you need per-integration validation fan-out using `/v2/integration/validate/{id}` for every integration.
- Add a synthetic or detector for the custom metric producer itself.

