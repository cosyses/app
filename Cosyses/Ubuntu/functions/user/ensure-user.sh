#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -u  User to prepare
  -g  Group of user to prepare
  -v  Verbose

Example: ${scriptName} -u username
EOF
}

trim()
{
  echo -n "$1" | xargs
}

userName=
groupName=
verbose=0

while getopts hu:g:v? option; do
  case ${option} in
    h) usage; exit 1;;
    u) userName=$(trim "$OPTARG");;
    g) groupName=$(trim "$OPTARG");;
    v) verbose=1;;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${userName}" ]]; then
  echo "No user name specified!"
  exit 1
fi

echo "Ensuring user: ${userName}"

if [[ $(getent passwd | cat | tr ':' ' ' | awk '{print $1}' | grep -e "^${userName}$" | wc -l) -eq 0 ]]; then
  echo "Creating user: ${userName}"
  if [[ $(getent group "${userName}" | wc -l) -gt 0 ]]; then
    useradd -m -g "${userName}" -s /bin/bash "${userName}"
  else
    useradd -m -s /bin/bash "${userName}"
  fi
elif [[ "${verbose}" == 1 ]]; then
  echo "User: ${userName} already exists"
fi

if [[ -n "${groupName}" ]]; then
  echo "Ensuring user group: ${groupName}"

  if [[ $(getent group | cat | tr ':' ' ' | awk '{print $1}' | grep -e "^${groupName}$" | wc -l) -eq 0 ]]; then
    echo "Creating new group: ${groupName}"
    groupadd "${groupName}"
  elif [[ "${verbose}" == 1 ]]; then
    echo "Group: ${groupName} already exists"
  fi

  groupCheck=$(id -nG "${userName}" | grep -w "${groupName}" | wc -l)

  if [[ "${groupCheck}" == 0 ]]; then
    echo "Adding user: ${userName} to group: ${groupName}"
    usermod -a -G "${groupName}" "${userName}"
  elif [[ "${verbose}" == 1 ]]; then
    echo "No need to add user: ${userName} to group: ${groupName}"
  fi
fi
