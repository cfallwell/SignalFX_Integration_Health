resource "synthetics_create_api_check_v2" "aws_integration_health" {
  test {
    active              = var.enabled
    device_id           = var.device_id
    frequency           = var.frequency_minutes
    location_ids        = var.locations
    name                = var.name
    scheduling_strategy = var.scheduling_strategy

    dynamic "custom_properties" {
      for_each = var.custom_properties
      content {
        key   = custom_properties.key
        value = custom_properties.value
      }
    }

    # Request 1: GET /v2/integration
    requests {
      configuration {
        name           = "Get integrations"
        request_method = "GET"
        url            = "https://api.${var.realm}.observability.splunkcloud.com/v2/integration"
        headers = {
          "Accept"     = "application/json"
          "X-SF-TOKEN" = var.o11y_api_token
        }
      }

      # Setup step 1: Save response body as integrationsResponse
      setup {
        name     = "Save Response Body"
        type     = "save"
        value    = "{{response.body}}"
        variable = "integrationsResponse"
      }

      # Setup step 2: Run JavaScript payload builder
      setup {
        name     = "Build metric payload"
        type     = "javascript"
        code     = var.javascript_code
        variable = "metricPayload"
      }

      # Validation: Assert HTTP 200
      validations {
        name       = "Status 200"
        type       = "assert_numeric"
        actual     = "{{response.code}}"
        comparator = "equals"
        expected   = 200
      }
    }

    # Request 2: POST /v2/datapoint
    requests {
      configuration {
        name           = "Post datapoints"
        request_method = "POST"
        url            = "https://ingest.${var.realm}.observability.splunkcloud.com/v2/datapoint"
        headers = {
          "Content-Type" = "application/json"
          "X-SF-TOKEN"   = var.o11y_ingest_token
        }
        body = "{{custom.metricPayload}}"
      }

      # Validation: Assert HTTP 200
      validations {
        name       = "Status 200"
        type       = "assert_numeric"
        actual     = "{{response.code}}"
        comparator = "equals"
        expected   = 200
      }
    }
  }
}
