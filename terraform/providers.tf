provider "signalfx" {
  auth_token = var.auth_token
  api_url    = "https://api.${var.realm}.signalfx.com"
}

provider "synthetics" {
  product = "observability"
  realm   = var.realm
  apikey  = var.o11y_api_token
}
