#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -u  Name of user to ensure
  -i  Id of user to ensure
  -g  Name of group to ensure
  -d  Id of group to ensure
  -v  Verbose

Example: ${scriptName} -u username
EOF
}

trim()
{
  echo -n "$1" | xargs
}

userName=
userId=
groupName=
groupId=
verbose=0

while getopts hu:i:g:d:v? option; do
  case ${option} in
    h) usage; exit 1;;
    u) userName=$(trim "$OPTARG");;
    i) userId=$(trim "$OPTARG");;
    g) groupName=$(trim "$OPTARG");;
    d) groupId=$(trim "$OPTARG");;
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
  if [[ -n "${userId}" ]]; then
    if [[ $(getent passwd | cat | tr ':' ' ' | awk '{print $3}' | grep -e "^${userId}$" | wc -l) -eq 0 ]]; then
      echo "Creating user with id: ${userId} and name: ${userName}"
      if [[ $(getent group "${userName}" | wc -l) -gt 0 ]]; then
        useradd -m -u "${userId}" -g "${userName}" -s /bin/bash "${userName}"
      else
        useradd -m -u "${userId}" -s /bin/bash "${userName}"
      fi
    else
      echo "Changing user with id: ${userId} to name: ${userName}"
      oldUserName=$(getent passwd "${userId}" | cat | tr ':' ' ' | awk '{print $1}')
      usermod -l "${userName}" "${oldUserName}"
    fi
  else
    echo "Creating user: ${userName}"
    if [[ $(getent group "${userName}" | wc -l) -gt 0 ]]; then
      useradd -m -g "${userName}" -s /bin/bash "${userName}"
    else
      useradd -m -s /bin/bash "${userName}"
    fi
  fi
elif [[ -n "${userId}" ]]; then
  if [[ $(getent passwd | cat | tr ':' ' ' | awk '{print $3}' | grep -e "^${userId}$" | wc -l) -eq 0 ]]; then
    echo "Changing user with name: ${userName} to id: ${userId}"
    usermod -u "${userId}" "${userName}"
  else
    if [[ $(getent passwd "${userId}" | cat | tr ':' ' ' | awk '{print $1}') == "${userName}" ]]; then
      if [[ "${verbose}" == 1 ]]; then
        echo "User: ${userName} already exists"
      fi
    else
      >&2 echo "Cannot change user with name: ${userName} to id: ${userId} because the id is already in use"
      exit 1
    fi
  fi
elif [[ "${verbose}" == 1 ]]; then
  echo "User: ${userName} already exists"
fi

if [[ -n "${groupName}" ]]; then
  echo "Ensuring group: ${groupName}"
  if [[ $(getent group | cat | tr ':' ' ' | awk '{print $1}' | grep -e "^${groupName}$" | wc -l) -eq 0 ]]; then
    if [[ -n "${groupId}" ]]; then
      if [[ $(getent group | cat | tr ':' ' ' | awk '{print $3}' | grep -e "^${groupId}$" | wc -l) -eq 0 ]]; then
        echo "Creating group with id: ${groupId} and name: ${groupName}"
        groupadd -g "${groupId}" "${groupName}"
      else
        echo "Changing group with id: ${groupId} to name: ${groupName}"
        oldGroupName=$(getent group "${groupId}" | cat | tr ':' ' ' | awk '{print $1}')
        groupmod -n "${groupName}" "${oldGroupName}"
      fi
    else
      echo "Creating new group: ${groupName}"
      groupadd "${groupName}"
    fi
  elif [[ -n "${groupId}" ]]; then
    if [[ $(getent group | cat | tr ':' ' ' | awk '{print $3}' | grep -e "^${groupId}$" | wc -l) -eq 0 ]]; then
      echo "Changing group with name: ${groupName} to id: ${groupId}"
      groupmod -g "${groupId}" "${groupName}"
    else
      if [[ $(getent group "${groupId}" | cat | tr ':' ' ' | awk '{print $1}') == "${groupName}" ]]; then
        if [[ "${verbose}" == 1 ]]; then
          echo "Group: ${userName} already exists"
        fi
      else
      >&2 echo "Cannot change group with name: ${groupName} to id: ${groupId} because the id is already in use"
        exit 1
      fi
    fi
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
