#!/usr/bin/env bash
# Note: Intentionally not using 'set -eu' to be more resilient when sourced

# Usage: source this script at the end of your pipeline script
# It will report success or failure to GitHub depending on the exit status

function report_status {
  local status=$1
  local description=$2

  # Check if required variables are set (without failing due to set -u)
  if [[ -n "${GIT_TOKEN:-}" && -n "${COMMIT_SHA:-}" && -n "${REPO_OWNER:-}" && -n "${REPO_NAME:-}" ]]; then
    echo "Reporting status: $status - $description"
    curl -s -X POST \
      -H "Authorization: token $GIT_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" \
      "https://github.ibm.com/api/v3/repos/$REPO_OWNER/$REPO_NAME/statuses/$COMMIT_SHA" \
      -d "{\"state\": \"$status\", \"target_url\": \"${PIPELINE_RUN_URL:-}\", \"context\": \"continuous-integration/simple-pipeline\", \"description\": \"$description\"}" \
      || echo "Warning: Failed to report status to GitHub"
  else
    echo "Skipping GitHub status report - missing required variables"
    echo "  GIT_TOKEN: ${GIT_TOKEN:+SET}"
    echo "  COMMIT_SHA: ${COMMIT_SHA:-NOT_SET}"
    echo "  REPO_OWNER: ${REPO_OWNER:-NOT_SET}"
    echo "  REPO_NAME: ${REPO_NAME:-NOT_SET}"
  fi
}
