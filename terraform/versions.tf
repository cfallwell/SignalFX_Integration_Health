terraform {
  required_version = ">= 1.0"

  required_providers {
    signalfx = {
      source  = "splunk-terraform/signalfx"
      version = "~> 9.14"
    }
    synthetics = {
      source  = "splunkdev/synthetics"
      version = "~> 1.2"
    }
  }
}
