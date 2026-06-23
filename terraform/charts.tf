# ============================================================
# AWS integration namespace coverage chart
# ============================================================
#
# A companion chart for the "AWS API exceptions - org scoped" rule.
#
# The native sf.org.num.awsServiceCallCountExceptions metric carries
# 'namespace' but NOT 'integrationId', so the alert itself cannot point at
# the responsible integration. This chart visualizes the custom
# 'custom.aws.integration.namespace' metric emitted by the producer
# (Synthetics test or external poller), showing every (integration,
# namespace) pair currently covered.
#
# The alert body for the API exceptions rule deep-links to this chart so
# a responder can sort by namespace and immediately see which
# integration(s) cover the affected AWS service.

resource "signalfx_list_chart" "namespace_coverage" {
  name        = "${var.detector_name} - AWS namespace coverage"
  description = "Lists which AWS integrations cover which AWS namespaces, based on custom.aws.integration.namespace emitted by the Synthetics test or external poller. Use this when the 'AWS API exceptions - org scoped' alert fires to find candidate integrations for the affected namespace."

  program_text = <<-EOT
    A = data('custom.aws.integration.namespace', filter=filter('source', 'synthetic-aws-integration-health'), rollup='latest', extrapolation='last_value', maxExtrapolations=10080).max(by=['integrationId', 'integrationName', 'awsAccountId', 'namespace']).publish(label='Namespace coverage')
  EOT

  sort_by                 = "-value"
  refresh_interval        = 300
  max_delay               = var.detector_max_delay
  hide_missing_values     = true
  disable_sampling        = false
  max_precision           = 0
  secondary_visualization = "None"

  legend_options_fields {
    property = "sf_originatingMetric"
    enabled  = false
  }
  legend_options_fields {
    property = "source"
    enabled  = false
  }
}

output "namespace_coverage_chart_id" {
  value       = signalfx_list_chart.namespace_coverage.id
  description = "ID of the namespace coverage list chart"
}

output "namespace_coverage_chart_url" {
  value       = signalfx_list_chart.namespace_coverage.url
  description = "URL of the namespace coverage list chart (linked from the API exceptions alert body)"
}
