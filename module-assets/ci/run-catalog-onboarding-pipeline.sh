#! /bin/bash

set -euo pipefail

function trigger_pipeline() {

  repo_name=$1
  product=$2
  flavor=$3
  version=$4
  git_url=$5
  git_org=$6
  destroy_on_failure=$7
  publish_apikey_override=$8
  validation_apikey_override=$9

  payload=$(jq -c -n --arg repoName "${repo_name}" \
                     --arg product "${product}" \
                     --arg flavor "${flavor}" \
                     --arg version "${version}" \
                     --arg gitUrl "${git_url}" \
                     --arg gitOrg "${git_org}" \
                     --arg destroyOnFailure "${destroy_on_failure}" \
                     --arg publishApikeyOverride "${publish_apikey_override}" \
                     --arg validationApikeyOverride "${validation_apikey_override}" \
                     '{"repo-name": $repoName,
                       "product": $product,
                       "flavor": $flavor,
                       "version": $version,
                       "git-url": $gitUrl,
                       "git-org": $gitOrg,
                       "external-catalog-api-key-override": $publishApikeyOverride,
                       "external-validation-api-key-override": $validationApikeyOverride,
                       "destroy-on-failure": $destroyOnFailure
                     }')

  curl -X POST \
  "$CATALOG_TEKTON_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "token: ${CATALOG_TEKTON_WEBHOOK_TOKEN}" \
  -d "${payload}"

}

PRG=$(basename -- "${0}")

USAGE="
usage:	${PRG}
        [--help]

        Required environment variables:
        CATALOG_TEKTON_WEBHOOK_URL
        CATALOG_TEKTON_WEBHOOK_TOKEN

        Optional environment variables:
        CATALOG_PUBLISH_APIKEY  (If not set, offering will be published to GoldenEye catalog. Requires --use_publish_apikey_override flag to be passed)
        CATALOG_VALIDATION_APIKEY  (If not set, offering will validated in GoldenEye dev account. Requires --use_valadation_apikey_override flag to be passed)

        Required arguments:
        --version=<version>

        Optional arguments:
        [--use_publish_apikey_override]  (Requires CATALOG_PUBLISH_APIKEY env var to be set)
        [--use_valadation_apikey_override]  (Requires CATALOG_VALIDATION_APIKEY env var to be set)
        [--github_url=<github_url>]  (Defaults to github.ibm.com)
        [--github_org=<github-org>]  (Defaults to GoldenEye)
        [--destroy_on_failure]  (By default resources will not be destroyed on validation failure to allow to debug. Use this flag to always attempt a destroy)
"

# Verify required environment variables are set
all_exist=true
env_var_array=( CATALOG_TEKTON_WEBHOOK_URL CATALOG_TEKTON_WEBHOOK_TOKEN )
set +u
for var in "${env_var_array[@]}"; do
  [ -z "${!var}" ] && echo "$var not defined." && all_exist=false
done
set -u
if [ $all_exist == false ]; then
  echo "One or more required environment variables are not defined. Exiting."
  exit 1
fi

# Pre-set macros so nounset doesn't complain
VERSION=""
GITHUB_URL="github.ibm.com"
GITHUB_ORG="GoldenEye"
CATALOG_JSON_FILENAME="ibm_catalog.json"
PUBLISH_APIKEY_OVERRIDE="none"
VALIDATION_APIKEY_OVERRIDE="none"
DESTROY_ON_FAILURE=false

# Determine repo name
REPO_NAME="$(basename "$(git config --get remote.origin.url)")"
REPO_NAME="${REPO_NAME//.git/}"

# Loop through all args
for arg in "$@"; do
  if [ ${arg} = --destroy_on_failure ]; then
    DESTROY_ON_FAILURE=true
  elif [ ${arg} = --use_publish_apikey_override ]; then
    set +u
    if [ -z "${CATALOG_PUBLISH_APIKEY}" ]; then
      echo "CATALOG_PUBLISH_APIKEY environment variable must be set when using --use_publish_apikey_override flag"
      exit 1
    else
      PUBLISH_APIKEY_OVERRIDE="${CATALOG_PUBLISH_APIKEY}"
    fi
    set -u
  elif [ ${arg} = --use_valadation_apikey_override ]; then
    set +u
    if [ -z "${CATALOG_VALIDATION_APIKEY}" ]; then
      echo "CATALOG_VALIDATION_APIKEY environment variable must be set when using --use_valadation_apikey_override flag"
      exit 1
    else
      VALIDATION_APIKEY_OVERRIDE="${CATALOG_VALIDATION_APIKEY}"
    fi
    set -u
  else
    set +e
    found_match=false
    if echo "${arg}" | grep -q -e --version=; then
      VERSION=$(echo "${arg}" | awk -F= '{ print $2 }')
      found_match=true
    fi
    if echo "${arg}" | grep -q -e --github_url=; then
      GITHUB_URL=$(echo "${arg}" | awk -F= '{ print $2 }')
      found_match=true
    fi
    if echo "${arg}" | grep -q -e --github_org=; then
      GITHUB_ORG=$(echo "${arg}" | awk -F= '{ print $2 }')
      found_match=true
    fi
    if [ ${found_match} = false ]; then
      if [ ${arg} != --help ]; then
        echo "Unknown command line argument:  ${arg}"
      fi
      echo "${USAGE}"
      exit 1
    fi
    set -e
  fi
done

# Verify version has been passed
if [ "${VERSION}" = "" ]; then
  echo "Version must be passed using --version flag"
  exit 1
fi

# Verify github org value
if [ "${GITHUB_URL}" != "github.ibm.com" ] && [ "${GITHUB_URL}" != "github.com" ]; then
  echo "--github_url value must be github.ibm.com or github.com"
  exit 1
fi

# Parse ibm_catalog.json if it exists
if test -f "${CATALOG_JSON_FILENAME}"; then
  echo "Parsing values from ${CATALOG_JSON_FILENAME} .."

  # Add all products into product array
  product_array=()
  while IFS='' read -r line; do product_array+=("$line"); done < <(jq -r '.products | .[].name' "${CATALOG_JSON_FILENAME}")

  # Loop through all products
  for product in "${product_array[@]}"; do
    # Add all product flavors into flavor array
    flavor_array=()
    while IFS='' read -r line; do flavor_array+=("$line"); done < <(jq -r --arg product "${product}" '.products | .[] | select(.name==$product) | .flavors | .[] | .name' "${CATALOG_JSON_FILENAME}")
    # Loop through all flavors and trigger onboarding pipeline for each one
    for flavor in "${flavor_array[@]}"; do
      echo
      echo "Kicking off tekton pipeline for ${product} (${flavor}) .."
      trigger_pipeline "${REPO_NAME}" "${product}" "${flavor}" "${VERSION}" "${GITHUB_URL}" "${GITHUB_ORG}" "${DESTROY_ON_FAILURE}" "${PUBLISH_APIKEY_OVERRIDE}" "${VALIDATION_APIKEY_OVERRIDE}"
      echo

      # Using syntax ${#a[@]} here to get last element of array so code is compatible on older bash (v4.0 or earlier) - see https://unix.stackexchange.com/a/198788
      if [ "${flavor}" != "${flavor_array[${#flavor_array[@]}-1]}" ]; then
        # Sleep for 5 mins to prevent 409 doc conflict when pipeline tries to update same document
        echo
        echo "Sleeping for 5 mins.."
        sleep 300
      fi
    done
  done
else
  # When repo contains no ibm_catalog.json, pass null as flavor type and repo name for product name
  echo
  echo "Kicking off tekton pipeline for ${REPO_NAME} .."
  trigger_pipeline "${REPO_NAME}" "${REPO_NAME}" "null" "${VERSION}" "${GITHUB_URL}" "${GITHUB_ORG}" "${DESTROY_ON_FAILURE}" "${PUBLISH_APIKEY_OVERRIDE}" "${VALIDATION_APIKEY_OVERRIDE}"
fi
