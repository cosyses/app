#!/bin/bash -e

function quoteRegex()
{
  sed 's/[]\.\/|$(){}?+*^[]/\\&/g' <<< "$*" | sed 's/ /\\\s*/g'
}

packageName="${1}"
baseVersion="${2}"

if [[ -z "${packageName}" ]]; then
  >&2 echo "No package name specified!"
  exit 1
fi

if [[ -n "${baseVersion}" ]]; then
  baseVersion=$(quoteRegex "${2}")
fi

while read -r version; do
  if [ -n "${baseVersion}" ]; then
    if [ "$(echo "${version}" | grep -P "^${baseVersion}" | wc -l )" -gt 0 ]; then
      echo "${version}"
    fi
  else
    echo "${version}"
  fi
done < <(npm view "${packageName}" versions --json | tail -n +2 | head -n -1 | sed -r 's/\s*\"(.*)\".*/\1/' | sort -rV)
