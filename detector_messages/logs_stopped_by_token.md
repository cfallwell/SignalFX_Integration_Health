# Alert message template: Logs stopped by token

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
