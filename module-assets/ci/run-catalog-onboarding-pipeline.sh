#! /bin/bash

set -euo pipefail

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
        --catalog_id=<catalog-id>
        --offering_id=<offering-id>
        --version=<version>
        --target=<target>  (ibm, account or public)

        Optional arguments:
        [--destroy_on_failure]  (By default resources will not be destroyed on validation failure to allow to debug. Use this flag to always attempt a destroy)
        [--use_default_targz]  (Publish / validate using the default tar.gz. If not used catalog.tar.gz will be used)
        [--use_publish_apikey_override]  (Requires CATALOG_PUBLISH_APIKEY env var to be set)
        [--use_valadation_apikey_override]  (Requires CATALOG_VALIDATION_APIKEY env var to be set)
        [--validation_dir_list=<validation-dir-list>]  (If not using ibm_catalog.json, then pass a comma seperated list of directories to validate)
        [--github_url=<github_url>]  (Defaults to github.ibm.com)
        [--github_org=<github-org>]  (Defaults to GoldenEye)
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
CATALOG_ID=""
OFFERING_ID=""
VERSION=""
TARGET=""
VALIDATION_DIR_LIST=""
GITHUB_URL="github.ibm.com"
GITHUB_ORG="GoldenEye"
VALIDATION_JSON_FILENAME="ibm_catalog.json"
USE_DEFAULT_TARGZ=false
DESTROY_ON_FAILURE=false
PUBLISH_APIKEY_OVERRIDE="none"
VALIDATION_APIKEY_OVERRIDE="none"
FLAVOR_LABEL=""
# If either of these files are detected, pass them to catalog pipeline
PREVALIDATION_SCRIPT="pre-validation.sh"
POSTVALIDATION_SCRIPT="post-validation.sh"

# Determine repo name
REPO_NAME="$(basename "$(git config --get remote.origin.url)")"
REPO_NAME="${REPO_NAME//.git/}"

# Loop through all args
for arg in "$@"; do
  if [ ${arg} = --use_default_targz ]; then
    USE_DEFAULT_TARGZ=true
  elif [ ${arg} = --destroy_on_failure ]; then
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
    if echo "${arg}" | grep -q -e --catalog_id=; then
      CATALOG_ID=$(echo "${arg}" | awk -F= '{ print $2 }')
      found_match=true
    fi
    if echo "${arg}" | grep -q -e --offering_id=; then
      OFFERING_ID=$(echo "${arg}" | awk -F= '{ print $2 }')
      found_match=true
    fi
    if echo "${arg}" | grep -q -e --version=; then
      VERSION=$(echo "${arg}" | awk -F= '{ print $2 }')
      found_match=true
    fi
    if echo "${arg}" | grep -q -e --target=; then
      TARGET=$(echo "${arg}" | awk -F= '{ print $2 }')
      found_match=true
    fi
    if echo "${arg}" | grep -q -e --validation_dir_list=; then
      VALIDATION_DIR_LIST=$(echo ${arg} | awk -F= '{ print $2 }' | sed 's/,/ /g')
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

# Verify values have been passed for required args
if [ "${CATALOG_ID}" = "" ] || [ "${OFFERING_ID}" = "" ] || [ "${VERSION}" = "" ] || [ "${TARGET}" = "" ]; then
  echo "Missing catalog_id, offering_id, version, or target definitions"
  echo "--catalog_id=${CATALOG_ID}"
  echo "--offering_id=${OFFERING_ID}"
  echo "--version=${VERSION}"
  echo "--target=${TARGET}"
  exit 1
fi

# Verify target value is only ibm, account or public
if [ "${TARGET}" != "ibm" ] && [ "${TARGET}" != "account" ] && [ "${TARGET}" != "public" ]; then
  echo "--target value must be ibm, account or public"
  exit 1
fi

# Verify github org value
if [ "${GITHUB_URL}" != "github.ibm.com" ] && [ "${GITHUB_URL}" != "github.com" ]; then
  echo "--github_url value must be github.ibm.com or github.com"
  exit 1
fi

# Generate array of validation directories
if [ "${VALIDATION_DIR_LIST}" == "" ]; then
  if [ ! -f "${VALIDATION_JSON_FILENAME}" ]; then
    echo "Could not find required file ibm_catalog.json"
    echo "Please add this file with required content, or use the --validation_dir_list flag to pass a list of directories to run validation on."
    exit 1
  else
    echo "Parsing details from ${VALIDATION_JSON_FILENAME} .."
    dir_array=()
    while IFS='' read -r line; do dir_array+=("$line"); done < <(jq -r '.flavors | .[] | .working_directory' "${VALIDATION_JSON_FILENAME}")
  fi
else
  IFS=', ' read -r -a dir_array <<< "${VALIDATION_DIR_LIST}"
fi

# Loop through tf directories to run validation on and kick off one pipeline instance per directory
for validation_dir in "${dir_array[@]}"; do

  # Determine if pre/post validation script exist
  prevalidation=""
  if [ -f "${validation_dir}/${PREVALIDATION_SCRIPT}" ]; then
    prevalidation="${validation_dir}/${PREVALIDATION_SCRIPT}"
  fi
  postvalidation=""
  if [ -f "${validation_dir}/${POSTVALIDATION_SCRIPT}" ]; then
      postvalidation="${validation_dir}/${POSTVALIDATION_SCRIPT}"
  fi

  # Fetch the flavor label name if ibm_catalog.json is being used
  if [ "${VALIDATION_DIR_LIST}" == "" ]; then
    FLAVOR_LABEL=$(jq -r --arg workDir "${validation_dir}" '.flavors | .[] | select(.working_directory==$workDir) | .label' ${VALIDATION_JSON_FILENAME})
  fi

  echo
  echo "Generating payload for ${validation_dir} .."
  payload=$(jq -c -n --arg repoName "${REPO_NAME}" \
                     --arg catalogID "${CATALOG_ID}" \
                     --arg offeringID "${OFFERING_ID}" \
                     --arg version "${VERSION}" \
                     --arg target "${TARGET}" \
                     --arg dir "${validation_dir}" \
                     --arg gitUrl "${GITHUB_URL}" \
                     --arg gitOrg "${GITHUB_ORG}" \
                     --arg useDefaultTargz "${USE_DEFAULT_TARGZ}" \
                     --arg publishApikeyOverride "${PUBLISH_APIKEY_OVERRIDE}" \
                     --arg validationApikeyOverride "${VALIDATION_APIKEY_OVERRIDE}" \
                     --arg destroyOnFailure "${DESTROY_ON_FAILURE}" \
                     --arg flavorLabel "${FLAVOR_LABEL}" \
                     --arg prevalidation "${prevalidation}" \
                     --arg postvalidation "${postvalidation}" \
                     '{"repo-name": $repoName,
                       "catalog-id": $catalogID,
                       "offering-id": $offeringID,
                       "version": $version,
                       "target": $target,
                       "validation-working-directory": $dir,
                       "git-url": $gitUrl,
                       "git-org": $gitOrg,
                       "use-default-targz": $useDefaultTargz,
                       "external-catalog-api-key-override": $publishApikeyOverride,
                       "external-validation-api-key-override": $validationApikeyOverride,
                       "destroy-on-failure": $destroyOnFailure,
                       "flavor": $flavorLabel,
                       "prevalidation-script": $prevalidation,
                       "postvalidation-script": $postvalidation
                     }')

  echo
  echo "Kicking off tekton pipeline for ${validation_dir}.."
  curl -X POST \
  "$CATALOG_TEKTON_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "token: ${CATALOG_TEKTON_WEBHOOK_TOKEN}" \
  -d "$payload"
  echo

  # Using syntax ${#a[@]} here to get last element of array so code is compatible on older bash (v4.0 or earlier) - see https://unix.stackexchange.com/a/198788
  if [ "${validation_dir}" != "${dir_array[${#dir_array[@]}-1]}" ]; then
    # Sleep for 5 mins to prevent 409 doc conflict when pipeline tries to update same document
    echo "Sleeping for 5 mins.."
    sleep 300
  fi
done
