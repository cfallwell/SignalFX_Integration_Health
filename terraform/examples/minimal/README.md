# Minimal Example

This directory contains a minimal working example of the AWS integration health Terraform deployment.

## Structure

```
minimal/
├── README.md                    # This file
├── main.tf                      # Module instantiation
├── variables.tf                 # Input variables and locals
├── versions.tf                  # Provider versions
└── terraform.tfvars.example     # Example configuration (rename to terraform.tfvars)
```

## Quick Start

1. Copy `terraform.tfvars.example` to `terraform.tfvars`:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your actual values:

   ```hcl
   realm              = "us0"
   auth_token         = "your-token"
   o11y_api_token     = "your-token"
   o11y_ingest_token  = "your-token"
   ```

3. Initialize Terraform:

   ```bash
   terraform init
   ```

4. Review the plan:

   ```bash
   terraform plan
   ```

5. Apply the configuration:

   ```bash
   terraform apply
   ```

## Configuration

### Required Variables

- `realm`: Your Splunk Observability Cloud realm (e.g., `us0`, `us1`, `eu0`)
- `auth_token`: API token with detector-creation permissions
- `o11y_api_token`: API token for reading integrations
- `o11y_ingest_token`: Ingest token for posting datapoints

### Optional Variables

- `rule_notifications`: Map of rule labels to notification recipients (default: empty, no notifications)
- `enable_synthetics`: Enable/disable the Synthetics API test (default: `true`)

## Tokens

For security, use environment variables instead of committing tokens to `terraform.tfvars`:

```bash
export TF_VAR_realm="us0"
export TF_VAR_auth_token="..."
export TF_VAR_o11y_api_token="..."
export TF_VAR_o11y_ingest_token="..."

terraform plan
terraform apply
```

Or use a secure secrets management tool (e.g., HashiCorp Vault, AWS Secrets Manager).

## Notifications

To receive alerts, configure notification recipients in `terraform.tfvars`:

```hcl
rule_notifications = {
  "AWS integration auth failure" = [
    "Email,sre@example.com",
    "Slack,#aws-alerts"
  ]
  "AWS integration disabled" = [
    "Email,sre@example.com"
  ]
  # ... other rules ...
}
```

Leave a rule's list empty (`[]`) to disable notifications for that rule.

## Outputs

After applying, Terraform outputs:

- `detector_id`: The ID of the created detector
- `detector_url`: The URL to the detector in the Splunk Observability Cloud UI
- `synthetics_test_id`: The ID of the Synthetics API test (if enabled)

## Next Steps

- See `../../README.md` for full documentation on the deployment
- See `../../modules/detector/README.md` for detector module details
- See `../../modules/synthetics_api_test/README.md` for Synthetics module details

## Troubleshooting

### "Invalid API URL" error

Check that your `realm` is correct (e.g., `us0`, not `US0` or `us-0`).

### Authentication errors

Verify your tokens are valid and have the correct permissions:

- `auth_token`: Must have detector-creation permission
- `o11y_api_token`: Must have read access to `/v2/integration`
- `o11y_ingest_token`: Must have write access to `/v2/datapoint`

### Synthetics test not running

- Confirm `enable_synthetics = true` in your variables
- Check that the test appears in the Synthetics UI with a green status
- Verify the test has run at least once (check the test history)

## File Paths

This example uses relative paths (`../../modules/`, `../../detectors/`, `../../synthetics/`) that are correct when you run Terraform from this directory.

If you copy this example to a different location, adjust the paths in `main.tf` accordingly.

## Example Usage: Production Deployment

For a production deployment with remote state:

```bash
# Initialize with S3 backend
terraform init -backend-config="bucket=my-state-bucket" \
               -backend-config="key=aws-integration-health/terraform.tfstate" \
               -backend-config="region=us-east-1"

# Plan and apply
terraform plan -out=tfplan
terraform apply tfplan
```

Update `main.tf` to include a backend block:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-state-bucket"
    key            = "aws-integration-health/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```
