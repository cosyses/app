#!/bin/bash -e

packageName="${1}"
version="${2}"

installedVersion=$(pear list | grep -P "^${packageName}\s" | grep -ohP "[0-9]+(\.[0-9]+)*" | cat)

if [ "$version" == "$installedVersion" ]; then
  echo "Latest PEAR package ${packageName}=${version} already installed"
else
  echo "Installing PEAR latest package ${packageName}=${version}"
  pear install "${packageName}-${version}"
fi
