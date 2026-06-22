terraform {
  required_version = ">= 1.0"

  required_providers {
    synthetics = {
      source  = "splunkdev/synthetics"
      version = "~> 1.2"
    }
  }
}
