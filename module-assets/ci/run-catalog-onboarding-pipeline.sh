#! /bin/bash

# This script is designed to run as a part of CI through the semantic release automation
# This script calls the webhook for the release pipeline in tekton with the parameters needed to onboard a release of a module to the catalog
# To run, call this script using the 'exec' plugin in your .releaserc, and provide the repo name, catalogID, offeringID, version, example, gitUrl (optional), gitOrg (optional) and prefix as parameters
# The webhook URL and token associated with the webhook must be provided via environment variables

repoName="$1"
catalogID="$2"
offeringID="$3"
version="$4"
target="$5"
example="${6:-none}"
gitUrl="${7:-github.ibm.com}"
gitOrg="${8:-GoldenEye}"
# This is the prefix on the programatic name in the catalog
prefix="${9:-goldeneye}"
use_catalog_source="${10:-true}"

if [ -z ${CATALOG_TEKTON_WEBHOOK_URL+x} ]; then echo "CATALOG_TEKTON_WEBHOOK_URL is unset"; else echo "CATALOG_TEKTON_WEBHOOK_URL is set"; fi
if [ -z ${CATALOG_TEKTON_WEBHOOK_TOKEN+x} ]; then echo "CATALOG_TEKTON_WEBHOOK_TOKEN is unset"; else echo "CATALOG_TEKTON_WEBHOOK_TOKEN is set"; fi

echo "$repoName"
echo "$catalogID"
echo "$offeringID"
echo "$version"
echo "$example"
echo "$gitUrl"
echo "$gitOrg"
echo "$prefix"
echo "$use_catalog_source"

echo "generating payload"
payload=$(jq -c -n --arg repoName "$repoName" --arg catalogID "$catalogID" --arg offeringID "$offeringID" --arg version "$version" --arg target "$target" --arg example "$example" --arg gitUrl "$gitUrl" --arg gitOrg "$gitOrg" --arg prefix "$prefix" '{"repo-name": $repoName, "catalog-id": $catalogID, "offering-id": $offeringID, "version": $version, "target": $target, "example": $example, "git-url": $gitUrl, "git-org": $gitOrg, "prefix": $prefix, "use_catalog_source": $use_catalog_source}')
echo "$payload"

echo "kicking off tekton pipeline"
curl -X POST \
"$CATALOG_TEKTON_WEBHOOK_URL" \
-H "Content-Type: application/json" \
-H "token: ${CATALOG_TEKTON_WEBHOOK_TOKEN}" \
-d "$payload"
