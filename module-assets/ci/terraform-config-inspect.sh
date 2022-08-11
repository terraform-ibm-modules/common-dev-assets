#!/bin/bash
set -e

"$HOME"/go/bin/terraform-config-inspect --json > module-metadata.json
