#!/bin/bash -e

currentUser=$(whoami)

home=$(awk -F: -v u="${currentUser}" '$1==u{print $6}' /etc/passwd)

if [[ -f ${home}/.ssh/id_rsa.pub ]]; then
  cat "${home}/.ssh/id_rsa.pub"
fi
