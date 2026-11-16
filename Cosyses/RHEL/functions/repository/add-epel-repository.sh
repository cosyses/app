#!/bin/bash -e

# Adds EPEL (Extra Packages for Enterprise Linux) on RHEL and its rebuilds, Fedora contains these packages itself
distributionId=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')

if [[ "${distributionId}" == "fedora" ]]; then
  echo "Fedora needs no EPEL repository"
  exit 0
fi

majorRelease=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | tr -d '"' | cut -d. -f1)

add-repository-package epel-release "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${majorRelease}.noarch.rpm"
