module "detector" {
  source = "./modules/detector"

  name                    = var.detector_name
  description             = var.detector_description
  tags                    = var.detector_tags
  teams                   = var.detector_teams
  authorized_writer_teams = var.detector_authorized_writer_teams
  authorized_writer_users = var.detector_authorized_writer_users
  time_zone               = var.detector_time_zone
  max_delay               = var.detector_max_delay
  min_delay               = var.detector_min_delay
  rule_messages           = local.rule_messages
  rule_severities         = local.rule_severities
  rule_notifications      = var.rule_notifications
  signalflow_file_path    = file("${path.module}/../detectors/aws_integration_health_detector.signalflow")
}

module "synthetics" {
  count  = var.enable_synthetics ? 1 : 0
  source = "./modules/synthetics_api_test"

  name                = var.synthetics_test_name
  realm               = var.realm
  o11y_api_token      = var.o11y_api_token
  o11y_ingest_token   = var.o11y_ingest_token
  frequency_minutes   = var.synthetics_frequency_minutes
  locations           = var.synthetics_locations
  enabled             = var.synthetics_enabled
  device_id           = var.synthetics_device_id
  scheduling_strategy = var.synthetics_scheduling_strategy
  custom_properties   = var.synthetics_custom_properties
  javascript_code     = file("${path.module}/../synthetics/build_metric_payload.js")
}
