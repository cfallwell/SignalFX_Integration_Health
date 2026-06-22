output "detector_id" {
  value       = signalfx_detector.detector.id
  description = "The ID of the created detector"
}

output "detector_url" {
  value       = signalfx_detector.detector.url
  description = "The URL of the detector in Splunk Observability Cloud"
}

output "label_resolutions" {
  value       = signalfx_detector.detector.label_resolutions
  description = "Map of detect_label to evaluation resolution in milliseconds, as reported by the SignalFx API after detector creation"
}

output "rule_labels" {
  value       = [for r in signalfx_detector.detector.rule : r.detect_label]
  description = "List of detect_labels wired up on this detector, in order"
}
