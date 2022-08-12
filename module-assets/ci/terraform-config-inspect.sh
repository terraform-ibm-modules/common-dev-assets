#!/bin/bash
set -e

/usr/local/bin/terraform-config-inspect --json > module-metadata.json
