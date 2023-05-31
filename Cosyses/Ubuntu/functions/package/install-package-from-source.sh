#!/bin/bash -e

packageName="${1}"
version="${2}"
uri="${3}"

installedVersion=$(get-installed-package-version "${packageName}")

if [ "${version}" == "${installedVersion}" ]; then
  echo "Package ${packageName}=${version} already installed"
else
  echo "Installing package ${packageName}=${version}"
  mkdir -p /tmp/install-package-from-source
  cd /tmp/install-package-from-source
  wget -qO- "${uri}" | tar xzpf -
  if [ ! -f configure ]; then
    extractedFolder=$(find /tmp/install-package-from-source/* -maxdepth 0 -type d)
    cd "${extractedFolder}"
  fi
  ./configure
  make all install
  cd /
  rm -rf /tmp/install-package-from-source
fi
