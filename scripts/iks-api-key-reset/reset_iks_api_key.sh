#!/bin/bash
#
# Usage: ./reset_iks_api_key.sh <region> <resource_group_name>
#
# Description:
#   Resets the IBM Cloud Kubernetes Service (IKS) API key for a specific region and resource group.
#   The script checks if an API key already exists for the given region and resource group combination.
#   If no key exists, it creates a new one.
#
# Prerequisites:
#   - IBMCLOUD_API_KEY environment variable must be set with a valid IBM Cloud API key
#   - IBM Cloud CLI (ibmcloud) must be installed
#   - jq must be installed for JSON parsing
#
# Arguments:
#   region              - IBM Cloud region (e.g., us-south, eu-gb)
#   resource_group_name - Name of the resource group
#
# Example:
#   export IBMCLOUD_API_KEY="your-api-key-here"
#   ./reset_iks_api_key.sh us-south my-resource-group
#

set -euo pipefail

REGION="${1:-}"
RESOURCE_GROUP_NAME="${2:-}"
APIKEY_KEY_NAME="containers-kubernetes-key"

# Validate args
if [[ -z "${IBMCLOUD_API_KEY:-}" ]]; then
    echo "API key must be set with IBMCLOUD_API_KEY environment variable"
    exit 1
fi

if [[ -z "${REGION}" ]]; then
    echo "Region must be passed as first input script argument"
    exit 1
fi

if [[ -z "${RESOURCE_GROUP_NAME}" ]]; then
    echo "Resource group name must be passed as second input script argument"
    exit 1
fi

# Login to ibmcloud with cli and target the resource group
attempts=1
max_attempts=3
until ibmcloud login -q -r "${REGION}" -g "${RESOURCE_GROUP_NAME}" || [ $attempts -gt $max_attempts ]; do
    if [ $attempts -lt $max_attempts ]; then
        echo "Error logging in to IBM Cloud CLI (attempt ${attempts}/${max_attempts}), retrying in 5 seconds..."
        sleep 5
    fi
    attempts=$((attempts+1))
done

if [ $attempts -gt $max_attempts ]; then
    echo "Failed to login to IBM Cloud CLI after ${max_attempts} attempts"
    exit 1
fi
echo "Successfully logged in to IBM Cloud CLI"

# Get resource group id with retry logic
attempts=1
max_attempts=3
RESOURCE_GROUP_ID=""
until [[ -n "${RESOURCE_GROUP_ID}" ]] || [ $attempts -gt $max_attempts ]; do
    echo "Attempting to get resource group ID (attempt ${attempts}/${max_attempts})..."
    RESOURCE_GROUP_ID=$(ibmcloud resource group "${RESOURCE_GROUP_NAME}" --output json | jq -r '.[].id // empty' 2>/dev/null || echo "")
    if [[ -z "${RESOURCE_GROUP_ID}" ]]; then
        if [ $attempts -lt $max_attempts ]; then
            echo "Failed to get resource group ID, retrying in 5 seconds..."
            sleep 5
        fi
        attempts=$((attempts+1))
    fi
done

if [[ -z "${RESOURCE_GROUP_ID}" ]]; then
    echo "Could not find resource group ID for ${RESOURCE_GROUP_NAME} after ${max_attempts} attempts"
    exit 1
fi
echo "Successfully retrieved resource group ID: ${RESOURCE_GROUP_ID}"

# check if containers api key already exists for the given region and resource group
reset=true
key_descriptions=()
while IFS='' read -r line; do key_descriptions+=("$line"); done < <(ibmcloud iam api-keys --all --output json | jq -r --arg name "${APIKEY_KEY_NAME}" '.[] | select(.name == $name) | .description')
for i in "${key_descriptions[@]}"; do
  if [[ "$i" =~ ${REGION} ]] && [[ "$i" =~ ${RESOURCE_GROUP_ID} ]]; then
    echo "Found key named ${APIKEY_KEY_NAME} which covers clusters in ${REGION} and resource group ${RESOURCE_GROUP_NAME} (${RESOURCE_GROUP_ID})"
    reset=false
    break
  fi
done

# create the key if one does not already exist
if [ "${reset}" == true ]; then
  echo "y" | ibmcloud ks api-key reset --region "${REGION}"
  sleep 10
fi
