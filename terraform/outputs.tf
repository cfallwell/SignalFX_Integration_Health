output "detector_id" {
  value       = module.detector.detector_id
  description = "The ID of the AWS integration health detector"
}

output "detector_url" {
  value       = module.detector.detector_url
  description = "The URL of the detector in Splunk Observability Cloud"
}

output "detector_rule_labels" {
  value       = module.detector.rule_labels
  description = "Detect labels wired up on the detector, in order"
}

output "detector_label_resolutions" {
  value       = module.detector.label_resolutions
  description = "Map of detect_label to evaluation resolution in milliseconds, populated after apply"
}

output "synthetics_test_id" {
  value       = var.enable_synthetics ? module.synthetics[0].test_id : null
  description = "The ID of the Synthetics API test (if enabled)"
}

output "synthetics_test_name" {
  value       = var.enable_synthetics ? module.synthetics[0].test_name : null
  description = "The name of the Synthetics API test (if enabled)"
}

output "synthetics_frequency_minutes" {
  value       = var.enable_synthetics ? module.synthetics[0].frequency_minutes : null
  description = "The frequency of the Synthetics test in minutes (if enabled)"
}
