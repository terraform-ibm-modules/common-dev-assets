#!/usr/bin/env bash
set -eu pipefail

# Setup environment variables and git authentication for CI pipelines

REPO_OWNER="${TRIGGERED_BY:-}"
REPO_NAME="${TRIGGER_NAME:-}"
GIT_TOKEN="$(get_env git-token "")"

# Configure Git authentication
if [[ -n "$GIT_TOKEN" ]]; then
  git config --global url."https://$GIT_TOKEN@github.ibm.com/".insteadOf "https://github.ibm.com/"
fi

# Get PR commit SHA
COMMIT_SHA="$(get_env COMMIT_SHA "")"
echo "commit - $COMMIT_SHA"

if [[ -z "$COMMIT_SHA" ]]; then
  PRS_JSON=$(curl -s -H "Authorization: token $GIT_TOKEN" -H "Accept: application/vnd.github+json" \
    "https://github.ibm.com/api/v3/repos/$REPO_OWNER/$REPO_NAME/pulls?state=open")
  COMMIT_SHA=$(echo "$PRS_JSON" | jq -r '.[0].head.sha')
  PR_NUMBER=$(echo "$PRS_JSON" | jq -r '.[0].number')
  echo "Using PR #$PR_NUMBER commit SHA: $COMMIT_SHA"
fi

# Export Artifactory credentials if present
ARTIFACTORY_USERNAME="$(get_env ARTIFACTORY_USERNAME "")"
export ARTIFACTORY_USERNAME
ARTIFACTORY_PASSWORD="$(get_env ARTIFACTORY_PASSWORD "")"  # pragma: allowlist secret
export ARTIFACTORY_PASSWORD

# Source report.sh and post pending status
source "$(dirname "${BASH_SOURCE[0]}")/report.sh"
report_status pending "Build started"
