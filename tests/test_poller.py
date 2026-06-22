import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "poller"))

from aws_integration_health_poller import (  # noqa: E402
    build_gauge_datapoints,
    extract_aws_account_id,
    is_aws_integration,
    normalize_integration_list,
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
