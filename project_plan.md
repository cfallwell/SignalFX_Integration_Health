# Project Plan: Splunk Observability Cloud Integration Health Detectors

## Objective

Build production-ready detector packages that alert on the health of cloud integrations in Splunk Observability Cloud. Each detector reports the most precise affected-object identifier the underlying metric exposes (typically the Splunk Observability integration ID, with documented fallbacks where a native metric does not carry one). All artifacts are wrapped in Terraform so a customer can deploy the full stack with `terraform apply`.

The project is scoped in two phases:

- **Phase 1 (MVP — delivered):** AWS integrations.
- **Phase 2 (future):** Expand to GCP and Azure integrations using the same architecture.

The AWS implementation in Phase 1 is the reference design. Phase 2 will mirror it for the other cloud providers wherever Splunk's native metric naming and integration-API shapes permit.

---

## Phase 1 (MVP — delivered): AWS Integration Health

The goal of the MVP was to alert when AWS integrations fail, are disabled, stop producing datapoints, generate AWS API exceptions, or stop receiving logs. The detector reports the AWS `integrationId`, `awsAccountId`, and `integrationName` wherever the native or custom metric supports it. Where those identifiers are not available, the detector reports the best available fallback (such as `tokenId` for log ingest).

### Architecture

#### Native Splunk Observability org metrics

Use native org metrics for the signals Splunk already emits:

| Signal                         | Metric                                     | Identifier available              |
| ------------------------------ | ------------------------------------------ | --------------------------------- |
| AWS auth failures              | `sf.org.num.awsServiceAuthErrorCount`      | `integrationId`                   |
| AWS latest datapoint timestamp | `sf.org.datainventory.latestTimestamp`     | `integrationId`                   |
| AWS API exceptions             | `sf.org.num.awsServiceCallCountExceptions` | `namespace`, `method`, `location` |
| Log ingest heartbeat           | `sf.org.log.grossMessagesReceivedByToken`  | `tokenId`                         |

#### Synthetic/API-derived custom metrics

Use a Synthetics API test or external poller to fill the native gap for exact disabled-state detection and to enrich the API exceptions alert with candidate integrations:

| Custom metric                              | Purpose                                                                                                                                                | Identifier available                                |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------- |
| `custom.aws.integration.enabled`           | Exact integration enabled/disabled state when returned reliably by the API                                                                             | `primaryId`, `integrationId`                        |
| `custom.aws.integration.inventory.present` | Confirms the producer saw the integration                                                                                                              | `primaryId`, `integrationId`                        |
| `custom.aws.integration.namespace`         | Per-(integration, namespace) coverage so the API exceptions alert can correlate `namespace` back to a candidate integration                            | `integrationId`, `integrationName`, `awsAccountId`, `namespace` |

#### Identifier standard

| Dimension         | Meaning                                                            |
| ----------------- | ------------------------------------------------------------------ |
| `primaryId`       | Stable affected-object ID to show in the alert                     |
| `primaryIdType`   | Type of `primaryId`, usually `integrationId`                       |
| `integrationId`   | Actual Splunk Observability AWS integration ID                     |
| `integrationName` | Human-friendly integration name when available                     |
| `awsAccountId`    | AWS account ID when available or derivable from role ARN           |
| `source`          | Custom metric producer, default `synthetic-aws-integration-health` |

`primaryId` is not a unique report/run ID. Do not populate it with a synthetic run ID. It must be a stable entity identifier.

### Implementation steps

#### Step 1.1 — Validate metrics and dimensions

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

#### Step 1.2 — Deploy custom integration-state producer

Choose one producer (Synthetics is the default; the external poller is a fallback for environments where Synthetics is not viable):

##### Option A: Synthetics API test (default)

Provisioned by Terraform via `terraform/modules/synthetics_api_test`. The test executes two requests:

1. `GET /v2/integration`.
2. `POST /v2/datapoint` with body `{{custom.metricPayload}}`, after a `save` step persists the GET response body and a `javascript` step transforms it via `synthetics/build_metric_payload.js`.

Default schedule is every 1 minute (tunable via `synthetics_frequency_minutes`).

##### Option B: External poller

1. Deploy `poller/aws_integration_health_poller.py` to a scheduled runtime.
2. Configure the required environment variables:
  - `SFX_REALM`
  - `SFX_API_TOKEN`
  - `SFX_INGEST_TOKEN`
3. Run with `--dry-run` first.
4. Confirm custom datapoints appear in Metric Finder.
5. Schedule every 1 minute (or longer if the Synthetics frequency is increased).

Exit criteria:

- `custom.aws.integration.enabled` appears in Metric Finder.
- `custom.aws.integration.inventory.present` appears in Metric Finder.
- `custom.aws.integration.namespace` appears in Metric Finder.
- Dimensions include `primaryId`, `primaryIdType`, `integrationId`, `integrationName`, and (for the namespace metric) `namespace`.

#### Step 1.3 — Install detector and namespace coverage chart

1. Provision the detector via `terraform/modules/detector`. The module loads `detectors/aws_integration_health_detector.signalflow` via `file()` and wires the five rules to message templates in `terraform/locals.tf`.
2. Provision the namespace coverage list chart via `terraform/charts.tf`. Its URL is interpolated into the API exceptions alert body so responders can pivot from `namespace` to candidate integrations in one click.
3. Detector resolution is 1 minute and `max_delay` defaults to 5 minutes (tunable).

Severities (all tunable via `rule_severity_overrides`):

| Rule                                    | Severity          |
| --------------------------------------- | ----------------- |
| `AWS integration auth failure`          | Critical          |
| `AWS integration disabled`              | Critical          |
| `AWS integration stale / no datapoints` | Major             |
| `AWS API exceptions - org scoped`       | Major             |
| `Logs stopped by token`                 | Major             |

Each rule that carries `integrationId` (auth failure, disabled, stale) also includes a deep link to the integration's view page in Splunk Observability:
`https://app.${realm}.signalfx.com/#/integrations/aws/view/{{dimensions.integrationId}}`

Exit criteria:

- Detector validates.
- Each rule has the correct message template with Markdown hard-break line endings so the body renders as multi-line in email/Slack notifications.
- Alert preview shows the expected dimensions and deep links.

#### Step 1.4 — Test scenarios

| # | Scenario                                                       | Expected alert                                                                          |
| - | -------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| 1 | Disable one AWS integration intentionally                      | `AWS integration disabled` fires with `integrationId` and integration view URL          |
| 2 | Break IAM trust or permissions for one AWS integration         | `AWS integration auth failure` fires with `integrationId` and integration view URL      |
| 3 | Stop datapoints by disabling import or breaking collection     | `AWS integration stale / no datapoints` fires with `integrationId` after threshold      |
| 4 | Force or wait for an AWS API exception                         | `AWS API exceptions - org scoped` fires with namespace/method/location + chart deep link |
| 5 | Stop one AWS log token path                                    | `Logs stopped by token` fires with `tokenId`                                            |

Exit criteria:

- Alerts include the intended identifier(s) and URLs.
- Alert noise is acceptable at the chosen detection windows.
- Runbook links and routing are correct.

#### Step 1.5 — Hardening

1. Store API tokens as Terraform variables marked `sensitive = true`. The customer's actual values live in `terraform.tfvars` (gitignored).
2. Use least privilege for the API token (integrations:read for the Synthetics GET; ingest for the POST).
3. Use a dedicated ingest token for custom metric emission.
4. Add owner/team dimensions later if needed, but avoid high-cardinality or unstable dimensions.
5. Monitor the Synthetics API test or external poller separately so stale custom state does not hide producer failures.
6. Add CI checks that validate Python code, JS payload builder, SignalFlow file presence, and `terraform validate` on the root and example.

### Known limitations (Phase 1)

1. `sf.org.num.awsServiceCallCountExceptions` does not provide `integrationId`. The MVP mitigates this by emitting `custom.aws.integration.namespace` and linking the alert body to a namespace-coverage list chart that lets responders identify candidate integrations.
2. `sf.org.log.grossMessagesReceivedByToken` is token-scoped, not integration-scoped.
3. Disabled-state accuracy depends on whether the Integrations API response reliably exposes `enabled` for AWS integrations in the customer realm.
4. If the API response always returns `enabled: true`, use the custom inventory metric for enrichment and rely on the native auth/stale detectors for failure detection.
5. A native no-static-token logs rule can alert only for token streams that have existed as metric time series. It cannot infer a token that was expected but has never emitted.

### Production follow-ups (Phase 1)

- Add a runbook that maps token IDs to AWS log forwarding paths if token ID is the only available log identifier.
- Add account aliases as custom properties or dimensions if the integration response does not include them.
- Consider a wrapper service if you need per-integration validation fan-out using `/v2/integration/validate/{id}` for every integration.
- Add a synthetic or detector for the custom metric producer itself.

---

## Phase 2 (future): GCP and Azure expansion

### Goal

Extend the detector pattern to Splunk Observability Cloud's GCP and Azure cloud integrations, reusing the Phase 1 architecture (native org metrics + Synthetics/poller producer + Terraform-managed detector and chart).

### Strategy

Mirror Phase 1's three-layer design for each new cloud:

1. **Native layer.** Identify Splunk's native org-metric equivalents for auth failures, datapoint staleness, API exceptions, and log ingest health for that cloud.
2. **Custom-producer layer.** Extend the existing Synthetics API test and Python poller to also enumerate GCP and Azure integrations from `GET /v2/integration` and emit `custom.gcp.integration.*` and `custom.azure.integration.*` metrics with the analogous identifier dimensions.
3. **Detector and chart layer.** Build per-cloud SignalFlow programs and message templates, packaged either as additional rules on the existing detector or as sibling detectors. Provision a per-cloud namespace coverage chart for the API-exceptions-equivalent rule.

### Open questions to resolve at the start of Phase 2

These need verification against the customer's realm before committing to specific metric names or schemas:

1. **Native metric naming.** Does Splunk expose equivalents for GCP and Azure (e.g., `sf.org.num.gcpServiceAuthErrorCount`, `sf.org.num.azureServiceAuthErrorCount`)? If naming differs, the SignalFlow tunables and module structure may need adjustment.
2. **Identifier conventions.** GCP integrations are keyed by project + service account; Azure by subscription + tenant + app registration. Decide which fields fill `primaryId`, `awsAccountId`-equivalents, and whether new dimensions are needed (e.g., `gcpProjectId`, `azureSubscriptionId`, `azureTenantId`).
3. **Service / namespace mapping.** For Phase 1's `custom.aws.integration.namespace`, AWS service codes normalize cleanly into `AWS/<Service>`. GCP services are referenced differently (e.g., `compute.googleapis.com`); Azure uses resource-provider names (`Microsoft.Compute`). Decide whether to canonicalize into a shared namespace convention or keep cloud-specific dimensions.
4. **Deep-link URL patterns.** Phase 1's rules deep-link to `https://app.${realm}.signalfx.com/#/integrations/aws/view/{integrationId}`. Confirm the equivalent paths for GCP (`/#/integrations/gcp/view/...`) and Azure (`/#/integrations/azure/view/...`) before parameterizing.
5. **API response field names for `enabled`/`services`.** Confirm the `/v2/integration` shape for GCP and Azure integrations and how to detect their disabled state.

### Implementation steps

#### Step 2.1 — Discovery and design

- Validate the open questions above against the customer realm.
- Decide on shared vs. per-cloud Terraform module layout (likely: one module per cloud under `terraform/modules/{detector_aws,detector_gcp,detector_azure}` with a shared base module for cross-cloud concerns).
- Decide whether to keep one combined detector or split into per-cloud detectors. (Recommended: per-cloud detectors so notifications and severity policies can differ.)

#### Step 2.2 — Refactor for multi-cloud

- Generalize `synthetics/build_metric_payload.js` and `poller/aws_integration_health_poller.py` to dispatch on integration `type` and emit cloud-prefixed custom metrics.
- Generalize the SignalFlow file with shared tunables but per-cloud blocks for the native metrics that differ between clouds.
- Generalize the namespace coverage chart to be parameterizable by cloud.
- Keep all Phase 1 file paths intact for backward compatibility; rename only where needed and provide migration notes.

#### Step 2.3 — GCP producer and detector

- Add `custom.gcp.integration.enabled`, `custom.gcp.integration.inventory.present`, `custom.gcp.integration.namespace` (or equivalent dimension names).
- Add GCP rule wiring: GCP integration auth failure, disabled, stale, API exceptions, logs stopped.
- Provision a `signalfx_list_chart` for the GCP namespace coverage.
- Deep-link rules to the GCP integration view URL.
- Reuse Phase 1's message-template structure with cloud-appropriate language.

#### Step 2.4 — Azure producer and detector

- Mirror Step 2.3 for Azure. Account for the two-level Azure identifier (`subscriptionId` + `tenantId`) in `primaryId` selection and alert body.

#### Step 2.5 — Cross-cloud rollup

- Add a top-level "Integration health overview" dashboard provisioned by Terraform (`signalfx_dashboard`) that surfaces per-cloud counts of unhealthy integrations using the new per-cloud detectors.
- Optionally publish a single combined "anything unhealthy" alert that fans out by cloud.

### Phase 2 exit criteria

- Each of the three cloud providers (AWS — already done; GCP; Azure) has equivalent detector coverage for the five rule categories where the underlying metric supports it.
- Each provider's alert body includes a deep link to the integration's view page when an `integrationId` is available, and a chart link when only namespace-level information is available.
- A single `terraform apply` deploys the customer's chosen subset of cloud detectors via `enable_aws`, `enable_gcp`, and `enable_azure` flags.

### Phase 2 out of scope

- Non-Splunk-native cloud monitoring sources (e.g., OpenTelemetry collector health, direct CloudWatch / GCP Monitoring / Azure Monitor scraping).
- Detector packages for non-cloud Splunk Observability integrations (PagerDuty, Slack, etc.). These could be a Phase 3 if needed.
