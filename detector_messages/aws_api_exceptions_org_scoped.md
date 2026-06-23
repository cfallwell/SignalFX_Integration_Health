# Alert message template: AWS API exceptions - org scoped

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

How to identify the responsible integration:
1. Open the "AWS namespace coverage" list chart created by the Terraform module. Filter by namespace = {{dimensions.namespace}} to see every AWS integration that covers this namespace — those are the candidates.
2. Cross-reference with the "AWS integration auth failure" rule. That rule fires on sf.org.num.awsServiceAuthErrorCount, which DOES carry integrationId and will usually co-fire on the same namespace when the root cause is integration-level (IAM, role trust, external ID).
3. Browse all AWS integrations in this org: https://app.<REALM>.signalfx.com/#/integrations/aws

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
