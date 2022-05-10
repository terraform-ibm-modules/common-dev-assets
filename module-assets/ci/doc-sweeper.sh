#! /bin/bash

# This script is designed to run as part of CI on PRs opened by renovate.
# The script will run the pre-commit hook and if there are any doc changes detected, it will commit them to the PR
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
  git add .
  git commit -m "doc: committing files modified by the hook"
  git push origin "${TRAVIS_PULL_REQUEST_BRANCH}"
}
# When running in Github Actions Set the environment variables with the following syntax
#   env:
#      TRAVIS_PULL_REQUEST_BRANCH: ${{ github.head_ref }}
#      TRAVIS_PULL_REQUEST: ${{ github.event.number }}
# Only run on PRs created by renovate
if [[ "${TRAVIS_PULL_REQUEST}" != "false" ]] && [[ "${TRAVIS_PULL_REQUEST_BRANCH}" =~ "renovate" ]]; then
  if ! pre-commit run --all-files; then
    echo "Pre-commit did not return 0 exit code. Checking if any files changes.."
    # Check if hook modified any files
    if ! git diff --exit-code; then
      echo "Detected file changes - configuring git to push changes to branch: ${TRAVIS_PULL_REQUEST_BRANCH}"
      # Configure local git
      git_config
      # Checkout to PR branch
      git checkout "${TRAVIS_PULL_REQUEST_BRANCH}"
      # Commit and push changes
      git_push
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
