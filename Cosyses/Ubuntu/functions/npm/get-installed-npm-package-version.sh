#!/bin/bash -e

packageName="${1}"
global="${2}"

if [[ "${global}" == 1 ]] || [[ "${global}" == "y" ]] || [[ "${global}" == "yes" ]]; then
  command="npm list -g --depth=0"
else
  command="npm list --depth=0"
fi

package=$(${command} | grep -E "." | awk '{print $2}' | grep -E "^${packageName}" | cat)

if [[ -n "${package}" ]]; then
  echo "${package}" | sed -r 's/.*@(.*)/\1/'
fi
