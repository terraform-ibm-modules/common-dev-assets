#! /bin/bash

set -e

trivy config . --exit-code 1 --severity CRITICAL,HIGH,LOW  --skip-files "**/.terraform/**/*"
