#!/bin/bash -e

# Enables a stream of a module, so that the packages of the module come from this stream, e.g. enable-dnf-module php remi-8.4
moduleName="${1}"
streamName="${2}"

if [[ -z "${moduleName}" ]] || [[ -z "${streamName}" ]]; then
  >&2 echo "usage: enable-dnf-module <module> <stream>"
  exit 1
fi

if dnf -q module list --enabled "${moduleName}" 2>/dev/null | awk -v moduleName="${moduleName}" -v streamName="${streamName}" '$1 == moduleName && $2 == streamName { found = 1 } END { exit !found }'; then
  echo "Module ${moduleName}:${streamName} already enabled"
  exit 0
fi

echo "Enabling module: ${moduleName}:${streamName}"
dnf module reset -y "${moduleName}" 2>&1
dnf module enable -y "${moduleName}:${streamName}" 2>&1
