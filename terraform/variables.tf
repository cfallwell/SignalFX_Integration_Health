variable "realm" {
  type        = string
  description = "Splunk Observability Cloud realm (e.g., 'us0', 'us1', 'eu0')"

  validation {
    condition     = can(regex("^[a-z]{2}[0-9]+$", var.realm))
    error_message = "Realm must be in format like 'us0', 'us1', 'eu0', etc."
  }
}

variable "auth_token" {
  type        = string
  description = "Splunk Observability Cloud API token with permissions to create detectors"
  sensitive   = true
}

variable "o11y_api_token" {
  type        = string
  description = "Splunk Observability Cloud API token for reading integrations (Synthetics use)"
  sensitive   = true
}

variable "o11y_ingest_token" {
  type        = string
  description = "Splunk Observability Cloud ingest token for posting datapoints (Synthetics use)"
  sensitive   = true
}

variable "detector_name" {
  type        = string
  default     = "AWS integration health"
  description = "Name of the detector"
}

variable "detector_description" {
  type        = string
  default     = "Monitors AWS integration health in Splunk Observability Cloud using native metrics and custom integration inventory data from Synthetics or external poller."
  description = "Description of the detector"
}

variable "detector_tags" {
  type        = list(string)
  default     = []
  description = "Tags to apply to the detector"
}

variable "detector_teams" {
  type        = list(string)
  default     = []
  description = "Teams authorized to view and edit the detector"
}

variable "detector_authorized_writer_teams" {
  type        = list(string)
  default     = []
  description = "Teams authorized to write (edit) the detector"
}

variable "detector_authorized_writer_users" {
  type        = list(string)
  default     = []
  description = "Users authorized to write (edit) the detector"
}

variable "detector_time_zone" {
  type        = string
  default     = "UTC"
  description = "Time zone for the detector"
}

variable "detector_max_delay" {
  type        = number
  default     = 900
  description = "Maximum delay in seconds (default 900 = 15 minutes; recommended 10-15 minutes)"
}

variable "detector_min_delay" {
  type        = number
  default     = null
  description = "Minimum delay in seconds (optional)"
}

variable "rule_notifications" {
  type = map(list(string))
  default = {
    "AWS integration auth failure"          = []
    "AWS integration disabled"              = []
    "AWS integration stale / no datapoints" = []
    "AWS API exceptions - org scoped"       = []
    "Logs stopped by token"                 = []
  }
  description = <<-EOT
    Map of rule label to list of notification recipients (e.g., "Email,sre@example.com").
    Keyed by the exact rule label published in the detector.
    An empty list means no notifications for that rule.
  EOT
}

variable "rule_severity_overrides" {
  type = map(string)
  default = {
    "AWS integration auth failure"          = "Critical"
    "AWS integration disabled"              = "Critical"
    "AWS integration stale / no datapoints" = "Major"
    "AWS API exceptions - org scoped"       = "Major"
    "Logs stopped by token"                 = "Major"
  }
  description = "Map of rule label to severity override. If not specified, defaults are used."
}

variable "enable_synthetics" {
  type        = bool
  default     = true
  description = "Enable the Splunk Synthetics API test for custom integration metrics. Set false to use external poller instead."
}

variable "synthetics_test_name" {
  type        = string
  default     = "AWS integration health - Synthetic API test"
  description = "Name of the Synthetics API test"
}

variable "synthetics_frequency_minutes" {
  type        = number
  default     = 5
  description = "Frequency of the Synthetics test in minutes"

  validation {
    condition     = var.synthetics_frequency_minutes > 0 && var.synthetics_frequency_minutes <= 1440
    error_message = "Frequency must be between 1 and 1440 minutes."
  }
}

variable "synthetics_locations" {
  type        = list(string)
  default     = ["aws-us-east-1"]
  description = "List of Synthetics location IDs to run the test (e.g., 'aws-us-east-1'). Common values: 'aws-us-east-1', 'aws-us-west-2', 'aws-eu-west-1', 'aws-ap-southeast-2'"
}

variable "synthetics_enabled" {
  type        = bool
  default     = true
  description = "Enable or disable the Synthetics test"
}

variable "synthetics_device_id" {
  type        = number
  default     = 1
  description = "Splunk Synthetics device ID for the test. This must be a valid device ID in your realm. Contact Splunk Observability support to confirm the device ID available in your organization."
}

variable "synthetics_scheduling_strategy" {
  type        = string
  default     = "round_robin"
  description = "Scheduling strategy for the Synthetics test. 'round_robin' distributes test runs across available locations."
}

variable "synthetics_custom_properties" {
  type        = map(string)
  default     = {}
  description = "Custom properties to attach to the Synthetics test as key-value pairs for metadata and filtering"
}
