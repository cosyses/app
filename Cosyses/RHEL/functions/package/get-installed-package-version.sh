#!/bin/bash -e

packageName="${1}"

if rpm -q "${packageName}" >/dev/null 2>&1; then
  rpm -q --qf "%{VERSION}-%{RELEASE}\n" "${packageName}" | sort -rV | head -n 1 | tr -d '\n'
fi
