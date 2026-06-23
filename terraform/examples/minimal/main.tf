# In production, configure the remote backend (uncomment and edit in versions.tf):
# terraform {
#   backend "s3" {
#     bucket         = "my-terraform-state"
#     key            = "aws-integration-health/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-locks"
#   }
# }

provider "signalfx" {
  auth_token = var.auth_token
  api_url    = "https://api.${var.realm}.signalfx.com"
}

provider "synthetics" {
  product = "observability"
  realm   = var.realm
  apikey  = var.o11y_api_token
}

module "detector" {
  source = "../../modules/detector"

  name                    = "AWS integration health"
  description             = "Monitors AWS integration health in Splunk Observability Cloud"
  tags                    = ["aws", "integration-health"]
  teams                   = []
  authorized_writer_teams = []
  authorized_writer_users = []
  time_zone               = "UTC"
  max_delay               = 900
  min_delay               = null
  rule_messages           = local.rule_messages
  rule_severities         = local.rule_severities
  rule_notifications      = var.rule_notifications
  signalflow_file_path    = file("${path.module}/../../../detectors/aws_integration_health_detector.signalflow")
}

module "synthetics" {
  count  = var.enable_synthetics ? 1 : 0
  source = "../../modules/synthetics_api_test"

  name                = "AWS integration health - Synthetic API test"
  realm               = var.realm
  o11y_api_token      = var.o11y_api_token
  o11y_ingest_token   = var.o11y_ingest_token
  frequency_minutes   = 5
  locations           = ["aws-us-east-1"]
  enabled             = true
  device_id           = 1
  scheduling_strategy = "round_robin"
  custom_properties   = {}
  javascript_code     = file("${path.module}/../../../synthetics/build_metric_payload.js")
}

output "detector_id" {
  value = module.detector.detector_id
}

output "detector_url" {
  value = module.detector.detector_url
}

output "synthetics_test_id" {
  value = var.enable_synthetics ? module.synthetics[0].test_id : null
}
