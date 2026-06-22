resource "synthetics_create_api_test_v2" "aws_integration_health" {
  name                = var.name
  description         = "Synthetic API test for AWS integration health monitoring"
  active              = var.enabled
  frequency           = var.frequency_minutes
  location_ids        = var.locations
  tags                = var.tags
  custom_properties   = {}

  # Step 1: GET /v2/integration
  steps = [
    {
      name     = "Get integrations"
      type     = "API"
      method   = "GET"
      url      = "https://api.${var.realm}.observability.splunkcloud.com/v2/integration"
      headers = {
        "Accept"       = "application/json"
        "X-SF-TOKEN"   = var.o11y_api_token
      }
      body              = ""
      extract_json_data = {
        "integrationsResponse" = "."
      }
      variable_names = ["integrationsResponse"]
    },

    # Step 2: JavaScript payload builder
    {
      name      = "Build metric payload"
      type      = "JavaScript"
      code      = var.javascript_file_path
      variables = ["integrationsResponse"]
      extract_variables = {
        "metricPayload" = "metricPayload"
      }
      variable_names = ["metricPayload"]
    },

    # Step 3: POST /v2/datapoint
    {
      name     = "Post datapoints"
      type     = "API"
      method   = "POST"
      url      = "https://ingest.${var.realm}.observability.splunkcloud.com/v2/datapoint"
      headers = {
        "Content-Type" = "application/json"
        "X-SF-TOKEN"   = var.o11y_ingest_token
      }
      body     = "{{custom.metricPayload}}"
      extract_json_data = {}
      variable_names    = []
    }
  ]
}
