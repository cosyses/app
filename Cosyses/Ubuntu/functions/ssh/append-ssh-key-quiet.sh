#!/bin/bash -e

file="${1}"
shift

while [ "${1}" ]; do
  home=$(awk -F: -v u="${1}" '$1==u{print $6}' /etc/passwd)
  fileName=$(basename "${file}")

  mkdir -p -m 700 "${home}/.ssh"
  touch "${home}/.ssh/authorized_keys"

  echo "# ${fileName}" >> "${home}/.ssh/authorized_keys"
  cat "${file}" >> "${home}/.ssh/authorized_keys"
  chmod 600 "${home}/.ssh/authorized_keys"
  chown "${1}": "${home}/.ssh/authorized_keys"

  shift
done
