#!/bin/bash -e

apt=$(which apt)

# Without ps (e.g. on Debian before procps is installed) there is nothing to wait for
if [[ -n "${apt}" ]] && [[ -x "$(command -v ps)" ]]; then
  first=1

  while [[ $(ps aux | grep -i "${apt}" | grep -v grep | wc -l) -gt 0 ]] || [[ $(ps aux | grep -i "apt.systemd.daily lock_is_held" | grep -v grep | wc -l) -gt 0 ]]; do
    if [[ "${first}" == 1 ]]; then
     echo -n "System not ready"
    else
      echo -n "."
    fi
    sleep 1
    first=0
  done

  if [[ "${first}" == 0 ]]; then
    echo ""
  fi
fi
