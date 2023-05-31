#!/bin/bash -e

currentUser=$(whoami)

home=$(awk -F: -v u="${currentUser}" '$1==u{print $6}' /etc/passwd)

if [[ ! -f ${home}/.ssh/id_rsa ]] && [[ ! -f ${home}/.ssh/id_rsa.pub ]]; then
  ssh-keygen -b 4096 -t rsa -f "${home}/.ssh/id_rsa" -q -N ""
else
  echo "Key already exists"
fi
