#!/bin/bash
set -e

terraform-config-inspect --json > module-metadata.json
