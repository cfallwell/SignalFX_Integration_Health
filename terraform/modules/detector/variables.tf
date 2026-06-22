variable "name" {
  type        = string
  default     = "AWS integration health"
  description = "Name of the detector"
}

variable "description" {
  type        = string
  default     = "Monitors AWS integration health in Splunk Observability Cloud using native metrics and custom integration inventory data from Synthetics or external poller."
  description = "Description of the detector"
}

variable "tags" {
  type        = list(string)
  default     = []
  description = "Tags to apply to the detector"
}

variable "teams" {
  type        = list(string)
  default     = []
  description = "Teams authorized to view and edit the detector"
}

variable "authorized_writer_teams" {
  type        = list(string)
  default     = []
  description = "Teams authorized to write (edit) the detector"
}

variable "authorized_writer_users" {
  type        = list(string)
  default     = []
  description = "Users authorized to write (edit) the detector"
}

variable "time_zone" {
  type        = string
  default     = "UTC"
  description = "Time zone for the detector"
}

variable "max_delay" {
  type        = number
  default     = 900
  description = "Maximum delay in seconds (default 900 = 15 minutes; recommended 10-15 minutes)"
}

variable "min_delay" {
  type        = number
  default     = null
  description = "Minimum delay in seconds (optional)"
}

variable "rule_messages" {
  type = map(object({
    subject = string
    body    = string
  }))
  description = "Map of rule label to subject and body message templates"
}

variable "rule_severities" {
  type        = map(string)
  description = "Map of rule label to severity (Critical, Major, Minor, Warning, Info)"
}

variable "rule_notifications" {
  type        = map(list(string))
  default     = {}
  description = "Map of rule label to list of notification recipients (e.g., 'Email,sre@example.com')"
}

variable "signalflow_file_path" {
  type        = string
  description = "Path to the SignalFlow detector program file (usually loaded via file() function)"
}
