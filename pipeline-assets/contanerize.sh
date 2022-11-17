#!/usr/bin/env bash

if [[ "$PIPELINE_DEBUG" == 1 ]]; then
  trap env EXIT
  env
  set -x
fi

exit_code=0
# shellcheck disable=SC2155
export ARTIFACTORY_USERNAME="$(get_env artifactory-user)"
# shellcheck disable=SC2155
export ARTIFACTORY_PASSWORD="$(get_env artifactory-password)"
# shellcheck disable=SC2155
export IBMCLOUD_APIKEY="$(get_env ibmcloud-api-key)"

make docker-build || exit_code=$?
make docker-validate  || exit_code=$?

BRANCH=$(get_env "BRANCH")

if [ "${BRANCH^^}" != "MASTER" ] && [ "${BRANCH^^}" != "MAIN" ]; then
  # Grep explanation https://stackoverflow.com/a/22727242
  PR_NUMBER=$(get_env "PR_URL" | grep -o '[^/]*$')
  IMAGE_NAME=$(get_env "IMAGE_NAME")
  IMAGE_TAG="PR-${PR_NUMBER}"
  make docker-push IMAGE_TAG="${IMAGE_TAG}"
  REGISTRY="$(get_env 'DEV_REPO'  | cut -f1 -d/  )"
  NAMESPACE="$(get_env 'DEV_REPO' | cut -f2 -d/ )"

  ./common-dev-assets/pipeline-assets/image_vuln_scan.sh "${REGISTRY}" "${NAMESPACE}" "${IMAGE_NAME}" "${IMAGE_TAG}" "${IBMCLOUD_APIKEY}" false  || exit_code=$?

fi

# save status for new evidence collection
set_env status "success"
if [ "$exit_code" != "0" ]; then
  set_env status "failure"
fi

exit $exit_code
