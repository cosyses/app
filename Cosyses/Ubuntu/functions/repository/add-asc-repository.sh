#!/bin/bash -e

aptFileName="/etc/apt/sources.list.d/${1}"
repoUri="${2}"
distribution="${3}"
component="${4}"
keyUri="${5}"
addSource="${6}"

binaryEntry="deb ${repoUri} ${distribution} ${component}"
sourceEntry="deb-src ${repoUri} ${distribution} ${component}"

if [ -f "${aptFileName}" ]; then
  if [ "$(grep -Fx "${binaryEntry}" "${aptFileName}" | wc -l)" -gt 0 ]; then
    echo "Repository ${2} already installed"
    exit 0
  fi
fi

echo "Installing repository: ${2}"
if [[ -n "${keyUri}" ]]; then
  keyName=$(basename "${keyUri}")
  wget -qO- "${keyUri}" | tee "/etc/apt/trusted.gpg.d/${keyName}.asc"
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
