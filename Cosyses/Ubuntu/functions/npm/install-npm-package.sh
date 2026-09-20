#!/bin/bash -e

packageName="${1}"
global="${2}"
baseVersion="${3}"

latestVersion=$(get-latest-npm-package-version "${packageName}" "${baseVersion}")

if [[ "${global}" == 1 ]] || [[ "${global}" == "y" ]] || [[ "${global}" == "yes" ]]; then
  installedVersion=$(get-installed-npm-package-version "${packageName}" "y")
else
  installedVersion=$(get-installed-npm-package-version "${packageName}")
fi

if [[ -z "${latestVersion}" ]]; then
  echo "Could not find latest version of npm package: ${packageName}"
  echo "Possible candidates:"
  echo get-available-npm-package-versions "${packageName}" | tr " " "\n" | sort -rV | uniq
  exit 1
fi

if [[ "${latestVersion}" == "${installedVersion}" ]]; then
  echo "Latest npm package ${packageName}=${latestVersion} already installed"
else
  if [[ "${global}" == 1 ]] || [[ "${global}" == "y" ]] || [[ "${global}" == "yes" ]]; then
    echo "Installing global npm package ${packageName}=${latestVersion}"
    npm install -g "${packageName}"@"${latestVersion}"
  else
    echo "Installing npm package ${packageName}=${latestVersion}"
    npm install "${packageName}"@"${latestVersion}"
  fi
fi
