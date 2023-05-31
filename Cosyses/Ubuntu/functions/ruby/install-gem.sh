#!/bin/bash -e

gemName="${1}"
baseVersion="${2}"

latestVersion=$(get-latest-gem-version "${gemName}" "${baseVersion}")
installedVersion=$(get-installed-gem-version "${gemName}")

if [ -z "${latestVersion}" ]; then
  >&2 echo "Could not find latest version of gem: ${gemName}"
  echo "Possible candidates:"
  gem list --remote --all "${gemName}" | grep -P "^${gemName}\s" | grep -ohP "[0-9]+(\.[0-9]+)*" | sort -rV | uniq
  exit 1
fi

if [ "$latestVersion" == "$installedVersion" ]; then
  echo "Latest gem ${gemName}=${latestVersion} already installed"
else
  echo "Installing latest gem ${gemName}=${latestVersion}"
  gem install "${gemName}" -v "${latestVersion}"
fi
