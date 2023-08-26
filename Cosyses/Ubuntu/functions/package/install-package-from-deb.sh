#!/bin/bash -e

packageName="${1}"
version="${2}"
uri="${3}"

install-package gnupg

installedVersion=$(get-installed-package-version "${packageName}")

if [ "$version" == "$installedVersion" ]; then
  echo "Package ${packageName}=${version} already installed"
else
  echo "Installing package ${packageName}=${version}"
  wget -nv "${uri}" -P /tmp
  dpkg --install "/tmp/${uri##*/}"
  rm -rf "/tmp/${uri##*/}"
fi
