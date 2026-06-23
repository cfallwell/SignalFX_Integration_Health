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

    # Request 1: GET /v2/integration — fetch the integration inventory.
    # Setup steps run BEFORE a request executes and access the PREVIOUS request's
    # response, so we cannot run save/javascript here for request 1's own body.
    # The save + JS steps live in request 2's setup, where they have access to
    # this request's response.
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

      validations {
        name       = "Status 200"
        type       = "assert_numeric"
        actual     = "{{response.code}}"
        comparator = "equals"
        expected   = 200
      }
    }

    # Request 2: POST /v2/datapoint — emit the custom integration-health metrics.
    # Setup steps here run BEFORE this POST executes, with {{response.body}}
    # referring to request 1's GET /v2/integration response.
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

      # Setup step 1: persist request 1's response body for the JS step to read.
      setup {
        name     = "Save integrations response body"
        type     = "save"
        value    = "{{response.body}}"
        variable = "integrationsResponse"
      }

      # Setup step 2: transform the saved body into a SignalFx datapoint payload.
      # The script's final expression is captured into custom.metricPayload via
      # the variable attribute below, then interpolated into this request's body.
      setup {
        name     = "Build metric payload"
        type     = "javascript"
        code     = var.javascript_code
        variable = "metricPayload"
      }

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
