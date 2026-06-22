# Detector alert message templates

This file contains all rule-specific message templates for `detectors/aws_integration_health_detector.signalflow`.

---

## 1. AWS integration auth failure

Rule name:

```text
AWS integration auth failure
```

Subject:

```handlebars
AWS auth failure - integration {{dimensions.integrationId}}
```

Body:

```handlebars
{{#if anomalous}}
AWS integration auth failure detected
{{else}}
AWS integration auth failure cleared
{{/if}}

Detector: {{detectorName}}
Rule: {{ruleName}}
Severity: {{ruleSeverity}}
State: {{anomalyState}}
Incident ID: {{incidentId}}

AWS Integration ID: {{dimensions.integrationId}}
AWS Namespace: {{dimensions.namespace}}
Client Interface: {{dimensions.clientInterface}}
AWS API Method: {{dimensions.method}}

Auth error signal value over the last 5 minutes: {{inputs.A.value}}

Likely impact:
Splunk Observability Cloud may be unable to retrieve AWS metrics or metadata for this integration.

Suggested checks:
1. Validate the AWS integration IAM role.
2. Validate the AWS role trust policy.
3. Confirm the configured external ID still matches.
4. Confirm required AWS permissions still exist for the namespace and method shown above.
5. Check whether this integration was recently edited, rotated, disabled, or recreated.

All signal dimensions:
{{dimensions}}

Detector URL:
{{{detectorUrl}}}

Timestamp:
{{timestamp}}
```

---

## 2. AWS integration disabled

Rule name:

```text
AWS integration disabled
```

Subject:

```handlebars
AWS integration disabled - {{dimensions.primaryId}}
```

Body:

```handlebars
{{#if anomalous}}
AWS integration is disabled
{{else}}
AWS integration is enabled again
{{/if}}

Detector: {{detectorName}}
Rule: {{ruleName}}
Severity: {{ruleSeverity}}
State: {{anomalyState}}
Incident ID: {{incidentId}}

Primary ID: {{dimensions.primaryId}}
Primary ID Type: {{dimensions.primaryIdType}}

AWS Integration ID: {{dimensions.integrationId}}
AWS Integration Name: {{dimensions.integrationName}}
AWS Account ID: {{dimensions.awsAccountId}}

Synthetic/API enabled value: {{inputs.B.value}}

Likely impact:
The AWS integration is disabled according to the custom integration inventory metric. Splunk Observability Cloud might not collect AWS metrics or metadata for this integration while it remains disabled.

Suggested checks:
1. Open the AWS integration shown above.
2. Confirm whether it was intentionally disabled.
3. Re-enable the integration if this was not expected.
4. Confirm CloudWatch import and/or Metric Streams settings are correct.
5. Validate IAM role trust and permissions after re-enabling.
6. Check whether native auth or stale-datapoint alerts are also firing.

All signal dimensions:
{{dimensions}}

Detector URL:
{{{detectorUrl}}}

Timestamp:
{{timestamp}}
```

---

## 3. AWS integration stale / no datapoints

Rule name:

```text
AWS integration stale / no datapoints
```

Subject:

```handlebars
AWS integration stale - {{dimensions.integrationId}}
```

Body:

```handlebars
{{#if anomalous}}
AWS integration appears stale or no longer producing datapoints
{{else}}
AWS integration datapoints are flowing again
{{/if}}

Detector: {{detectorName}}
Rule: {{ruleName}}
Severity: {{ruleSeverity}}
State: {{anomalyState}}
Incident ID: {{incidentId}}

AWS Integration ID: {{dimensions.integrationId}}

Estimated age of latest AWS datapoint, in minutes: {{inputs.C.value}}
Configured stale threshold, in minutes: 90

Likely impact:
Splunk Observability Cloud has not seen recent AWS datapoints for this integration. This can indicate broken collection, missing permissions, no selected services or regions producing data, a disabled integration, or an upstream AWS/API issue.

Suggested checks:
1. Open the AWS integration with the integration ID shown above.
2. Check whether the synthetic disabled-state alert is also firing.
3. Confirm CloudWatch import and/or Metric Streams are enabled as expected.
4. Confirm selected AWS regions still contain active resources.
5. Confirm selected AWS services are still expected to emit metrics.
6. Check whether an auth-failure alert is firing for the same integration ID.
7. Validate AWS IAM role trust and permissions.

All signal dimensions:
{{dimensions}}

Detector URL:
{{{detectorUrl}}}

Timestamp:
{{timestamp}}
```

---

## 4. AWS API exceptions - org scoped

Rule name:

```text
AWS API exceptions - org scoped
```

Subject:

```handlebars
AWS API exceptions - {{dimensions.namespace}} {{dimensions.method}}
```

Body:

```handlebars
{{#if anomalous}}
AWS API exceptions detected during cloud integration collection
{{else}}
AWS API exceptions cleared
{{/if}}

Detector: {{detectorName}}
Rule: {{ruleName}}
Severity: {{ruleSeverity}}
State: {{anomalyState}}
Incident ID: {{incidentId}}

AWS Namespace: {{dimensions.namespace}}
AWS API Method: {{dimensions.method}}
Exception Location: {{dimensions.location}}

API exception signal value over the last 10 minutes: {{inputs.D.value}}

Important:
This native org metric does not include integrationId or tokenId. This alert is scoped to the organization, AWS namespace, API method, and exception location rather than to a specific AWS integration.

Suggested checks:
1. Check whether AWS integration auth-failure alerts are firing at the same time.
2. Check whether AWS integration stale/no-datapoint alerts are firing at the same time.
3. Check whether AWS integration disabled alerts are firing from the custom integration inventory dataset.
4. Review the AWS namespace and API method shown above.
5. Check AWS service health or account-level API issues for the affected namespace.
6. Check for recent IAM, SCP, region, or service configuration changes.

All signal dimensions:
{{dimensions}}

Detector URL:
{{{detectorUrl}}}

Timestamp:
{{timestamp}}
```

---

## 5. Logs stopped by token

Rule name:

```text
Logs stopped by token
```

Subject:

```handlebars
Logs stopped - token {{dimensions.tokenId}}
```

Body:

```handlebars
{{#if anomalous}}
Logs appear to have stopped for token {{dimensions.tokenId}}
{{else}}
Logs are flowing again for token {{dimensions.tokenId}}
{{/if}}

Detector: {{detectorName}}
Rule: {{ruleName}}
Severity: {{ruleSeverity}}
State: {{anomalyState}}
Incident ID: {{incidentId}}

Fallback ID Type: tokenId
Log Token ID: {{dimensions.tokenId}}

Gross log messages received in the last 60 minutes: {{inputs.E.value}}

Interpretation:
The native log org metric does not include an AWS integration ID. For this rule, tokenId is the fallback identifier.

Likely impact:
Splunk Observability Cloud has not received log messages for this token during the configured window. If this token is dedicated to an AWS account, the token ID identifies the affected AWS log path.

Suggested checks:
1. Map the token ID above to the AWS account or log forwarding path that owns it.
2. Confirm the token has not been disabled, rotated, deleted, or replaced.
3. Check the AWS log forwarding path for that account.
4. Validate the forwarding component, such as Firehose, Lambda, OpenTelemetry Collector, HEC forwarding, or another configured path.
5. Confirm the AWS account is still producing logs for the expected regions and services.
6. Check whether logs are being filtered, throttled, or dropped before reaching Splunk Observability Cloud.

All signal dimensions:
{{dimensions}}

Detector URL:
{{{detectorUrl}}}

Timestamp:
{{timestamp}}
```
