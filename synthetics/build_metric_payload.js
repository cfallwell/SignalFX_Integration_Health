/*
  Splunk Synthetics JavaScript step

  Input custom variable:
    custom.integrationsResponse

  Output custom variable:
    metricPayload, saved as custom.metricPayload by the Synthetics step

  Configure this as a Save return value from JavaScript step and set
  the output variable name to:
    metricPayload

  The next API test request should POST {{custom.metricPayload}} to:
    https://ingest.<REALM>.observability.splunkcloud.com/v2/datapoint

  Notes:
    - This code does not use Node.js modules.
    - It does not make HTTP calls from JavaScript.
    - It only transforms the response from a prior API test request.
*/

function asString(value, fallback) {
  if (value === null || value === undefined || value === '') {
    return fallback;
  }
  return String(value);
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function findFirstKeyRecursive(obj, keyNames, maxDepth) {
  if (maxDepth < 0 || !isObject(obj)) {
    return null;
  }

  for (var i = 0; i < keyNames.length; i++) {
    var key = keyNames[i];
    if (Object.prototype.hasOwnProperty.call(obj, key)) {
      return obj[key];
    }
  }

  for (var prop in obj) {
    if (!Object.prototype.hasOwnProperty.call(obj, prop)) {
      continue;
    }
    var child = obj[prop];
    if (isObject(child)) {
      var found = findFirstKeyRecursive(child, keyNames, maxDepth - 1);
      if (found !== null && found !== undefined && found !== '') {
        return found;
      }
    }
  }

  return null;
}

function parseAccountFromArn(value) {
  if (!value) {
    return null;
  }
  var text = String(value);
  var match = text.match(/^arn:aws[a-zA-Z-]*:iam::([0-9]{12}):/);
  return match ? match[1] : null;
}

function extractAwsAccountId(integration) {
  var direct = findFirstKeyRecursive(
    integration,
    ['awsAccountId', 'accountId', 'accountID', 'account'],
    3
  );

  if (direct !== null && direct !== undefined && direct !== '') {
    return asString(direct, 'unknown');
  }

  var roleArn = findFirstKeyRecursive(
    integration,
    ['roleArn', 'roleARN', 'awsRoleArn', 'awsRoleARN'],
    5
  );

  var accountFromArn = parseAccountFromArn(roleArn);
  if (accountFromArn) {
    return accountFromArn;
  }

  return 'unknown';
}

function normalizeIntegrationList(parsed) {
  if (Array.isArray(parsed)) {
    return parsed;
  }
  if (parsed && Array.isArray(parsed.integrations)) {
    return parsed.integrations;
  }
  if (parsed && Array.isArray(parsed.results)) {
    return parsed.results;
  }
  if (parsed && Array.isArray(parsed.data)) {
    return parsed.data;
  }
  if (parsed && parsed.rs && Array.isArray(parsed.rs)) {
    return parsed.rs;
  }
  return [];
}

function isAwsIntegration(integration) {
  var typeValue = asString(integration.type, '').toLowerCase();
  var nameValue = asString(integration.name, '').toLowerCase();

  if (typeValue.indexOf('aws') >= 0) {
    return true;
  }

  if (typeValue === 'awscloudwatch') {
    return true;
  }

  if (nameValue.indexOf('aws') >= 0 && typeValue.indexOf('cloud') >= 0) {
    return true;
  }

  return false;
}

function enabledValue(integration) {
  if (Object.prototype.hasOwnProperty.call(integration, 'enabled')) {
    return integration.enabled === false ? 0 : 1;
  }

  /*
    If the API response omits enabled, do not emit custom.aws.integration.enabled.
    The inventory.present metric is still emitted so you can confirm the poller saw
    the integration.
  */
  return null;
}

var source = 'synthetic-aws-integration-health';

/*
  In Splunk Synthetics V2, `custom.<name>` is injected by the runtime as a
  read-only object containing any custom variables saved by prior setup steps.
  Reading it works. Writing to it (`custom.x = ...`) throws TypeError and
  crashes the step. To save this step's output, set `variable = "metricPayload"`
  on the JavaScript setup step in Terraform and let the V8 runtime save the
  final returned expression.
*/

if (typeof custom === 'undefined' || custom === null) {
  throw new Error('custom namespace is not defined; verify this JS step runs inside a Splunk Synthetics API check V2');
}

var raw = custom.integrationsResponse;
if (raw === undefined || raw === null || raw === '') {
  throw new Error('custom.integrationsResponse is empty; verify the prior save step ran and the GET /v2/integration request returned a body');
}

var parsed;
try {
  parsed = JSON.parse(raw);
} catch (parseErr) {
  throw new Error('Failed to JSON.parse custom.integrationsResponse: ' + parseErr.message);
}

var integrations = normalizeIntegrationList(parsed);
var gauge = [];

for (var i = 0; i < integrations.length; i++) {
  var integration = integrations[i];

  if (!integration || !isAwsIntegration(integration)) {
    continue;
  }

  var integrationId = asString(integration.id || integration.integrationId, 'unknown');

  if (integrationId === 'unknown') {
    continue;
  }

  var integrationName = asString(integration.name, 'unknown');
  var awsAccountId = extractAwsAccountId(integration);
  var primaryId = integrationId;
  var primaryIdType = 'integrationId';

  var commonDimensions = {
    'primaryId': primaryId,
    'primaryIdType': primaryIdType,
    'integrationId': integrationId,
    'integrationName': integrationName,
    'awsAccountId': awsAccountId,
    'source': source
  };

  gauge.push({
    'metric': 'custom.aws.integration.inventory.present',
    'dimensions': commonDimensions,
    'value': 1
  });

  var enabled = enabledValue(integration);
  if (enabled !== null) {
    gauge.push({
      'metric': 'custom.aws.integration.enabled',
      'dimensions': commonDimensions,
      'value': enabled
    });
  }
}

var metricPayload = JSON.stringify({
  'gauge': gauge
});

// Final expression — captured by the setup step's `variable = "metricPayload"`
// and exposed to subsequent requests as {{custom.metricPayload}}.
metricPayload;

