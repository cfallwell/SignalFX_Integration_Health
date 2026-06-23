# Alert message template: AWS integration disabled

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
AWS Integration URL: https://app.<REALM>.signalfx.com/#/integrations/aws/view/{{dimensions.integrationId}}  
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
