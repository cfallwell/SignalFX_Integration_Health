output "test_id" {
  value       = synthetics_create_api_test_v2.aws_integration_health.id
  description = "The ID of the created Synthetics API test"
}

output "test_name" {
  value       = synthetics_create_api_test_v2.aws_integration_health.name
  description = "The name of the Synthetics API test"
}

output "frequency_minutes" {
  value       = synthetics_create_api_test_v2.aws_integration_health.frequency
  description = "The frequency of the test in minutes"
}
