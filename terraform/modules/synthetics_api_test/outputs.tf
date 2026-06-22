output "test_id" {
  value       = synthetics_create_api_check_v2.aws_integration_health.id
  description = "The ID of the created Synthetics API check (V2)."
}

output "test_name" {
  value       = var.name
  description = "The name of the Synthetics API check, echoed from input."
}

output "frequency_minutes" {
  value       = var.frequency_minutes
  description = "The configured frequency of the test, in minutes."
}
