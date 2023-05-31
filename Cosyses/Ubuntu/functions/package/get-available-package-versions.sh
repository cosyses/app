#!/bin/bash -e

function quoteRegex()
{
  sed 's/[]\.\/|$(){}?+*^[]/\\&/g' <<< "$*" | sed 's/ /\\\s*/g'
}

packageName="${1}"
baseVersion="${2}"

if [ -n "${baseVersion}" ]; then
  baseVersion=$(quoteRegex "${2}")
fi

while read -r line; do
  exploded=($(echo "${line}" | tr "|" "\n"))
  if [ -n "${baseVersion}" ]; then
    if [ "$(echo "${exploded[1]}" | grep -P "^${baseVersion}" | wc -l )" -gt 0 ]; then
      echo "${exploded[1]}"
    fi
  else
    echo "${exploded[1]}"
  fi
done < <(apt-cache madison "${packageName}" | sort -rV)
