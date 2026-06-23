import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "poller"))

from aws_integration_health_poller import (  # noqa: E402
    build_gauge_datapoints,
    extract_aws_account_id,
    extract_integration_namespaces,
    is_aws_integration,
    normalize_integration_list,
    to_aws_namespace,
)


def load_fixture():
    fixture = Path(__file__).parent / "fixtures" / "integrations_response.json"
    return json.loads(fixture.read_text())


def test_normalize_integration_list():
    payload = load_fixture()
    integrations = normalize_integration_list(payload)
    assert len(integrations) == 3


def test_is_aws_integration():
    integrations = normalize_integration_list(load_fixture())
    assert is_aws_integration(integrations[0]) is True
    assert is_aws_integration(integrations[1]) is True
    assert is_aws_integration(integrations[2]) is False


def test_extract_account_from_role_arn():
    integrations = normalize_integration_list(load_fixture())
    assert extract_aws_account_id(integrations[0]) == "111122223333"
    assert extract_aws_account_id(integrations[1]) == "444455556666"


def test_build_gauge_datapoints():
    integrations = normalize_integration_list(load_fixture())
    gauge = build_gauge_datapoints(integrations)

    metrics = [item["metric"] for item in gauge]
    assert metrics.count("custom.aws.integration.inventory.present") == 2
    assert metrics.count("custom.aws.integration.enabled") == 2

    enabled_points = [
        item for item in gauge if item["metric"] == "custom.aws.integration.enabled"
    ]
    values_by_integration = {
        item["dimensions"]["integrationId"]: item["value"] for item in enabled_points
    }

    assert values_by_integration["aws-integration-001"] == 1
    assert values_by_integration["aws-integration-002"] == 0

    for point in gauge:
        dims = point["dimensions"]
        assert dims["primaryId"] == dims["integrationId"]
        assert dims["primaryIdType"] == "integrationId"
        assert dims["source"] == "synthetic-aws-integration-health"


def test_to_aws_namespace_normalization():
    assert to_aws_namespace("EC2") == "AWS/EC2"
    assert to_aws_namespace("AWS/EC2") == "AWS/EC2"
    assert to_aws_namespace("AWS_EC2") == "AWS/EC2"
    assert to_aws_namespace("AWSLambda") == "AWS/Lambda"
    assert to_aws_namespace("  S3  ") == "AWS/S3"
    assert to_aws_namespace(None) is None
    assert to_aws_namespace("") is None
    assert to_aws_namespace("   ") is None


def test_extract_integration_namespaces():
    integrations = normalize_integration_list(load_fixture())
    # First AWS integration has services=["EC2","S3","Lambda"]
    ns0 = extract_integration_namespaces(integrations[0])
    assert ns0 == ["AWS/EC2", "AWS/S3", "AWS/Lambda"]
    # Second AWS integration has namespaces=["AWS/EKS","AWS_EC2"]
    ns1 = extract_integration_namespaces(integrations[1])
    assert ns1 == ["AWS/EKS", "AWS/EC2"]
    # Non-AWS integration has neither field
    assert extract_integration_namespaces(integrations[2]) == []


def test_build_namespace_coverage_datapoints():
    integrations = normalize_integration_list(load_fixture())
    gauge = build_gauge_datapoints(integrations)

    ns_points = [
        item for item in gauge if item["metric"] == "custom.aws.integration.namespace"
    ]
    # 3 namespaces for integration-001 + 2 for integration-002 = 5 total
    assert len(ns_points) == 5

    # Each point must carry integrationId AND namespace and have value=1
    for p in ns_points:
        assert p["value"] == 1
        assert p["dimensions"]["integrationId"]
        assert p["dimensions"]["namespace"].startswith("AWS/")
        assert p["dimensions"]["source"] == "synthetic-aws-integration-health"

    # Verify the namespace dimension matches what the sf.org native exception
    # metric uses (AWS/Service form), so SignalFlow can join.
    namespaces_for_001 = {
        p["dimensions"]["namespace"]
        for p in ns_points
        if p["dimensions"]["integrationId"] == "aws-integration-001"
    }
    assert namespaces_for_001 == {"AWS/EC2", "AWS/S3", "AWS/Lambda"}
