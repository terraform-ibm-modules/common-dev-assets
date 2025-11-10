#!/bin/bash
#
# Script: reset_iks_api_key.sh
# Description: Reset IBM Cloud Kubernetes Service (IKS) API key for a specific region and resource group
#
# Usage: ./reset_iks_api_key.sh <REGION> <RESOURCE_GROUP_NAME> [ACCOUNT_ID] [PRIVATE_ENV] [CLUSTER_ENDPOINT]
#
# Required Arguments:
#   REGION                  IBM Cloud region (e.g., us-south, eu-gb, jp-tok)
#   RESOURCE_GROUP_NAME     Name of the resource group
#
# Optional Arguments:
#   ACCOUNT_ID              IBM Cloud account ID (default: abac0df06b644a9cabc6e44f55b3880e)
#   PRIVATE_ENV             Use private endpoints (true/false, default: false)
#   CLUSTER_ENDPOINT        Cluster endpoint type (default/private/vpe, default: default)
#
# Environment Variables:
#   IBMCLOUD_API_KEY                        (Required) IBM Cloud API key for authentication
#   IBMCLOUD_IAM_API_ENDPOINT               (Optional) IAM API endpoint (default: iam.cloud.ibm.com)
#   IBMCLOUD_CS_API_ENDPOINT                (Optional) Container Service API endpoint (default: containers.cloud.ibm.com)
#   IBMCLOUD_RESOURCE_CONTROLLER_API_ENDPOINT (Optional) Resource Controller API endpoint (default: resource-controller.cloud.ibm.com)
#
# Examples:
#   # Basic usage with required parameters
#   export IBMCLOUD_API_KEY="your-api-key-here"
#   ./reset_iks_api_key.sh us-south my-resource-group
#
#   # With custom account ID
#   ./reset_iks_api_key.sh eu-gb my-resource-group 1234567890abcdef1234567890abcdef
#
#   # Using private endpoints
#   ./reset_iks_api_key.sh us-south my-resource-group abac0df06b644a9cabc6e44f55b3880e true
#
#   # Using VPE endpoint
#   ./reset_iks_api_key.sh us-south my-resource-group abac0df06b644a9cabc6e44f55b3880e true vpe
#
# Exit Codes:
#   0    Success - API key reset successfully
#   1    Failure - Missing required parameters, authentication failure, or API errors
#
# Notes:
#   - The script checks for existing API keys before attempting to reset
#   - Maximum retry attempts: 10
#   - Retry wait time: 5 seconds between attempts
#   - After successful reset, the script waits 10 seconds for key replication
#

set -eo pipefail

REGION="${1:-}"
RESOURCE_GROUP_NAME="${2:-}"
ACCOUNT_ID="${3:-"abac0df06b644a9cabc6e44f55b3880e"}"
PRIVATE_ENV="${4:-false}"
CLUSTER_ENDPOINT="${5:-"default"}"
APIKEY_KEY_NAME="containers-kubernetes-key"
MAX_ATTEMPTS=10

if [[ -z "${REGION}" ]]; then
    echo "Region must be passed as first input script argument" >&2
    exit 1
fi

if [[ -z "${RESOURCE_GROUP_NAME}" ]]; then
    echo "Resource group name must be passed as second input script argument" >&2
    exit 1
fi

if [[ -z "${ACCOUNT_ID}" ]]; then
    echo "Account ID must be passed as third input script argument" >&2
    exit 1
fi

if [[ -z "${IBMCLOUD_API_KEY}" ]]; then
    echo "IBM Cloud api key must be set using the environment variable IBMCLOUD_API_KEY" >&2
    exit 1
fi
set -u

get_cloud_endpoint() {
    iam_cloud_endpoint="${IBMCLOUD_IAM_API_ENDPOINT:-"iam.cloud.ibm.com"}"
    IBMCLOUD_IAM_API_ENDPOINT=${iam_cloud_endpoint#https://}

    cs_api_endpoint="${IBMCLOUD_CS_API_ENDPOINT:-"containers.cloud.ibm.com"}"
    cs_api_endpoint=${cs_api_endpoint#https://}
    IBMCLOUD_CS_API_ENDPOINT=${cs_api_endpoint%/global}
}

fetch_data() {
    local url="$IAM_URL"

    while [ "$url" != "null" ]; do
        # Fetch data from the API
        IAM_RESPONSE=$(curl -s "$url" --header "Authorization: Bearer $IAM_TOKEN" --header "Content-Type: application/json")

        ERROR_MESSAGE=$(echo "${IAM_RESPONSE}" | jq 'has("errors")')
        if [[ "${ERROR_MESSAGE}" != false ]]; then
            echo "${IAM_RESPONSE}" | jq '.errors'
            echo "Could not obtain api keys"
            exit 1
        fi

        next_url=$(echo "${IAM_RESPONSE}" | jq -r '.next')
        key_descriptions=$(echo "$IAM_RESPONSE" | jq -r --arg name "${APIKEY_KEY_NAME}" '.apikeys | .[] | select(.name == $name) | .description')
        for i in "${key_descriptions[@]}"; do
            if [[ "$i" =~ ${REGION} ]] && [[ "$i" =~ ${RESOURCE_GROUP_ID} ]]; then
                echo "Found key named ${APIKEY_KEY_NAME} which covers clusters in ${REGION} and resource group ${RESOURCE_GROUP_NAME} (ID: ${RESOURCE_GROUP_ID})"
                reset=false
                break
            fi
        done
        url=$next_url
    done
}

get_resource_group_id() {
    local rg_name="$1"

    # Determine the Resource Manager API endpoint
    rc_api_endpoint="${IBMCLOUD_RESOURCE_CONTROLLER_API_ENDPOINT:-"resource-controller.cloud.ibm.com"}"
    rc_api_endpoint=${rc_api_endpoint#https://}

    if [ "$PRIVATE_ENV" = true ]; then
        RC_URL="https://private.$rc_api_endpoint/v2/resource_groups?account_id=$ACCOUNT_ID"
    else
        RC_URL="https://$rc_api_endpoint/v2/resource_groups?account_id=$ACCOUNT_ID"
    fi

    echo "Looking up resource group ID for name: $rg_name" >&2

    # Fetch resource groups from the API
    RC_RESPONSE=$(curl -s "$RC_URL" --header "Authorization: Bearer $IAM_TOKEN" --header "Content-Type: application/json")

    ERROR_MESSAGE=$(echo "${RC_RESPONSE}" | jq 'has("errors")')
    if [[ "${ERROR_MESSAGE}" != false ]]; then
        echo "${RC_RESPONSE}" | jq '.errors' >&2
        echo "Could not obtain resource groups" >&2
        exit 1
    fi

    # Extract the resource group ID for the given name
    RESOURCE_GROUP_ID=$(echo "$RC_RESPONSE" | jq -r --arg name "$rg_name" '.resources[] | select(.name == $name) | .id')

    if [[ -z "${RESOURCE_GROUP_ID}" ]] || [[ "${RESOURCE_GROUP_ID}" == "null" ]]; then
        echo "Resource group with name '$rg_name' not found" >&2
        exit 1
    fi

    echo "Found resource group ID: $RESOURCE_GROUP_ID" >&2
    echo "$RESOURCE_GROUP_ID"
}

#######################################################

# Determine endpoints to use
get_cloud_endpoint

# Generate IAM access token
IAM_RESPONSE=$(curl -s --request POST \
"https://${IBMCLOUD_IAM_API_ENDPOINT}/identity/token" \
--header 'Content-Type: application/x-www-form-urlencoded' \
--header 'Accept: application/json' \
--data-urlencode 'grant_type=urn:ibm:params:oauth:grant-type:apikey' --data-urlencode 'apikey='"${IBMCLOUD_API_KEY}")

ERROR_MESSAGE=$(echo "${IAM_RESPONSE}" | jq 'has("errorMessage")')
if [[ "${ERROR_MESSAGE}" != false ]]; then
    echo "${IAM_RESPONSE}" | jq '.errorMessage'
    echo "Could not obtain an access token"
    exit 1
fi

IAM_TOKEN=$(echo "${IAM_RESPONSE}" | jq -r '.access_token')

# Convert resource group name to ID
RESOURCE_GROUP_ID=$(get_resource_group_id "$RESOURCE_GROUP_NAME")

if [ "$IBMCLOUD_IAM_API_ENDPOINT" = "iam.cloud.ibm.com" ]; then
    if [ "$PRIVATE_ENV" = true ]; then
        IAM_URL="https://private.$IBMCLOUD_IAM_API_ENDPOINT/v1/apikeys?account_id=$ACCOUNT_ID&scope=account&pagesize=100&type=user&sort=name"
    else
        IAM_URL="https://$IBMCLOUD_IAM_API_ENDPOINT/v1/apikeys?account_id=$ACCOUNT_ID&scope=account&pagesize=100&type=user&sort=name"
    fi
else
    IAM_URL="https://$IBMCLOUD_IAM_API_ENDPOINT/v1/apikeys?account_id=$ACCOUNT_ID&scope=account&pagesize=100&type=user&sort=name"
fi

# Check existing apikeys
fetch_data

attempt=0
retry_wait_time=5
reset=true
if [ "${reset}" == true ]; then
    while [ $attempt -lt $MAX_ATTEMPTS ]; do
        if [ "$IBMCLOUD_CS_API_ENDPOINT" = "containers.cloud.ibm.com" ]; then
            if [ "$PRIVATE_ENV" = true ]; then
                if [ "$CLUSTER_ENDPOINT" == "private" ] || [ "$CLUSTER_ENDPOINT" == "default" ]; then
                    RESET_URL="https://private.$REGION.$IBMCLOUD_CS_API_ENDPOINT/v1/keys"
                    result=$(curl -i -H "accept: application/json" -H "Authorization: Bearer $IAM_TOKEN" -H "X-Auth-Resource-Group: $RESOURCE_GROUP_ID" -X POST "$RESET_URL" 2>/dev/null)
                    status_code=$(echo "$result" | head -n 1 | cut -d$' ' -f2)
                elif [ "$CLUSTER_ENDPOINT" == "vpe" ]; then
                    RESET_URL="https://api.$REGION.$IBMCLOUD_CS_API_ENDPOINT/v1/keys"
                    result=$(curl -i -H "accept: application/json" -H "Authorization: Bearer $IAM_TOKEN" -H "X-Auth-Resource-Group: $RESOURCE_GROUP_ID" -X POST "$RESET_URL" 2>/dev/null)
                    status_code=$(echo "$result" | head -n 1 | cut -d$' ' -f2)
                fi
            else
                RESET_URL="https://$IBMCLOUD_CS_API_ENDPOINT/global/v1/keys"
                result=$(curl -i -H "accept: application/json" -H "X-Region: $REGION" -H "Authorization: Bearer $IAM_TOKEN" -H "X-Auth-Resource-Group: $RESOURCE_GROUP_ID" -X POST "$RESET_URL" -d '' 2>/dev/null)
                status_code=$(echo "$result" | head -n 1 | cut -d$' ' -f2)
            fi
        else
            RESET_URL="https://$IBMCLOUD_CS_API_ENDPOINT/global/v1/keys"
            result=$(curl -i -H "accept: application/json" -H "X-Region: $REGION" -H "Authorization: Bearer $IAM_TOKEN" -H "X-Auth-Resource-Group: $RESOURCE_GROUP_ID" -X POST "$RESET_URL" -d '' 2>/dev/null)
            status_code=$(echo "$result" | head -n 1 | cut -d$' ' -f2)
        fi

        if [ "${status_code}" == "204" ] || [ "${status_code}" == "200" ]; then
            echo "The IAM API key is successfully reset."
            sleep 10
            exit 0
        else
            echo "ERROR:: FAILED TO RESET THE IAM API KEY"
            echo "$result"
            sleep $retry_wait_time
            ((attempt++))
        fi
        # sleep for 10 secs to allow the new key to be replicated across backend DB instances before attempting to create cluster
    done
    echo "Maximum retry attempts reached. Could not reset api key."
    exit 1
fi
