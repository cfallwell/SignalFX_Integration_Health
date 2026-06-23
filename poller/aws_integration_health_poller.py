#!/usr/bin/env python3
"""
AWS integration health custom metric poller for Splunk Observability Cloud.

This script is an external alternative to the Synthetics API-test approach.
It performs the same high-level work:

1. GET /v2/integration
2. Filter AWS integrations
3. Build custom metric datapoints
4. POST /v2/datapoint

Environment variables:
  SFX_REALM          Example: us0, us1, eu0
  SFX_API_TOKEN      Token authorized to read integrations
  SFX_INGEST_TOKEN   Token authorized to ingest datapoints
  SFX_API_BASE       Optional override, for example https://api.us0.observability.splunkcloud.com
  SFX_INGEST_BASE    Optional override, for example https://ingest.us0.observability.splunkcloud.com
  SFX_METRIC_SOURCE  Optional, default synthetic-aws-integration-health

Usage:
  python3 poller/aws_integration_health_poller.py --dry-run
  python3 poller/aws_integration_health_poller.py --input-file tests/fixtures/integrations_response.json --dry-run
  python3 poller/aws_integration_health_poller.py
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

JsonObj = Dict[str, Any]

DEFAULT_SOURCE = "synthetic-aws-integration-health"
DEFAULT_TIMEOUT_SECONDS = 30
DEFAULT_CHUNK_SIZE = 500


@dataclass(frozen=True)
class Settings:
    api_base: str
    ingest_base: str
    api_token: str
    ingest_token: str
    source: str
    timeout_seconds: int
    missing_enabled: str
    dry_run: bool
    include_inventory: bool


def env_required(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def build_settings(args: argparse.Namespace) -> Settings:
    realm = os.environ.get("SFX_REALM", "").strip()
    api_base = os.environ.get("SFX_API_BASE", "").strip()
    ingest_base = os.environ.get("SFX_INGEST_BASE", "").strip()

    offline_dry_run = bool(args.input_file and args.dry_run)

    if not api_base or not ingest_base:
        if not realm:
            if offline_dry_run:
                realm = "us0"
            else:
                raise SystemExit(
                    "Set SFX_REALM or both SFX_API_BASE and SFX_INGEST_BASE."
                )
        api_base = api_base or f"https://api.{realm}.observability.splunkcloud.com"
        ingest_base = ingest_base or f"https://ingest.{realm}.observability.splunkcloud.com"

    api_token = os.environ.get("SFX_API_TOKEN", "")
    ingest_token = os.environ.get("SFX_INGEST_TOKEN", "")

    if not api_token and not args.input_file:
        api_token = env_required("SFX_API_TOKEN")
    if not ingest_token and not args.dry_run:
        ingest_token = env_required("SFX_INGEST_TOKEN")

    return Settings(
        api_base=api_base.rstrip("/"),
        ingest_base=ingest_base.rstrip("/"),
        api_token=api_token or "dry-run-api-token",
        ingest_token=ingest_token or "dry-run-ingest-token",
        source=os.environ.get("SFX_METRIC_SOURCE", DEFAULT_SOURCE),
        timeout_seconds=args.timeout,
        missing_enabled=args.missing_enabled,
        dry_run=args.dry_run,
        include_inventory=not args.no_inventory,
    )


def http_json(
    method: str,
    url: str,
    token: str,
    body: Optional[JsonObj] = None,
    timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS,
) -> JsonObj:
    data = None
    headers = {
        "Accept": "application/json",
        "X-SF-TOKEN": token,
    }

    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(url, data=data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            raw = response.read().decode("utf-8")
            if not raw:
                return {}
            return json.loads(raw)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"HTTP {exc.code} calling {method} {url}: {detail}"
        ) from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Failed calling {method} {url}: {exc}") from exc


def get_integrations(settings: Settings) -> Sequence[JsonObj]:
    payload = http_json(
        "GET",
        f"{settings.api_base}/v2/integration",
        settings.api_token,
        timeout_seconds=settings.timeout_seconds,
    )
    return normalize_integration_list(payload)


def normalize_integration_list(payload: Any) -> Sequence[JsonObj]:
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]

    if not isinstance(payload, dict):
        return []

    for key in ("integrations", "results", "data", "rs"):
        value = payload.get(key)
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]

    return []


def is_aws_integration(integration: JsonObj) -> bool:
    integration_type = str(integration.get("type", "")).lower()
    integration_name = str(integration.get("name", "")).lower()

    if "aws" in integration_type:
        return True

    if integration_type == "awscloudwatch":
        return True

    if "aws" in integration_name and "cloud" in integration_type:
        return True

    return False


def first_present(obj: JsonObj, keys: Sequence[str]) -> Optional[Any]:
    for key in keys:
        value = obj.get(key)
        if value is not None and value != "":
            return value
    return None


def find_first_key_recursive(
    value: Any,
    keys: Sequence[str],
    max_depth: int = 4,
) -> Optional[Any]:
    if max_depth < 0:
        return None

    if isinstance(value, dict):
        direct = first_present(value, keys)
        if direct is not None:
            return direct

        for child in value.values():
            found = find_first_key_recursive(child, keys, max_depth=max_depth - 1)
            if found is not None and found != "":
                return found

    elif isinstance(value, list):
        for child in value:
            found = find_first_key_recursive(child, keys, max_depth=max_depth - 1)
            if found is not None and found != "":
                return found

    return None


def parse_account_from_arn(value: Optional[Any]) -> Optional[str]:
    if not value:
        return None
    match = re.match(r"^arn:aws[a-zA-Z-]*:iam::([0-9]{12}):", str(value))
    return match.group(1) if match else None


def extract_aws_account_id(integration: JsonObj) -> str:
    direct = find_first_key_recursive(
        integration,
        ("awsAccountId", "accountId", "accountID", "account"),
        max_depth=3,
    )
    if direct is not None and str(direct).strip():
        return str(direct)

    role_arn = find_first_key_recursive(
        integration,
        ("roleArn", "roleARN", "awsRoleArn", "awsRoleARN"),
        max_depth=5,
    )
    parsed = parse_account_from_arn(role_arn)
    return parsed or "unknown"


def enabled_value(integration: JsonObj, missing_enabled: str) -> Optional[int]:
    if "enabled" in integration:
        return 0 if integration.get("enabled") is False else 1

    if missing_enabled == "skip":
        return None
    if missing_enabled == "enabled":
        return 1
    if missing_enabled == "disabled":
        return 0

    raise ValueError(f"Unexpected missing_enabled mode: {missing_enabled}")


def to_aws_namespace(service: Any) -> Optional[str]:
    """Normalize a Splunk Observability service code into a CloudWatch
    namespace string of the form 'AWS/<Service>'.

    The /v2/integration response uses values like 'EC2', 'AWS_EC2', or
    sometimes already 'AWS/EC2'. The native metric
    sf.org.num.awsServiceCallCountExceptions exposes them in the 'AWS/X'
    form, so we normalize to match.

    Returns None for empty/garbage input.
    """
    if service is None:
        return None
    text = str(service).strip()
    if not text:
        return None
    if text.startswith("AWS/"):
        return text
    # Strip the common internal prefixes Splunk uses.
    for prefix in ("AWS_", "AWS"):
        if text.startswith(prefix):
            text = text[len(prefix):]
            break
    text = text.strip("_/")
    if not text:
        return None
    return f"AWS/{text}"


def extract_integration_namespaces(integration: JsonObj) -> List[str]:
    """Pull AWS namespaces covered by this integration from any of the common
    fields the /v2/integration response may use, and normalize them.
    """
    raw: List[Any] = []
    for key in ("services", "namespaces", "awsServices"):
        value = integration.get(key)
        if isinstance(value, list):
            raw.extend(value)

    seen = set()
    out: List[str] = []
    for item in raw:
        ns = to_aws_namespace(item)
        if ns and ns not in seen:
            seen.add(ns)
            out.append(ns)
    return out


def safe_dimension(value: Any) -> str:
    text = str(value) if value is not None else "unknown"
    text = text.strip()
    if not text:
        return "unknown"
    return text[:256]


def common_dimensions(integration: JsonObj, source: str) -> Optional[Dict[str, str]]:
    integration_id = first_present(integration, ("id", "integrationId"))
    if not integration_id:
        return None

    integration_id_text = safe_dimension(integration_id)
    return {
        "primaryId": integration_id_text,
        "primaryIdType": "integrationId",
        "integrationId": integration_id_text,
        "integrationName": safe_dimension(integration.get("name", "unknown")),
        "awsAccountId": safe_dimension(extract_aws_account_id(integration)),
        "source": source,
    }


def build_gauge_datapoints(
    integrations: Sequence[JsonObj],
    source: str = DEFAULT_SOURCE,
    missing_enabled: str = "skip",
    include_inventory: bool = True,
) -> List[JsonObj]:
    gauge: List[JsonObj] = []
    now_ms = int(time.time() * 1000)

    for integration in integrations:
        if not is_aws_integration(integration):
            continue

        dimensions = common_dimensions(integration, source)
        if not dimensions:
            continue

        if include_inventory:
            gauge.append(
                {
                    "metric": "custom.aws.integration.inventory.present",
                    "dimensions": dimensions,
                    "value": 1,
                    "timestamp": now_ms,
                }
            )

        enabled = enabled_value(integration, missing_enabled=missing_enabled)
        if enabled is not None:
            gauge.append(
                {
                    "metric": "custom.aws.integration.enabled",
                    "dimensions": dimensions,
                    "value": enabled,
                    "timestamp": now_ms,
                }
            )

        # Per-namespace coverage. Each (integration, namespace) pair gets a
        # value=1 datapoint so SignalFlow can join API exceptions
        # (which carry 'namespace' but no integrationId) back to integrations
        # via the namespace dimension.
        for namespace in extract_integration_namespaces(integration):
            ns_dimensions = dict(dimensions)
            ns_dimensions["namespace"] = safe_dimension(namespace)
            gauge.append(
                {
                    "metric": "custom.aws.integration.namespace",
                    "dimensions": ns_dimensions,
                    "value": 1,
                    "timestamp": now_ms,
                }
            )

    return gauge


def chunked(items: Sequence[JsonObj], size: int) -> Iterable[Sequence[JsonObj]]:
    for index in range(0, len(items), size):
        yield items[index : index + size]


def post_datapoints(settings: Settings, gauge: Sequence[JsonObj]) -> None:
    if not gauge:
        print("No datapoints to send.")
        return

    if settings.dry_run:
        print(json.dumps({"gauge": list(gauge)}, indent=2, sort_keys=True))
        return

    for chunk in chunked(list(gauge), DEFAULT_CHUNK_SIZE):
        http_json(
            "POST",
            f"{settings.ingest_base}/v2/datapoint",
            settings.ingest_token,
            body={"gauge": list(chunk)},
            timeout_seconds=settings.timeout_seconds,
        )
        print(f"Posted {len(chunk)} datapoints.")


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the datapoint payload instead of posting it.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT_SECONDS,
        help=f"HTTP timeout in seconds. Default: {DEFAULT_TIMEOUT_SECONDS}",
    )
    parser.add_argument(
        "--missing-enabled",
        choices=("skip", "enabled", "disabled"),
        default="skip",
        help=(
            "What to do when an integration object does not include an enabled field. "
            "Default: skip custom.aws.integration.enabled for that integration."
        ),
    )
    parser.add_argument(
        "--no-inventory",
        action="store_true",
        help="Do not emit custom.aws.integration.inventory.present.",
    )
    parser.add_argument(
        "--input-file",
        help="Read an integrations API response from a local JSON file instead of calling /v2/integration.",
    )
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    settings = build_settings(args)

    if args.input_file:
        with open(args.input_file, "r", encoding="utf-8") as handle:
            integrations = normalize_integration_list(json.load(handle))
    else:
        integrations = get_integrations(settings)
    aws_integrations = [item for item in integrations if is_aws_integration(item)]
    gauge = build_gauge_datapoints(
        aws_integrations,
        source=settings.source,
        missing_enabled=settings.missing_enabled,
        include_inventory=settings.include_inventory,
    )

    print(f"Found {len(integrations)} integrations; {len(aws_integrations)} look like AWS.")
    print(f"Built {len(gauge)} gauge datapoints.")
    post_datapoints(settings, gauge)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
