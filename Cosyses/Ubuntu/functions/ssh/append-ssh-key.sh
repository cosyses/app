#!/bin/bash -e

file="${1}"
shift

echo "Using file: ${file}"
while [ "${1}" ]; do
  home=$(awk -F: -v u="${1}" '$1==u{print $6}' /etc/passwd)
  echo "User home at: ${home}"

  fileName=$(basename "${file}")
  echo "Using file name: ${fileName}"

  if [[ ! -d "${home}/.ssh" ]]; then
    echo "Creating directory at: ${home}/.ssh"
    mkdir -m 700 "${home}/.ssh"
  fi

  echo "Checking authorization file at: ${home}/.ssh/authorized_keys"
  touch "${home}/.ssh/authorized_keys"

  echo "Adding public key to: ${home}/.ssh/authorized_keys"
  echo "# ${fileName}" >> "${home}/.ssh/authorized_keys"
  cat "${file}" >> "${home}/.ssh/authorized_keys"
  chmod 600 "${home}/.ssh/authorized_keys"
  chown "${1}": "${home}/.ssh/authorized_keys"

  shift
done
