#! /bin/bash

set -euo pipefail

function trigger_pipeline() {

  repo_name=$1
  product=$2
  flavor_label=$3
  install_type=$4
  version=$5
  git_url=$6
  git_org=$7
  destroy_resources_on_failure=$8
  destroy_workspace_on_failure=$9
  publish_apikey_override=${10}
  validation_apikey_override=${11}

  payload=$(jq -c -n --arg repoName "${repo_name}" \
                     --arg product "${product}" \
                     --arg flavorLabel "${flavor_label}" \
                     --arg installType "${install_type}" \
                     --arg version "${version}" \
                     --arg gitUrl "${git_url}" \
                     --arg gitOrg "${git_org}" \
                     --arg destroyResourcesOnFailure "${destroy_resources_on_failure}" \
                     --arg destroyWorkspaceOnFailure "${destroy_workspace_on_failure}" \
                     --arg publishApikeyOverride "${publish_apikey_override}" \
                     --arg validationApikeyOverride "${validation_apikey_override}" \
                     '{"repo-name": $repoName,
                       "product": $product,
                       "flavor-label": $flavorLabel,
                       "install-type": $installType,
                       "version": $version,
                       "git-url": $gitUrl,
                       "git-org": $gitOrg,
                       "external-catalog-api-key-override": $publishApikeyOverride,
                       "external-validation-api-key-override": $validationApikeyOverride,
                       "destroy-resources-on-failure": $destroyResourcesOnFailure,
                       "destroy-workspace-on-failure": $destroyWorkspaceOnFailure
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
        [--destroy_resources_on_failure]  (By default resources will not be destroyed on validation failure to allow to debug. Use this flag to always attempt a destroy of resources)
        [--destroy_workspace_on_failure]  (By default the workspace will not be destroyed on validation failure to allow to debug. Use this flag to always attempt a destroy of the workspace (can only be used if --destroy_resources_on_failure is set too))
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
DESTROY_RESOURCES_ON_FAILURE=false
DESTROY_WORKSPACE_ON_FAILURE=false

# Verify ibm_catalog.json exists
if ! test -f "${CATALOG_JSON_FILENAME}"; then
  echo "No ${CATALOG_JSON_FILENAME} file was detected, unable to proceed."
  exit 1
fi

# Determine repo name
REPO_NAME="$(basename "$(git config --get remote.origin.url)")"
REPO_NAME="${REPO_NAME//.git/}"

# Loop through all args
for arg in "$@"; do
  if [ "${arg}" = --destroy_resources_on_failure ]; then
    DESTROY_RESOURCES_ON_FAILURE=true
  elif [ "${arg}" = --destroy_workspace_on_failure ]; then
    DESTROY_WORKSPACE_ON_FAILURE=true
  elif [ "${arg}" = --use_publish_apikey_override ]; then
    set +u
    if [ -z "${CATALOG_PUBLISH_APIKEY}" ]; then
      echo "CATALOG_PUBLISH_APIKEY environment variable must be set when using --use_publish_apikey_override flag"
      exit 1
    else
      PUBLISH_APIKEY_OVERRIDE="${CATALOG_PUBLISH_APIKEY}"
    fi
    set -u
  elif [ "${arg}" = --use_valadation_apikey_override ]; then
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
      if [ "${arg}" != --help ]; then
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

# Verify destroy flags used correctly
if [ ${DESTROY_WORKSPACE_ON_FAILURE} == true ] && [ ${DESTROY_RESOURCES_ON_FAILURE} == false ]; then
  echo "If you are setting --destroy_workspace_on_failure then you must also set --destroy_resources_on_failure"
  exit 1
fi

# Verify github org value
if [ "${GITHUB_URL}" != "github.ibm.com" ] && [ "${GITHUB_URL}" != "github.com" ]; then
  echo "--github_url value must be github.ibm.com or github.com"
  exit 1
fi

# Add all products into product array
product_array=()
while IFS='' read -r line; do product_array+=("$line"); done < <(jq -r '.products | .[].name' "${CATALOG_JSON_FILENAME}")

# Loop through all products
for product in "${product_array[@]}"; do
  # Add all product flavors into a directory array since directory will be unique for each entry
  directory_array=()
  while IFS='' read -r line; do directory_array+=("$line"); done < <(jq -r --arg product "${product}" '.products | .[] | select(.name==$product) | .flavors | .[] | .working_directory' "${CATALOG_JSON_FILENAME}")
  # Loop through all flavor directories and trigger onboarding pipeline for each one
  for flavor_dir in "${directory_array[@]}"; do
    if [ "${flavor_dir}" == "null" ]; then
      echo "Unable to determine working directory. Please ensure the ibm_catalog.json has working_directory value set"
      exit 1
    fi
    # determine the flavor label
    flavor_label=$(jq -r --arg wdir "${flavor_dir}" --arg product "${product}" '.products | .[] | select(.name==$product) | .flavors | .[] | select(.working_directory==$wdir) | .label' "${CATALOG_JSON_FILENAME}")
    # determine the install type
    install_type="non-da"
    if [ "${flavor_label}" != "null" ]; then
      install_type=$(jq -r --arg wdir "${flavor_dir}" --arg product "${product}" '.products | .[] | select(.name==$product) | .flavors | .[] | select(.working_directory==$wdir) | .install_type' "${CATALOG_JSON_FILENAME}")
      echo
      echo "Kicking off tekton pipeline for ${product} (${flavor_label} - ${install_type}) .."
    else
      echo
      echo "Kicking off tekton pipeline for ${product} (${install_type}) .."
    fi
    trigger_pipeline "${REPO_NAME}" "${product}" "${flavor_label}" "${install_type}" "${VERSION}" "${GITHUB_URL}" "${GITHUB_ORG}" "${DESTROY_RESOURCES_ON_FAILURE}" "${DESTROY_WORKSPACE_ON_FAILURE}" "${PUBLISH_APIKEY_OVERRIDE}" "${VALIDATION_APIKEY_OVERRIDE}"
    echo

    # Using syntax ${#a[@]} here to get last element of array so code is compatible on older bash (v4.0 or earlier) - see https://unix.stackexchange.com/a/198788
    if [ "${flavor_dir}" != "${directory_array[${#directory_array[@]}-1]}" ]; then
      # Sleep for 5 mins before triggering pipeline again
      echo
      echo "Sleeping for 5 mins.."
      sleep 300
    fi
  done
done
