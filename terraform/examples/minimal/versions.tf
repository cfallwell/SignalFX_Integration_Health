terraform {
  required_version = ">= 1.5"

  required_providers {
    signalfx = {
      source  = "splunk-terraform/signalfx"
      version = "~> 9.14"
    }
    synthetics = {
      source  = "splunk/synthetics"
      version = "~> 2.0"
    }
  }
}
