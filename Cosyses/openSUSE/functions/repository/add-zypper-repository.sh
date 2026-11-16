#!/bin/bash -e

repositoryAlias="${1}"
repositoryUrl="${2}"
keyUrl="${3}"

if [[ -z "${repositoryAlias}" ]] || [[ -z "${repositoryUrl}" ]]; then
  >&2 echo "usage: add-zypper-repository <alias> <url> [<keyUrl>]"
  exit 1
fi

if zypper --non-interactive repos "${repositoryAlias}" >/dev/null 2>&1; then
  echo "Repository ${repositoryAlias} already installed"
  exit 0
fi

if [[ -n "${keyUrl}" ]]; then
  echo "Importing repository key from: ${keyUrl}"
  rpm --import "${keyUrl}"
fi

echo "Installing repository: ${repositoryAlias} with url: ${repositoryUrl}"
zypper --non-interactive addrepo --refresh "${repositoryUrl}" "${repositoryAlias}" 2>&1

# Without a key URL, the key of the repository is trusted on the first refresh
zypper --non-interactive --gpg-auto-import-keys refresh "${repositoryAlias}" 2>&1
