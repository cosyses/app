#!/bin/bash -e

repositoryUrl="${1}"
keyUrl="${2}"

if grep -qxF "${repositoryUrl}" /etc/apk/repositories; then
  echo "Repository ${repositoryUrl} already installed"
  exit 0
fi

if [[ -n "${keyUrl}" ]]; then
  echo "Installing repository key from: ${keyUrl}"
  wget -q -O "/etc/apk/keys/$(basename "${keyUrl}")" "${keyUrl}"
fi

echo "Installing repository: ${repositoryUrl}"
echo "${repositoryUrl}" >> /etc/apk/repositories

update-packages
