#! /bin/bash

set -e

version="$1"

if [ -z "${ARTIFACTORY_USERNAME}" ]; then echo "Error: ARTIFACTORY_USERNAME is undefined"; exit 1; fi
if [ -z "${ARTIFACTORY_PASSWORD}" ]; then echo "Error: ARTIFACTORY_PASSWORD is undefined"; exit 1; fi
if [ -z "${ARTIFACTORY_URL}" ]; then echo "Error: ARTIFACTORY_URL is undefined"; exit 1; fi
if [ -z "${ARTIFACTORY_GO_REPO}" ]; then echo "Error: ARTIFACTORY_GO_REPO is undefined"; exit 1; fi

# check incoming version maches semver style (v.x.x.x)
# (regex based on official semver: https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string)
if ! [[ $version =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$ ]]; then echo "Error: Version is not in semver format"; exit 1; fi

# jfrog CLI v2.x requires three steps to publish Go modules:
# 1. configure server with ID
# 2. configure Go build/publish to ID
# 3. publish

jfrog config add goldeneye_go_publish --url "$ARTIFACTORY_URL" --user "$ARTIFACTORY_USERNAME" --password "$ARTIFACTORY_PASSWORD" --interactive=false
jfrog go-config --repo-resolve "$ARTIFACTORY_GO_REPO" --repo-deploy "$ARTIFACTORY_GO_REPO" --server-id-resolve goldeneye_go_publish --server-id-deploy goldeneye_go_publish
jfrog go-publish "$version"
