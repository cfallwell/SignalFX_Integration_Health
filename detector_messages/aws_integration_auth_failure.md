# Alert message template: AWS integration auth failure

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
AWS Integration URL: https://app.<REALM>.signalfx.com/#/integrations/aws/view/{{dimensions.integrationId}}
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
