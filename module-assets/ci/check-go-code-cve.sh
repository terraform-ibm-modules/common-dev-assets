#!/bin/bash

if [[ -d tests ]];then
  trivy repo --severity HIGH,CRITICAL --exit-code 1 tests/
fi
