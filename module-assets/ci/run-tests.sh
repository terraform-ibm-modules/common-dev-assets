#!/bin/bash

# WARNING
#
# This script will only work in travis if git depth is disabled in travis.yml.
# Disabling this will allow a deep clone of the source repo with the full history.
# Approach based on https://dev.to/ahferroin7/skip-ci-stages-in-travis-based-on-what-files-changed-3a4k
#

set -e

# Determine if PR
IS_PR=false
if [ "${GITHUB_ACTIONS}" == "true" ]; then
  # GITHUB_HEAD_REF: This property is only set when the event that triggers a workflow run is either pull_request or pull_request_target
  if [ -n "${GITHUB_HEAD_REF}" ]; then
    IS_PR=true
    TARGET_BRANCH="origin/${GITHUB_BASE_REF}"
  fi
elif [ "${TRAVIS}" == "true" ]; then
  # TRAVIS_PULL_REQUEST: The pull request number if the current job is a pull request, “false” if it’s not a pull request.
  if [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
    IS_PR=true
    TARGET_BRANCH="${TRAVIS_BRANCH}"
  fi
else
  echo "Could not determine CI runtime environment. Script only support travis or github actions."
  exit 1
fi

if [ ${IS_PR} == true ]; then

  # Files that should not trigger tests
  declare -a skip_array=(".drawio"
                         ".github/settings.yml"
                         ".github/workflows/main.yml"
                         ".gitignore"
                         ".gitmodules"
                         ".md"
                         ".mdlrc"
                         ".png"
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
                         "catalogValidationValues.json.template")

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
    go test "${test_arg}" -count=1 -v -timeout 300m
    cd ..
  else
    echo "No file changes detected to trigger tests"
  fi
else
  echo "Not running tests in merge pipeline"
fi
