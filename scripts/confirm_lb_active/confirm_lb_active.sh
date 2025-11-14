#!/bin/bash

set -euo pipefail

REGION="$1"
LB_ID="$2"
PRIVATE_ENV="$3"
API_VERSION="2024-03-01"

if [[ -z "${REGION}" ]]; then
    echo "Region must be passed as first input script argument" >&2
    exit 1
fi

get_cloud_endpoint() {
    cloud_endpoint="${IBMCLOUD_IS_NG_API_ENDPOINT:-"iaas.cloud.ibm.com"}"
    IBMCLOUD_IS_NG_API_ENDPOINT=${cloud_endpoint#https://}
}

get_cloud_endpoint

lb_attempts=1
if [ "$IBMCLOUD_IS_NG_API_ENDPOINT" = "iaas.cloud.ibm.com" ]; then
    if [ "$PRIVATE_ENV" = true ]; then
        URL="https://$REGION.private.$IBMCLOUD_IS_NG_API_ENDPOINT/v1/load_balancers/$LB_ID?version=$API_VERSION&generation=2"
    else
        URL="https://$REGION.$IBMCLOUD_IS_NG_API_ENDPOINT/v1/load_balancers/$LB_ID?version=$API_VERSION&generation=2"
    fi
else
    URL="https://$IBMCLOUD_IS_NG_API_ENDPOINT/v1/load_balancers/$LB_ID?version=$API_VERSION&generation=2"
fi

while true; do
    STATUS=$(curl -H "Authorization: $IAM_TOKEN" -X GET "$URL" | jq -r '.operating_status')
    echo "Load balancer status: $STATUS"
    if [[ "$STATUS" == "online" ]]; then
        sleep 300
        STATUS=$(curl -H "Authorization: $IAM_TOKEN" -X GET "$URL" | jq -r '.operating_status')
        if [[ "$STATUS" == "online" ]]; then
            break
        fi
    else
        lb_attempts=$((lb_attempts + 1))
        if [ $lb_attempts -ge 10 ]; then
            echo "Load balancer status: $STATUS"
            break
        fi
        echo "Sleeping for 30 secs.."
        sleep 30
    fi
    STATUS=""
done
