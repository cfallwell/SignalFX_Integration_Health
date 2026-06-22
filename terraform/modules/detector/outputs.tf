output "detector_id" {
  value       = signalfx_detector.detector.id
  description = "The ID of the created detector"
}

output "detector_url" {
  value       = signalfx_detector.detector.url
  description = "The URL of the detector in Splunk Observability Cloud"
}

output "rule_label_to_name" {
  value = {
    for rule in signalfx_detector.detector.rule : rule.detect_label => rule.id
  }
  description = "Map of rule detect_label to rule name/id"
}
