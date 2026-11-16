#!/bin/bash -e

# Installs a package that adds repositories, e.g. add-repository-package epel-release https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
packageName="${1}"
packageUrl="${2}"

if [[ -z "${packageName}" ]] || [[ -z "${packageUrl}" ]]; then
  >&2 echo "usage: add-repository-package <packageName> <packageUrl>"
  exit 1
fi

if rpm -q "${packageName}" >/dev/null 2>&1; then
  echo "Repository package ${packageName} already installed"
  exit 0
fi

echo "Installing repository package: ${packageName} from: ${packageUrl}"
dnf install -y "${packageUrl}" 2>&1
