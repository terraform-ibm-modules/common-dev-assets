#!/usr/bin/env bash
set -eu pipefail

# Usage: source this script at the end of your pipeline script
# It will report success or failure to GitHub depending on the exit status

function report_status {
  local status=$1
  local description=$2
  if [[ -n "$GIT_TOKEN" && -n "$COMMIT_SHA" ]]; then
    curl -s -X POST -H "Authorization: token $GIT_TOKEN" -H "Accept: application/vnd.github+json" \
      https://github.ibm.com/api/v3/repos/$REPO_OWNER/$REPO_NAME/statuses/$COMMIT_SHA \
      -d "{\"state\": \"$status\", \"target_url\": \"$PIPELINE_RUN_URL\", \"context\": \"continuous-integration/simple-pipeline\", \"description\": \"$description\"}"
  fi
}

# Trap errors and report failure
trap 'report_status failure "Build failed"' ERR

# At the end of your script, call:
# report_status success "All checks passed"
