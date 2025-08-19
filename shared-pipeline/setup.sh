#!/usr/bin/env bash
set -euo pipefail

# Setup environment variables and git authentication for CI pipelines

REPO_OWNER="GoldenEye"
REPO_NAME="release-notes"

# Log potential environment variables for debugging
echo "=== ENVIRONMENT VARIABLE DEBUGGING ==="
echo "TRIGGER_NAME: ${TRIGGER_NAME:-NOT_SET}"
echo "TRIGGERED_BY: ${TRIGGERED_BY:-NOT_SET}"
echo "PIPELINE_RUN_NAME: ${PIPELINE_RUN_NAME:-NOT_SET}"
echo "PIPELINE_RUN_ID: ${PIPELINE_RUN_ID:-NOT_SET}"
echo "PIPELINE_RUN_URL: ${PIPELINE_RUN_URL:-NOT_SET}"
echo "GIT_URL: ${GIT_URL:-NOT_SET}"
echo "GIT_BRANCH: ${GIT_BRANCH:-NOT_SET}"
echo "GIT_COMMIT: ${GIT_COMMIT:-NOT_SET}"
echo "GIT_TOKEN: ${GIT_TOKEN:+SET}"
echo "REPO_URL: ${REPO_URL:-NOT_SET}"
echo "REPOSITORY_URL: ${REPOSITORY_URL:-NOT_SET}"
echo "SOURCE_REPOSITORY_URL: ${SOURCE_REPOSITORY_URL:-NOT_SET}"
echo "CI_REPOSITORY_URL: ${CI_REPOSITORY_URL:-NOT_SET}"
echo "GITHUB_REPOSITORY: ${GITHUB_REPOSITORY:-NOT_SET}"
echo "GITHUB_REF: ${GITHUB_REF:-NOT_SET}"
echo "GITHUB_SHA: ${GITHUB_SHA:-NOT_SET}"
echo "PR_NUMBER: ${PR_NUMBER:-NOT_SET}"
echo "PULL_REQUEST_NUMBER: ${PULL_REQUEST_NUMBER:-NOT_SET}"
echo "BUILD_NUMBER: ${BUILD_NUMBER:-NOT_SET}"
echo "BUILD_ID: ${BUILD_ID:-NOT_SET}"

# Check get_env function for various potential variables
echo "=== GET_ENV FUNCTION CHECKS ==="
echo "get_env TRIGGER_NAME: $(get_env TRIGGER_NAME "")"
echo "get_env TRIGGERED_BY: $(get_env TRIGGERED_BY "")"
echo "get_env REPO_NAME: $(get_env REPO_NAME "")"
echo "get_env REPOSITORY_NAME: $(get_env REPOSITORY_NAME "")"
echo "get_env GIT_REPO: $(get_env GIT_REPO "")"
echo "get_env SOURCE_REPO: $(get_env SOURCE_REPO "")"
echo "get_env PIPELINE_SOURCE_REPO: $(get_env PIPELINE_SOURCE_REPO "")"
echo "get_env TEKTON_REPO: $(get_env TEKTON_REPO "")"
echo "get_env WORKSPACE_NAME: $(get_env WORKSPACE_NAME "")"

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
