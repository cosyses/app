#!/bin/bash -e

packageName="${1}"
version="${2}"

installedVersion=$(pecl list | grep -P "^${packageName}\s" | grep -ohP "[0-9]+(\.[0-9]+)*" | cat)

if [ "$version" == "$installedVersion" ]; then
  echo "Latest PECL package ${packageName}=${version} already installed"
else
  echo "Installing PECL latest package ${packageName}=${version}"
  yes '' | pecl install -f "${packageName}-${version}"
fi
