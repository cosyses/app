#!/bin/bash -e

# Adds the repositories of Remi Collet (rpms.remirepo.net), which have every PHP version for RHEL and Fedora
distributionId=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
versionId=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | tr -d '"')

if [[ "${distributionId}" == "fedora" ]]; then
  add-repository-package remi-release "https://rpms.remirepo.net/fedora/remi-release-${versionId}.rpm"
else
  # The packages of Remi need some of EPEL
  add-epel-repository
  add-repository-package remi-release "https://rpms.remirepo.net/enterprise/remi-release-${versionId%%.*}.rpm"
fi
