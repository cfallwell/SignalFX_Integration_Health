terraform {
  required_version = ">= 1.0"

  required_providers {
    synthetics = {
      source  = "splunk/synthetics"
      version = "~> 2.0"
    }
  }
}
