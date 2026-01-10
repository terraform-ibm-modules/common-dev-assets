# ICD Version Checker

A Go CLI tool for managing IBM Cloud Databases (ICD) version information in Terraform module repositories. It extracts and updates version configurations across multiple files: `variables.tf`, `ibm_catalog.json`, and `tests/pr_test.go`.

## Supported Services

- postgresql
- mysql
- mongodb
- redis
- elasticsearch
- rabbitmq
- etcd
- enterprisedb

## Installation

### From Source

```bash
go install github.com/terraform-ibm-modules/common-dev-assets/scripts/icd-version-checker@latest
```

### Build Locally

```bash
cd common-dev-assets/scripts/icd-version-checker
go build -o icd-version-checker .
```

## Running Locally

### Prerequisites

- Go 1.21 or later
- For the `sync` command: an IBM Cloud API key with access to the Databases API

### Environment Variables

| Variable | Description |
|----------|-------------|
| `IBMCLOUD_API_KEY` | IBM Cloud API key for fetching versions from the API (primary) |
| `TF_VAR_ibmcloud_api_key` | IBM Cloud API key (fallback if IBMCLOUD_API_KEY not set) |

## Commands

### extract

Extracts current version information from repository files.

```bash
icd-version-checker extract --service-type <service> --repo-root <path>
```

**Flags:**
- `--service-type` (required): ICD service type (e.g., postgresql, mysql, redis)
- `--repo-root` (required): Path to the repository root

**Example:**

```bash
icd-version-checker extract --service-type postgresql --repo-root /path/to/terraform-ibm-icd-postgresql
```

**Output (JSON):**

```json
{
  "service_type": "postgresql",
  "variable_name": "postgresql_version",
  "variables_tf": {
    "versions": ["15", "16", "17"],
    "latest_version": "17"
  },
  "ibm_catalog": {
    "versions": ["15", "16", "17"],
    "latest_version": "17"
  },
  "test_file": {
    "versions": ["17"],
    "latest_version": "17"
  }
}
```

### fetch

Fetches available versions from the IBM Cloud Databases API.

```bash
icd-version-checker fetch --service-type <service> [--ibmcloud-api-key <key>]
```

**Flags:**
- `--service-type` (required): ICD service type (e.g., postgresql, mysql, redis)
- `--ibmcloud-api-key`: IBM Cloud API key (or set `IBMCLOUD_API_KEY`/`TF_VAR_ibmcloud_api_key` env var)

**Example:**

```bash
export IBMCLOUD_API_KEY="your-api-key"
icd-version-checker fetch --service-type postgresql
```

**Output (JSON):**

```json
{
  "service_type": "postgresql",
  "variable_name": "postgresql_version",
  "versions": ["15", "16", "17", "18"],
  "latest_version": "18"
}
```

### update

Updates version information in repository files.

```bash
icd-version-checker update --service-type <service> --repo-root <path> --versions <versions> [--latest <version>]
```

**Flags:**
- `--service-type` (required): ICD service type
- `--repo-root` (required): Path to the repository root
- `--versions` (required): Comma-separated list of versions (e.g., "15,16,17,18")
- `--latest` (optional): The latest version (defaults to highest version in the list)

**Example:**

```bash
# Latest version auto-detected from list (18)
icd-version-checker update --service-type postgresql --repo-root . --versions "15,16,17,18"

# Or explicitly specify latest
icd-version-checker update --service-type postgresql --repo-root . --versions "15,16,17,18" --latest 18
```

**Output (JSON):**

```json
{
  "updated_files": ["variables.tf", "ibm_catalog.json", "tests/pr_test.go"]
}
```

### sync

Combines `fetch`, `extract`, and `update` into a single command. This is the primary command used in CI/CD workflows.

The sync command:
1. Fetches available versions from IBM Cloud API (`fetch`)
2. Extracts current versions from repository files (`extract`)
3. Compares versions to detect changes
4. Updates files if new versions are available (`update`)

```bash
icd-version-checker sync --service-type <service> --repo-root <path> [--dry-run] [--ibmcloud-api-key <key>]
```

**Flags:**
- `--service-type` (required): ICD service type
- `--repo-root` (required): Path to the repository root
- `--dry-run`: Show what would change without modifying files
- `--ibmcloud-api-key`: IBM Cloud API key (or set `IBMCLOUD_API_KEY`/`TF_VAR_ibmcloud_api_key` env var)

**Example:**

```bash
# Dry run to see what would change
export IBMCLOUD_API_KEY="your-api-key"
icd-version-checker sync --service-type postgresql --repo-root . --dry-run

# Actually update files
icd-version-checker sync --service-type postgresql --repo-root .
```

**Output (JSON):**

```json
{
  "service_type": "postgresql",
  "current_versions": ["15", "16", "17"],
  "current_latest": "17",
  "api_versions": ["15", "16", "17", "18"],
  "api_latest": "18",
  "new_versions": ["18"],
  "deprecated_versions": [],
  "has_changes": true,
  "updated_files": ["variables.tf", "ibm_catalog.json", "tests/pr_test.go"],
  "dry_run": false
}
```

## Files Modified

The tool updates version information in the following files:

### variables.tf

Updates the version validation block:

```hcl
variable "postgresql_version" {
  validation {
    condition = anytrue([
      var.postgresql_version == null,
      var.postgresql_version == "18",
      var.postgresql_version == "17",
      var.postgresql_version == "16",
      var.postgresql_version == "15",
    ])
    error_message = "Version must be 15, 16, 17 or 18."
  }
}
```

### ibm_catalog.json

Updates the version configuration options:

```json
{
  "key": "postgresql_version",
  "default_value": "17",
  "options": [
    {"displayname": "15", "value": "15"},
    {"displayname": "16", "value": "16"},
    {"displayname": "17", "value": "17"},
    {"displayname": "18", "value": "18"}
  ]
}
```

Note: For single-version services (like Redis) that only have a `default_value` without an `options` array, the parser uses the `default_value` as the sole version.

### tests/pr_test.go

Updates the `latestVersion` constant:

```go
const latestVersion = "18"
```

Note: When extracting versions, the parser first looks for a `const latestVersion` declaration. If not found, it falls back to searching for `"<service>_version": "<version>"` patterns in the test file (e.g., `"edb_version": "12"`).

## Development

### Running Tests

```bash
cd common-dev-assets/scripts/icd-version-checker
go test ./...
```

### Running Tests with Verbose Output

```bash
go test ./... -v
```

### Project Structure

```
icd-version-checker/
├── main.go                    # CLI entry point
├── cmd/
│   ├── root.go                # Root command setup
│   ├── extract.go             # Extract subcommand
│   ├── update.go              # Update subcommand
│   └── sync.go                # Sync subcommand
├── internal/
│   ├── types/
│   │   └── types.go           # Shared types and service configs
│   ├── parser/
│   │   ├── hcl.go             # HCL parser for variables.tf
│   │   ├── catalog.go         # JSON parser for ibm_catalog.json
│   │   └── gotest.go          # Go file parser for pr_test.go
│   ├── updater/
│   │   ├── hcl.go             # HCL updater for variables.tf
│   │   ├── catalog.go         # JSON updater for ibm_catalog.json
│   │   └── gotest.go          # Go file updater for pr_test.go
│   └── ibmcloud/
│       └── client.go          # IBM Cloud API client
└── testdata/                  # Test fixtures
```

## CI/CD Integration

This tool is designed to be used with the reusable workflow `icd-version-update.yml`. See the workflow file for integration details.

Example workflow usage:

```yaml
jobs:
  check-versions:
    uses: terraform-ibm-modules/common-pipeline-assets/.github/workflows/icd-version-update.yml@main
    with:
      icd_service_type: 'postgresql'
    secrets:
      IBMCLOUD_API_KEY: ${{ secrets.IBMCLOUD_API_KEY }}
```
