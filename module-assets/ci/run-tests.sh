#!/bin/bash

# WARNING
#
# This script will only work in travis if git depth is disabled in travis.yml.
# Disabling this will allow a deep clone of the source repo with the full history.
# Approach based on https://dev.to/ahferroin7/skip-ci-stages-in-travis-based-on-what-files-changed-3a4k
#

set -e
set -o pipefail

# Determine if PR
IS_PR=false

# GitHub Actions (see https://docs.github.com/en/actions/learn-github-actions/environment-variables)
if [ "${GITHUB_ACTIONS}" == "true" ]; then
  # GITHUB_HEAD_REF: This property is only set when the event that triggers a workflow run is either pull_request or pull_request_target
  if [ -n "${GITHUB_HEAD_REF}" ]; then
    IS_PR=true
    TARGET_BRANCH="origin/${GITHUB_BASE_REF}"
    PR_NUM=$(echo "$GITHUB_REF" | awk -F/ '{print $3}')
  fi
  REPO_NAME="$(basename "${GITHUB_REPOSITORY}")"

# Travis (see https://docs.travis-ci.com/user/environment-variables)
elif [ "${TRAVIS}" == "true" ]; then
  # TRAVIS_PULL_REQUEST: The pull request number if the current job is a pull request, “false” if it’s not a pull request.
  if [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
    IS_PR=true
    TARGET_BRANCH="${TRAVIS_BRANCH}"
    PR_NUM="${TRAVIS_PULL_REQUEST}"
  fi
  REPO_NAME="$(basename "${TRAVIS_REPO_SLUG}")"

# Tekton Toolchain (see https://cloud.ibm.com/docs/devsecops?topic=devsecops-devsecops-pipelinectl)
elif [ -n "${PIPELINE_RUN_ID}" ]; then
  if [ "$(get_env pipeline_namespace)" == "pr" ]; then
    IS_PR=true
    TARGET_BRANCH="origin/$(get_env base-branch)"
    PR_NUM="$(basename "${PR_URL}")"
  fi
  REPO_NAME="$(load_repo app-repo path)"
else
  echo "Could not determine CI runtime environment. Script only support tekton, travis or github actions."
  exit 1
fi

if [ ${IS_PR} == true ]; then

  # Files that should not trigger tests
  declare -a skip_array=(".drawio"
                         ".github/settings.yml"
                         ".github/workflows/ci.yml"
                         ".github/workflows/release.yml"
                         ".gitignore"
                         ".gitmodules"
                         ".md"
                         ".mdlrc"
                         ".png"
                         ".svg"
                         ".pre-commit-config.yaml"
                         ".releaserc"
                         ".secrets.baseline"
                         ".travis.yml"
                         ".whitesource"
                         "Brewfile"
                         "CODEOWNERS"
                         "commitlint.config.js"
                         "common-dev-assets"
                         "Makefile"
                         "renovate.json"
                         "catalogValidationValues.json.template"
                         ".one-pipeline.yaml"
                         "module-metadata.json"
                         "ibm_catalog.json"
                         "cra-tf-validate-ignore-goals.json")

  # Determine all files being changed in the PR, and add it to array
  changed_files="$(git diff --name-only "${TARGET_BRANCH}..HEAD" --)"
  mapfile -t file_array <<< "${changed_files}"

  # Check if any file in skip_array matches any of the files being updated in the PR
  for f in "${file_array[@]}"; do
    match=false
    for s in "${skip_array[@]}"; do
      if [[ "$f" =~ $s ]]; then
        # File has matched one in the skip_array - break out of loop to try next file
        match=true
        break
      fi
    done
    if [ "${match}" == "false" ]; then
      # No need to iterate through any more files as PR contains a file not in skip_array
      break
    fi
  done

  # If there are any files being updated in the PR that are not in the skip list, then run the tests
  if [ "${match}" == "false" ]; then
    cd tests
    test_arg=""
    # If pr_test.go exists, only execute those tests
    pr_test_file=pr_test.go
    if test -f "${pr_test_file}"; then
        test_arg=${pr_test_file}
    fi
    test_cmd="go test ${test_arg} -count=1 -v -timeout 300m"
    if [[ "$MZ_INGESTION_KEY" ]] ; then
      # Assign location to be observed by logdna-agent
      if [ -z "$MZ_LOG_DIRS" ]; then
        export MZ_LOG_DIRS="/tmp"
      fi
      #lookback strategy determines how the agent handles existing files on agent startup
      if [ -z "$LOGDNA_LOOKBACK" ]; then
        export LOGDNA_LOOKBACK="smallfiles"
      fi
      # This is required to send logs to logdna-agent instance
      if [ -z "$MZ_HOST" ]; then
        export MZ_HOST="logs.us-south.logging.cloud.ibm.com"
      fi
      log_location="$MZ_LOG_DIRS/test.log"
      # Assign tags
      export MZ_TAGS="$REPO_NAME-PR$PR_NUM"
      # Exclude extra logs
      export MZ_EXCLUSION_REGEX_RULES="/var/log/*"
      echo "Starting logdna-agent"
      systemctl start logdna-agent
      echo "Logdna-agent Status: $(systemctl status logdna-agent)"
      $test_cmd 2>&1 | tee "$log_location"

    else
      $test_cmd
    fi
    cd ..
  else
    echo "No file changes detected to trigger tests"
  fi
else
  echo "Not running tests in merge pipeline"
fi
