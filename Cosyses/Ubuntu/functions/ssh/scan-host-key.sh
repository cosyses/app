#!/bin/bash -e

host="${1}"
type="${2}"

if [[ -n "${host}" ]]; then
  echo "Checking host: ${host}"

  if [[ -z "${type}" ]]; then
    type="rsa,dsa"
  fi
  ssh-keyscan -t "${type}" "${host}" >> ~/.ssh/known_hosts
else
  >&2 echo "No host to scan"
  exit 1
fi
