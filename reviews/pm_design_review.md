# PM Design Review: AWS Integration Health Terraform

**Date:** 2026-06-22  
**Reviewer Role:** Product Manager  
**Scope:** Design validation of Terraform implementation against project plan and customer requirements

---

## Verdict summary

| # | Area | Verdict |
| - | ---- | ------- |
| 1 | Alert rule coverage | PASS |
| 2 | Severity assignment matches plan | PASS |
| 3 | Identifier standard preserved | PASS |
| 4 | Synthetics vs poller choice | PASS |
| 5 | Tokens, scopes, and security posture | PASS |
| 6 | Customer override surface | PASS |
| 7 | Deployment story / docs | PASS |
| 8 | Known-limitations are still documented | PASS |
| 9 | Operational handoff | GAP |
| 10 | Things outside scope that should still be acknowledged | GAP |

---

## Findings

### 1. Alert rule coverage — PASS

All five alert rules from the project plan are configured and wired correctly:

1. **AWS integration auth failure** (rule label: `AWS integration auth failure`)
   - Sourced from native metric `sf.org.num.awsServiceAuthErrorCount`
   - Rule defined in `/terraform/modules/detector/main.tf`, lines 16-28
   - Detect label matches SignalFlow output exactly: `AWS integration auth failure`

2. **AWS integration disabled** (rule label: `AWS integration disabled`)
   - Sourced from custom metric `custom.aws.integration.enabled`
   - Rule defined in lines 31-43
   - Detect label matches: `AWS integration disabled`

3. **AWS integration stale / no datapoints** (rule label: `AWS integration stale / no datapoints`)
   - Sourced from native metric `sf.org.datainventory.latestTimestamp`
   - Rule defined in lines 46-58
   - Detect label matches: `AWS integration stale / no datapoints`

4. **AWS API exceptions - org scoped** (rule label: `AWS API exceptions - org scoped`)
   - Sourced from native metric `sf.org.num.awsServiceCallCountExceptions`
   - Rule defined in lines 61-73
   - Detect label matches: `AWS API exceptions - org scoped`

5. **Logs stopped by token** (rule label: `Logs stopped by token`)
   - Sourced from native metric `sf.org.log.grossMessagesReceivedByToken`
   - Rule defined in lines 76-88
   - Detect label matches: `Logs stopped by token`

Each rule uses the `lookup()` function to fetch notifications from `var.rule_notifications`, defaulting to an empty list if not specified. The Synthetics module correctly bridges custom metrics from the JavaScript payload builder to the detector.

### 2. Severity assignment matches plan — PASS

Severity defaults are specified in `/terraform/locals.tf`, lines 221-228:

```hcl
default_severities = {
  "AWS integration auth failure"           = "Critical"
  "AWS integration disabled"               = "Critical"
  "AWS integration stale / no datapoints"  = "Major"
  "AWS API exceptions - org scoped"        = "Major"
  "Logs stopped by token"                  = "Major"
}
```

These exactly match the suggested severities from `project_plan.md`, Phase 3, lines 113-120. The implementation allows customer override via `var.rule_severity_overrides` (see `/terraform/variables.tf`, lines 99-109), which merges overrides with defaults in `locals.tf`, lines 231-234. This gives customers full control without breaking the recommended defaults.

The detector module variable `var.rule_severities` receives the merged severities and applies them to each rule (lines 18, 33, 48, 63, 78 in `/terraform/modules/detector/main.tf`).

### 3. Identifier standard preserved — PASS

All required identifier fields are preserved through the message templates and metric flow:

**In custom metrics (Synthetics/poller output):**
- `primaryId` = `integrationId` (standard identifier for alerts, defined in `/synthetics/build_metric_payload.js`, line 168)
- `primaryIdType` = `"integrationId"` (line 169)
- `integrationId` = actual AWS integration ID from API (line 160)
- `integrationName` = AWS integration name or "unknown" (line 166)
- `awsAccountId` = extracted from integration response or ARN (line 167)
- `source` = `"synthetic-aws-integration-health"` (line 147)

These dimensions are included in `commonDimensions` (lines 171-178) and attached to all custom metric datapoints.

**In message templates:**
- "AWS integration auth failure" template uses `{{dimensions.integrationId}}`
- "AWS integration disabled" template uses `{{dimensions.primaryId}}` (primary identifier) plus `{{dimensions.integrationId}}`, `{{dimensions.integrationName}}`, `{{dimensions.awsAccountId}}`
- "AWS integration stale / no datapoints" template uses `{{dimensions.integrationId}}`
- "AWS API exceptions - org scoped" template correctly documents that `integrationId` is NOT available (lines 219-220 in `/detector_messages/all_message_templates.md`)
- "Logs stopped by token" template uses `{{dimensions.tokenId}}` (fallback when integration ID unavailable, lines 271-272)

These match exactly the identifier strategy laid out in `project_plan.md`, lines 35-47 (Identifier standard table) and are preserved in the Terraform locals (see `/terraform/locals.tf`, which contains the same message templates).

### 4. Synthetics vs poller choice — PASS

The Terraform makes Synthetics the default and clearly documents the poller as an alternative.

**Synthetics is the default:**
- `/terraform/variables.tf`, line 111-114: `var.enable_synthetics` defaults to `true`
- `/terraform/main.tf`, line 19-32: Synthetics module is instantiated conditionally on `var.enable_synthetics ? 1 : 0`
- `/terraform/README.md`, "Deployment Options" section (lines 252-289) documents both options clearly:
  - Option 1 (default) uses Synthetics with pros/cons
  - Option 2 offers the external poller with instructions
- The example minimal config (`/terraform/examples/minimal/terraform.tfvars.example`, line 45) sets `enable_synthetics = true` by default

**Poller is preserved and accessible:**
- The poller code at `/poller/aws_integration_health_poller.py` is NOT deleted and remains fully functional
- Instructions for using the poller are in:
  - `/terraform/README.md`, lines 269-289 (Option 2: External Python Poller)
  - `/README.md`, lines 109-122 (Option C: External poller)
  - The root `/terraform/README.md` shows how to set `enable_synthetics = false` and deploy the poller on a schedule

The implementation correctly treats Synthetics as the recommended path (Option A per project_plan.md Phase 2) while preserving the external poller (Option B) as a fully supported alternative.

### 5. Tokens, scopes, and security posture — PASS

**Separate tokens for API and ingest:**
- `/terraform/variables.tf` defines three separate token variables:
  - Line 11-15: `var.auth_token` (sensitive=true) for detector creation
  - Line 17-21: `var.o11y_api_token` (sensitive=true) for API read access (Synthetics/poller)
  - Line 23-27: `var.o11y_ingest_token` (sensitive=true) for ingest write access (Synthetics/poller)

**Token scope documentation:**
- `/terraform/README.md`, "Token Management" section (lines 186-231) explains each token's minimum privileges:
  - API Token: scope `ingest` for reading `/v2/integration`
  - Ingest Token: scope `ingest` for writing to `/v2/datapoint`
  - Detector Auth Token: scope `admin` for detector creation
  
(Note: The README uses scope names "ingest" for read and "ingest" for write, which may be worth validating against actual Splunk Observability Cloud token scopes, but the documentation is at least explicit and customers can adjust based on their realm.)

**Token security:**
- All three tokens are marked `sensitive = true` in variable definitions
- The README strongly discourages putting tokens in `terraform.tfvars` (lines 219-231)
- Recommended approach is environment variables: `export TF_VAR_realm=...`, etc. (lines 224-231)
- No tokens appear in outputs (checked `/terraform/outputs.tf` and `/terraform/modules/detector/outputs.tf` — no sensitive data exported)
- Synthetics module does NOT output tokens; only test metadata (lines 1-14 in `/terraform/modules/synthetics_api_test/outputs.tf`)

**Token usage in Synthetics:**
- Tokens are passed to the Synthetics module in `/terraform/main.tf`, lines 25-26
- Synthetics module receives them as sensitive variables (lines 13-22 in `/terraform/modules/synthetics_api_test/variables.tf`)
- Tokens are used in API request headers in `/terraform/modules/synthetics_api_test/main.tf`:
  - Line 19: API token in `GET /v2/integration` headers
  - Line 48: Ingest token in `POST /v2/datapoint` headers
- These are embedded in the Synthetics test configuration, which is created in the Splunk platform (not output or exposed in logs)

### 6. Customer override surface — PASS

All required override points are configurable variables with sensible defaults:

**Realm and tokens:**
- `var.realm` (required, no default, validated to regex `^[a-z]{2}[0-9]+$` for safety)
- `var.auth_token`, `var.o11y_api_token`, `var.o11y_ingest_token` (required, sensitive)

**Detector name and metadata:**
- `var.detector_name` (default: `"AWS integration health"`)
- `var.detector_description` (default provided, lines 35-39 in `/terraform/variables.tf`)
- `var.detector_tags` (default: `[]`)
- `var.detector_teams`, `var.detector_authorized_writer_teams`, `var.detector_authorized_writer_users` (all default to `[]`)

**Detector timing:**
- `var.detector_time_zone` (default: `"UTC"`)
- `var.detector_max_delay` (default: 900 seconds = 15 minutes; project plan recommends 10-15 minutes)
- `var.detector_min_delay` (default: `null`)

**Alert rules:**
- `var.rule_notifications` (map of rule label to notification recipients; default: empty lists for all rules)
- `var.rule_severity_overrides` (map of rule label to severity; defaults provided, can be overridden per rule)

**Synthetics:**
- `var.enable_synthetics` (default: `true`; set to false to use external poller)
- `var.synthetics_test_name` (default: `"AWS integration health - Synthetic API test"`)
- `var.synthetics_frequency_minutes` (default: `5`, validated 1-1440)
- `var.synthetics_locations` (default: `["aws-us-east-1"]`)
- `var.synthetics_enabled` (default: `true`)
- `var.synthetics_tags` (default: `[]`)

All overridable points are documented in `/terraform/README.md`, "Configuration Guide" section (lines 88-131), with clear tables and examples.

### 7. Deployment story / docs — PASS

**Top-level README points to Terraform:**
- `/README.md`, lines 73-96 clearly labels Terraform as the recommended path (Option A)
- Links to `terraform/README.md` with instructions

**Terraform README covers all prerequisites:**
- `/terraform/README.md`, "Prerequisites" section (lines 21-30) lists required Splunk account setup, realm, tokens, and Terraform version
- "Provider Versions" section (lines 33-38) pins versions for reproducibility
- "Token Management" section (lines 186-231) explains how to create tokens with minimum privilege

**Flow documentation:**
- "Quick Start" section (lines 40-86) walks through `terraform init`, `terraform.tfvars`, `terraform plan`, `terraform apply`
- "Configuration Guide" section (lines 88-131) documents all variables with defaults
- "Notification Recipients" section (lines 133-160) shows the format for per-rule notification routing
- "Severity Levels" section (lines 162-184) explains how to override severities

**Minimal example:**
- `/terraform/examples/minimal/` provides a working example with:
  - `main.tf`: instantiates the detector and (optionally) Synthetics modules
  - `variables.tf`: defines required and optional inputs, includes locals with message templates
  - `terraform.tfvars.example`: populated with comments explaining each variable
  - `README.md`: guides through copy-paste, init, plan, apply flow
- The example uses relative paths (`../../modules/`, `../../detectors/`) that work when running `terraform` from the `examples/minimal/` directory
- This is a complete, minimal end-to-end example that requires only filling in three token values

**Upgrade story:**
- `/terraform/README.md`, "Upgrading" section (lines 291-299) explains that customers can update `terraform.tfvars` and re-run `terraform apply` to take new detector messages or provider versions
- Terraform handles updates to detector rules, message templates, and Synthetics test configuration automatically

### 8. Known-limitations are still documented — PASS

All five known limitations from `project_plan.md`, lines 159-165 are referenced or clearly explained in the Terraform docs without contradiction:

1. **API exception metric has no `integrationId`:**
   - Project plan, line 161: "`sf.org.num.awsServiceCallCountExceptions` does not provide `integrationId`..."
   - Terraform detector message (locals.tf, lines 154-155): "This native org metric does not include integrationId or tokenId. This alert is scoped to the organization, AWS namespace, API method, and exception location..."
   - Detector_messages/all_message_templates.md, lines 219-220: same explanation
   - PASS: No contradiction; limitation is explained in message template so customer understands scope

2. **Logs metric is token-scoped:**
   - Project plan, line 162: "`sf.org.log.grossMessagesReceivedByToken` is token-scoped, not integration-scoped."
   - Terraform detector message (locals.tf, lines 196 and 277): explains tokenId is the fallback when integrationId unavailable
   - Detector_messages/all_message_templates.md, lines 276-277: same
   - PASS: Limitation is documented in message template

3. **Disabled-state accuracy depends on API:**
   - Project plan, line 163: "Disabled-state accuracy depends on whether the Integrations API response reliably exposes `enabled`..."
   - Terraform build_metric_payload.js, lines 134-145: checks for `enabled` field and returns `null` if absent (does not emit metric)
   - PASS: Logic matches plan's handling

4. **If API always returns `enabled: true`:**
   - Project plan, lines 164: "If the API response always returns `enabled: true`, use the custom inventory metric for enrichment..."
   - Terraform build_metric_payload.js, line 181: emits both `custom.aws.integration.enabled` (if enabled field exists) and `custom.aws.integration.inventory.present` (always)
   - PASS: Code allows for this scenario

5. **No static token list:**
   - Project plan, line 165: detector cannot infer a token that was expected but never emitted
   - Terraform detector (SignalFlow, line 247-262): uses `sf.org.log.grossMessagesReceivedByToken` directly without filtering
   - This is a measurement limitation, not a Terraform limitation; Terraform docs do not claim to solve it
   - PASS: Not hidden or contradicted

### 9. Operational handoff — GAP

**Issue:** Project plan Phase 5, item 5 (line 156) states: "Monitor the Synthetics API test or external poller separately so stale custom state does not hide poller failures."

This is NOT mentioned or called out in the Terraform documentation or examples.

**Why it matters:** If the Synthetics test or poller crashes or stops running, the detector will continue to alert based on the last received custom metric values (because of `extrapolation='last_value'` in the SignalFlow, line 123 of the detector). The customer needs to know they should monitor the health of the producer itself.

**What's missing:**
- No mention in `/terraform/README.md` of how to monitor Synthetics test health (check test history, status, last run time)
- No suggestion to create a separate detector or alert on Synthetics test failures
- No guidance on what to do if the Synthetics test is disabled or failing

**Recommendation:** Add a "Production Hardening" or "Monitoring the Producer" section to `/terraform/README.md` that explains:
- How to check Synthetics test status in the UI (test history, last run timestamp)
- Optional: create a companion detector to alert if Synthetics test fails or stops running
- For external poller: set up CloudWatch alarms or equivalent for Lambda / Kubernetes job failures

### 10. Things outside scope that should still be acknowledged — GAP

**Issue:** Project plan "Production follow-ups" section (lines 167-172) lists four items that are acknowledged as out-of-scope for Phase 1-5, but which should be mentioned in the Terraform docs as "next steps" or future considerations.

1. **Runbook for token-to-AWS-account mapping:**
   - Project plan, line 168: "Add a runbook that maps token IDs to AWS log forwarding paths if token ID is the only available log identifier."
   - NOT mentioned in `/terraform/README.md` or example docs
   - Relevant for customers deploying Option A (Synthetics) who rely on "Logs stopped by token" rule

2. **Account aliases as dimensions:**
   - Project plan, line 169: "Add account aliases as custom properties or dimensions if the integration response does not include them."
   - NOT mentioned in Terraform docs
   - Would enhance alert readability by including human-friendly AWS account names

3. **Per-integration validate endpoint:**
   - Project plan, line 170: "Consider a wrapper service if you need per-integration validation fan-out using `/v2/integration/validate/{id}`..."
   - NOT mentioned in Terraform docs
   - Current approach only checks the integration enabled/disabled state, not full health

4. **Self-monitoring of custom-metric producer:**
   - Project plan, line 171: "Add a synthetic or detector for the custom metric producer itself."
   - This is partly covered (GAP 9 above), but not the complete picture

**Why it matters:** Customers reading the Terraform docs may think the deployment is "done" without being aware of these production-hardening tasks. The project plan explicitly flags them as follow-up work, but they disappear from the Terraform view.

**Recommendation:** Add a "Production Follow-ups and Enhancements" section to `/terraform/README.md` (or `/terraform/modules/README.md`) that lists these four items and explains why they might be relevant for a production deployment. This sets customer expectations and provides a roadmap for future work.

---

## Prioritized recommendations

### P0 (Blocking)
None. The design is sound and all critical paths are covered.

### P1 (High priority)
1. **Add "Monitoring the Producer" section to terraform/README.md** (addresses GAP 9)
   - Explain that the Synthetics test or poller must be monitored separately
   - Show how to check Synthetics test status in the UI
   - Suggest creating a companion detector for Synthetics test failures
   - Link to the external poller documentation for Lambda/Kubernetes scheduling tips

### P2 (Medium priority)
1. **Add "Production Follow-ups" section to terraform/README.md** (addresses GAP 10)
   - List the four follow-up items from project_plan.md "Production follow-ups" section
   - Explain briefly why each is relevant (token mapping, account aliases, per-integration validation, self-monitoring)
   - Suggest that a production deployment should plan for these enhancements in Phase 6/beyond

2. **Verify token scopes with Splunk Observability Cloud API documentation**
   - The `/terraform/README.md` Token Management section (lines 186-231) uses generic scope names ("ingest" for both read and write)
   - Confirm these are correct for the actual Splunk Observability Cloud API
   - If scopes differ by realm or customer, add a note about validating against live documentation

---

## Sign-off

**Ready for QA: yes-with-fixes**

The Terraform implementation is well-structured, complete, and aligns with the project plan on all critical design points:

- All five alert rules are correctly wired to their detect labels and message templates
- Severity defaults match the plan; customer override is fully supported
- All required identifiers (primaryId, integrationId, integrationName, awsAccountId) are preserved through the signal flow
- Synthetics is the recommended default; external poller is preserved and documented as an alternative
- Tokens are handled securely (separate, sensitive, no leaks in outputs)
- Customer override surface is comprehensive and well-documented
- Deployment story is clear: README → Terraform README → Quick Start → Minimal example → terraform apply
- Known limitations are documented without contradiction
- Message templates and examples are production-ready

**Gaps identified are improvements, not blockers:**
- P1: Add guidance on monitoring Synthetics test / poller health (necessary for production-grade observability)
- P2: Add forward-looking section on production follow-ups (helpful roadmap but not blocking initial deployment)

**Next steps:**
1. Address P1 and P2 recommendations in terraform/README.md
2. Forward to QA agent for syntax, provider compatibility, and example validation
3. After QA sign-off, ready for customer delivery

