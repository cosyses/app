#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} <version1> <operator> <version2>

Compares two versions in the order of sort -V and exits with 0 if the comparison holds, else with 1.
Operators: -lt, -le, -eq, -ne, -ge, -gt (or <, <=, ==, !=, >=, >)

Example: if ${scriptName} 2.4.8-p3 -ge 2.4.6; then echo "2.4.6 or newer"; fi
EOF
}

if [[ "$#" -ne 3 ]]; then
  usage
  exit 2
fi

version1="${1}"
operator="${2}"
version2="${3}"

if [[ "${version1}" == "${version2}" ]]; then
  result=0
elif [[ "${version1}" == "$(printf '%s\n%s\n' "${version1}" "${version2}" | sort -V | head -n 1)" ]]; then
  result=-1
else
  result=1
fi

case "${operator}" in
  -lt|"<") [[ "${result}" -lt 0 ]] ;;
  -le|"<=") [[ "${result}" -le 0 ]] ;;
  -eq|"=="|"=") [[ "${result}" -eq 0 ]] ;;
  -ne|"!=") [[ "${result}" -ne 0 ]] ;;
  -ge|">=") [[ "${result}" -ge 0 ]] ;;
  -gt|">") [[ "${result}" -gt 0 ]] ;;
  *) >&2 echo "Invalid operator: ${operator}"; usage; exit 2 ;;
esac
