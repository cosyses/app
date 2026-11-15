#!/bin/bash -e

set -o pipefail

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options [path:mode:flag ...]

Gives an application user (e.g. www-data) and the owner of paths mounted from the host into a container access to
these paths. The host user and group are created as docker_volume_<id> (an existing user or group with the id is
renamed), the application user and the host user become members of each other's group.

OPTIONS:
  -h  Show this message
  -u  Name of the application user, for example: www-data
  -i  Id of the host user
  -g  Id of the group of the host user, default: id of the host user
  -p  Comma separated paths to check and modify for access (path:mode:flag), can be used multiple times,
      paths can also be given as arguments after the options
  -f  Prepare the users again even if they were already prepared in this container
  -v  Verbose

Every path is given as path:mode:flag:
  mode  first letter: access to the path itself, r (read), w (write) or e (execute)
        second letter: access to everything below a directory, r, w, e or + (the same as the first letter);
        without a second letter only the path itself is checked
  flag  i: ignore a path that does not exist

The application user and the host user are members of each other's group, so both have the access when the owner (one
of the two users) and the group have it. Paths that are neither owned by the host user with the application group nor
in the host group are moved into the host group: the host user is not a member of the application group on the host.
The script fails if a path still lacks the access afterwards.

Example: ${scriptName} -u www-data -i 1000 -g 1000 -p /var/www/project/var:w+,/var/www/project/vendor:r+:i
EOF
}

trim()
{
  echo -n "$1" | xargs
}

# prints the permission bits needed for files and directories: read needs directories to be listed and entered, write
# needs the content to be read as well
accessBits()
{
  local access="${1}"
  local type="${2}"

  case "${access}" in
    r) if [[ "${type}" == "d" ]]; then echo "rx"; else echo "r"; fi ;;
    w) if [[ "${type}" == "d" ]]; then echo "rwx"; else echo "rw"; fi ;;
    e) echo "x" ;;
    *) >&2 echo "Invalid access: ${access}"; exit 1 ;;
  esac
}

# fixes the group and the permissions of the path (depth 0) or of everything below it (depth 1), with one find per
# change, and fails if a path still lacks the access afterwards
ensureAccess()
{
  local path="${1}"
  local access="${2}"
  local depth="${3}"
  local depthParameters
  local fileBits
  local directoryBits
  local count
  local missing

  if [[ "${depth}" == 0 ]]; then
    depthParameters=( -maxdepth 0 )
  else
    depthParameters=( -mindepth 1 )
  fi

  fileBits=$(accessBits "${access}" f)
  directoryBits=$(accessBits "${access}" d)

  count=$(find "${path}" "${depthParameters[@]}" ! -type l ! -group "${hostGroupId}" \
    ! \( -user "${hostUserId}" -group "${appGroupId}" \) -print -exec chgrp "${hostGroupId}" {} + | wc -l)
  if [[ "${count}" -gt 0 ]]; then
    echo "Changed group to: ${hostGroupName} of ${count} path(s) at: ${path} (depth ${depth})"
  fi

  count=$(find "${path}" "${depthParameters[@]}" -type d ! -perm "-u=${directoryBits},g=${directoryBits}" \
    -print -exec chmod "ug+${directoryBits}" {} + | wc -l)
  if [[ "${count}" -gt 0 ]]; then
    echo "Added mode: ug+${directoryBits} to ${count} directories at: ${path} (depth ${depth})"
  fi

  count=$(find "${path}" "${depthParameters[@]}" -type f ! -perm "-u=${fileBits},g=${fileBits}" \
    -print -exec chmod "ug+${fileBits}" {} + | wc -l)
  if [[ "${count}" -gt 0 ]]; then
    echo "Added mode: ug+${fileBits} to ${count} files at: ${path} (depth ${depth})"
  fi

  missing=$(find "${path}" "${depthParameters[@]}" \
    \( \( -type d ! -perm "-u=${directoryBits},g=${directoryBits}" \) -o \( -type f ! -perm "-u=${fileBits},g=${fileBits}" \) \) \
    -print | head -n 5)
  if [[ -n "${missing}" ]]; then
    >&2 echo "Could not give access: ${access} to path(s):"
    >&2 echo "${missing}"
    exit 1
  fi
}

checkAccessPath()
{
  local accessPath="${1}"
  local path
  local mode
  local flag
  local subAccess

  IFS=: read -r path mode flag <<< "${accessPath}"

  if [[ -z "${path}" ]]; then
    return 0
  fi

  if [[ -z "${mode}" ]]; then
    >&2 echo "No mode specified for path: ${path}"
    exit 1
  fi

  if [[ ! -e "${path}" ]]; then
    if [[ "${flag}" != "i" ]]; then
      >&2 echo "Could not find path at: ${path}"
      exit 1
    fi
    if [[ "${verbose}" == 1 ]]; then
      echo "Ignoring missing path: ${path}"
    fi
    return 0
  fi

  echo "Ensuring access: ${mode} to path: ${path}"

  ensureAccess "${path}" "${mode:0:1}" 0

  if [[ -d "${path}" ]] && [[ "${#mode}" -gt 1 ]]; then
    subAccess="${mode:1:1}"
    if [[ "${subAccess}" == "+" ]]; then
      subAccess="${mode:0:1}"
    fi
    ensureAccess "${path}" "${subAccess}" 1
  fi
}

appUserName=
hostUserId=
hostGroupId=
accessPaths=()
forcePrepare=0
verbose=0

while getopts hu:i:g:p:fv? option; do
  case ${option} in
    h) usage; exit 1;;
    u) appUserName=$(trim "$OPTARG");;
    i) hostUserId=$(trim "$OPTARG");;
    g) hostGroupId=$(trim "$OPTARG");;
    p) IFS=, read -r -a optionPaths <<< "${OPTARG}"; accessPaths+=( "${optionPaths[@]}" );;
    f) forcePrepare=1;;
    v) verbose=1;;
    ?) usage; exit 1;;
  esac
done
shift $((OPTIND - 1))
accessPaths+=( "$@" )

if [[ -z "${appUserName}" ]]; then
  >&2 echo "No application user specified!"
  usage
  exit 1
fi

if [[ -z "${hostUserId}" ]]; then
  >&2 echo "No host user id specified!"
  usage
  exit 1
fi

if [[ -z "${hostGroupId}" ]]; then
  hostGroupId="${hostUserId}"
fi

if ! id "${appUserName}" >/dev/null 2>&1; then
  >&2 echo "Could not find application user: ${appUserName}"
  exit 1
fi

appUserId=$(id -u "${appUserName}")
appGroupId=$(id -g "${appUserName}")
appGroupName=$(id -gn "${appUserName}")

# a host user or group with the id of the application user or group is used as it is instead of being renamed
if [[ "${hostUserId}" == "${appUserId}" ]]; then
  hostUserName="${appUserName}"
else
  hostUserName="docker_volume_${hostUserId}"
fi
if [[ "${hostGroupId}" == "${appGroupId}" ]]; then
  hostGroupName="${appGroupName}"
else
  hostGroupName="docker_volume_${hostGroupId}"
fi

if [[ "${verbose}" == 1 ]]; then
  echo "Application user: ${appUserName} (${appUserId}), group: ${appGroupName} (${appGroupId})"
  echo "Host user: ${hostUserName} (${hostUserId}), group: ${hostGroupName} (${hostGroupId})"
fi

# the users and groups only change with a new container, so their setup (slow: it checks packages and accounts) runs
# once per container and is remembered in the container itself
usersPreparedFile="/var/lib/cosyses/path-access/users-${appUserName}-${hostUserId}-${hostGroupId}.done"
if [[ -f "${usersPreparedFile}" ]] && [[ "${forcePrepare}" == 0 ]]; then
  echo "Users already prepared: ${appUserName}, ${hostUserName}"
else
  if [[ "${hostUserName}" != "${appUserName}" ]]; then
    ensure-user -u "${hostUserName}" -i "${hostUserId}" -g "${hostGroupName}" -d "${hostGroupId}"
  fi

  if [[ "${hostGroupName}" != "${appGroupName}" ]]; then
    ensure-user -u "${appUserName}" -g "${hostGroupName}" -d "${hostGroupId}"
  fi
  if [[ "${hostUserName}" != "${appUserName}" ]]; then
    ensure-user -u "${hostUserName}" -g "${appGroupName}"
  fi

  prepare-user -u "${appUserName}"
  if [[ "${hostUserName}" != "${appUserName}" ]]; then
    prepare-user -u "${hostUserName}"
  fi

  mkdir -p "$(dirname "${usersPreparedFile}")"
  touch "${usersPreparedFile}"
fi

if [[ "${#accessPaths[@]}" -gt 0 ]]; then
  for accessPath in "${accessPaths[@]}"; do
    checkAccessPath "${accessPath}"
  done
else
  echo "No paths to check"
fi
