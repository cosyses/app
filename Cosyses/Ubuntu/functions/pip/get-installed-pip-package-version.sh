#!/bin/bash -e

packageName="${1}"

pip list | tail -n +3 | grep -E "^${packageName}" | awk '{print $2}'
