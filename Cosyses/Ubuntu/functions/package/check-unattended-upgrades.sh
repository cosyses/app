#!/bin/bash -e

apt=$(which apt)

if [[ -n "${apt}" ]]; then
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
