#! /bin/bash

# This script is designed to run as part of Travis or Github Actions on PRs opened by renovate.
# The script will run the pre-commit hook and if there are any changes detected, it will commit them to the PR
# branch which will trigger a new run of the pipeline.

set -e

function git_config() {
  git_user="goldeneye.development@ibm.com"
  git config --global user.email "${git_user}"
  git config --global user.name "${git_user}"
  git config --replace-all remote.origin.fetch +refs/heads/*:refs/remotes/origin/*
  git fetch
}

function git_push() {
  branch=$1

  git add .
  git commit -m "doc: committing files modified by the hook"
  git push origin "${branch}"
}

# Determine if PR
IS_PR=false
if [ "${GITHUB_ACTIONS}" == "true" ]; then
  # GITHUB_HEAD_REF: This property is only set when the event that triggers a workflow run is either pull_request or pull_request_target
  if [ -n "${GITHUB_HEAD_REF}" ]; then
    IS_PR=true
    BRANCH="${GITHUB_HEAD_REF}"
  fi
elif [ "${TRAVIS}" == "true" ]; then
  # TRAVIS_PULL_REQUEST: The pull request number if the current job is a pull request, “false” if it’s not a pull request.
  if [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
    IS_PR=true
    BRANCH="${TRAVIS_PULL_REQUEST_BRANCH}"
  fi
else
  echo "Could not determine CI runtime environment. Script only support travis or github actions."
  exit 1
fi

# Only run on PRs created by renovate
if [[ ${IS_PR} == true ]] && [[ "${BRANCH}" =~ "renovate" ]]; then
  if ! pre-commit run --all-files; then
    echo "Pre-commit did not return 0 exit code. Checking if any files changes.."
    # Check if hook modified any files
    if ! git diff --exit-code; then
      echo "Detected file changes - configuring git to push changes to branch: ${BRANCH}"
      # Configure local git
      git_config
      # Checkout to PR branch
      git checkout "${BRANCH}"
      # Commit and push changes
      git_push "${BRANCH}"
      echo "Changes pushed in a new commit, exiting with exit code 1 - new commit will trigger new pipeline run"
      exit 1 # Failing the pipeline here to ensure the PR cannot be merged before new pipeline runs on the commit we just pushed
    else
      echo "Did not detect any file changes, yet the hook failed. Please investigate"
      exit 1
    fi
  else
    echo "No changes detected after running hook - no action required"
    exit 0
  fi
fi
