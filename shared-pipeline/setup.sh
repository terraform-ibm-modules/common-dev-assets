#!/usr/bin/env bash
set -euo pipefail

# Setup environment variables and git authentication for CI pipelines

REPO_OWNER="GoldenEye"
REPO_NAME="${TRIGGER_NAME:-}"

# Get PR commit SHA from GIT_COMMIT environment variable
COMMIT_SHA="$(get_env GIT_COMMIT "")"
echo "commit - $COMMIT_SHA"

if [[ -z "$COMMIT_SHA" ]]; then
  PRS_JSON=$(curl -s -H "Authorization: token $GIT_TOKEN" -H "Accept: application/vnd.github+json" \
    "https://github.ibm.com/api/v3/repos/$REPO_OWNER/$REPO_NAME/pulls?state=open")
  COMMIT_SHA=$(echo "$PRS_JSON" | jq -r '.[0].head.sha')
  PR_NUMBER=$(echo "$PRS_JSON" | jq -r '.[0].number')
  echo "Using PR #$PR_NUMBER commit SHA: $COMMIT_SHA"
fi

export COMMIT_SHA
export REPO_OWNER
export REPO_NAME

# Source report.sh and post pending status
source "$(dirname "${BASH_SOURCE[0]}")/report.sh"
report_status pending "Build started"
