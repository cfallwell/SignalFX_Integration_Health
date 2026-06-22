provider "signalfx" {
  auth_token = var.auth_token
  api_url    = "https://api.${var.realm}.signalfx.com"
}

provider "synthetics" {
  api_key = var.o11y_api_token
  api_url = "https://api.${var.realm}.observability.splunkcloud.com"
}
