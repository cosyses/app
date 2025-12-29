#!/bin/bash -e

aptFileName="/etc/apt/sources.list.d/${1}"
repoUri="${2}"
distribution="${3}"
component="${4}"
keyUri="${5}"
addSource="${6}"

if [[ -n "${keyUri}" ]]; then
  if [[ "${distribution}" == "/" ]]; then
    if [[ "${component}" == "/" ]]; then
      keyName="all-all-$(basename "${keyUri}")"
    else
      keyName="all-${component}-$(basename "${keyUri}")"
    fi
  else
    if [[ "${component}" == "/" ]]; then
      keyName="${distribution}-all-$(basename "${keyUri}")"
    else
      keyName="${distribution}-${component}-$(basename "${keyUri}")"
    fi
  fi
  if [[ "${distribution}" == "/" ]]; then
    binaryEntry="deb [signed-by=/etc/apt/keyrings/${keyName}] ${repoUri} /"
    sourceEntry="deb-src [signed-by=/etc/apt/keyrings/${keyName}] ${repoUri} /"
  else
    binaryEntry="deb [signed-by=/etc/apt/keyrings/${keyName}] ${repoUri} ${distribution} ${component}"
    sourceEntry="deb-src [signed-by=/etc/apt/keyrings/${keyName}] ${repoUri} ${distribution} ${component}"
  fi
else
  binaryEntry="deb ${repoUri} ${distribution} ${component}"
  sourceEntry="deb-src ${repoUri} ${distribution} ${component}"
fi

if [ -f "${aptFileName}" ]; then
  if [ "$(grep -Fx "${binaryEntry}" "${aptFileName}" | wc -l)" -gt 0 ]; then
    echo "Repository ${2} already installed"
    exit 0
  fi
fi

install-package gnupg
install-package software-properties-common
install-package wget

echo "Installing repository: ${2}"
if [[ -n "${keyUri}" ]]; then
  mkdir -p /etc/apt/keyrings
  if [[ -f "/etc/apt/keyrings/${keyName}" ]]; then
     rm -rf "/etc/apt/keyrings/${keyName}"
  fi
  wget -qO- "${keyUri}" | gpg --dearmor -o "/etc/apt/keyrings/${keyName}"
fi
if [ -f "${aptFileName}" ]; then
  echo "${binaryEntry}" >> "${aptFileName}"
else
  echo "${binaryEntry}" > "${aptFileName}"
fi
if [ "${addSource}" == "y" ]; then
  echo "${sourceEntry}" >> "${aptFileName}"
fi

update-packages
