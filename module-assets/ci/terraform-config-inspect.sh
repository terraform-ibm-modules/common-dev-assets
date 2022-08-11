#!/bin/bash
set -e

go mod download
"$HOME"/go/bin/terraform-config-inspect --json > module-metadata.json
