#!/usr/bin/env bash
set -euo pipefail

# Setup environment variables and git authentication for CI pipelines

REPO_OWNER="GoldenEye"
# Use custom repo-name environment variable (no default - must be set)
REPO_NAME="$(get_env repo-name "")"
echo "Using REPO_NAME: $REPO_NAME"

# Get the actual PR commit SHA (not master head)
# GIT_COMMIT points to master head, so we need to get the PR head SHA instead
GIT_COMMIT_MASTER="$(get_env GIT_COMMIT "")"
echo "GIT_COMMIT (from env): $GIT_COMMIT_MASTER"

# Get PR commit SHA from GitHub API (this is the actual commit we want to report status on)
PRS_JSON=$(curl -s -H "Authorization: token $GIT_TOKEN" -H "Accept: application/vnd.github+json" \
  "https://github.ibm.com/api/v3/repos/$REPO_OWNER/$REPO_NAME/pulls?state=open")
COMMIT_SHA=$(echo "$PRS_JSON" | jq -r '.[0].head.sha')
PR_NUMBER=$(echo "$PRS_JSON" | jq -r '.[0].number')
echo "PR #$PR_NUMBER head commit: $COMMIT_SHA"

# Compare the two
if [[ "$GIT_COMMIT_MASTER" == "$COMMIT_SHA" ]]; then
  echo "✅ GIT_COMMIT and PR head match - using GIT_COMMIT"
  COMMIT_SHA="$GIT_COMMIT_MASTER"
else
  echo "⚠️  GIT_COMMIT ($GIT_COMMIT_MASTER) != PR head ($COMMIT_SHA)"
  echo "Using PR head commit for status reporting"
fi

export COMMIT_SHA
export REPO_OWNER
export REPO_NAME

# Source report.sh and post pending status
source "$(dirname "${BASH_SOURCE[0]}")/report.sh"
report_status pending "Build started"
