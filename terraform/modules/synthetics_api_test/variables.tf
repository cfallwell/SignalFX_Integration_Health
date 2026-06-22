variable "name" {
  type        = string
  default     = "AWS integration health - Synthetic API test"
  description = "Name of the Synthetics test"
}

variable "realm" {
  type        = string
  description = "Splunk Observability Cloud realm (e.g., 'us0', 'us1')"
}

variable "o11y_api_token" {
  type        = string
  sensitive   = true
  description = "Splunk Observability Cloud API token for reading integrations"
}

variable "o11y_ingest_token" {
  type        = string
  sensitive   = true
  description = "Splunk Observability Cloud ingest token for posting datapoints"
}

variable "frequency_minutes" {
  type        = number
  default     = 5
  description = "Frequency to run the test in minutes (1-1440)"

  validation {
    condition     = var.frequency_minutes > 0 && var.frequency_minutes <= 1440
    error_message = "Frequency must be between 1 and 1440 minutes."
  }
}

variable "locations" {
  type        = list(string)
  default     = ["aws-us-east-1"]
  description = "List of Synthetics location IDs (e.g., 'aws-us-east-1')"
}

variable "enabled" {
  type        = bool
  default     = true
  description = "Enable or disable the test"
}

variable "tags" {
  type        = list(string)
  default     = []
  description = "Tags to apply to the test"
}

variable "javascript_file_path" {
  type        = string
  description = "Path to the JavaScript payload builder file (loaded via file())"
}
