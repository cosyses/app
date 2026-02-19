#!/bin/bash -e

currentUser=$(whoami)

home=$(awk -F: -v u="${currentUser}" '$1==u{print $6}' /etc/passwd)
echo "User home at: ${home}"

if [[ ! -f ${home}/.ssh/id_rsa ]] && [[ ! -f ${home}/.ssh/id_rsa.pub ]]; then
  if [[ ! -d "${home}" ]]; then
    echo "Creating directory at: ${home}"
    mkdir -p "${home}"
  fi
  if [[ ! -d "${home}/.ssh" ]]; then
    echo "Creating directory at: ${home}/.ssh"
    mkdir -m 700 "${home}/.ssh"
  fi
  ssh-keygen -b 4096 -t rsa -f "${home}/.ssh/id_rsa" -q -N ""
else
  echo "Key already exists"
fi
