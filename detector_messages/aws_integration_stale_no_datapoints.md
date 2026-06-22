# Alert message template: AWS integration stale / no datapoints

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
