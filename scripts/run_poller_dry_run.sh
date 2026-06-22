#!/usr/bin/env bash
set -euo pipefail

python3 poller/aws_integration_health_poller.py --dry-run
