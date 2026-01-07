#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

OPTIONS:
  --help                   Show this message
  --serverName             Server name
  --webUser                Web user, default: www-data
  --webGroup               Web group, default: www-data
  --basicAuthUserName      Basic auth user name
  --basicAuthPassword      Basic auth password
  --basicAuthUserFilePath  Basic auth user file path, default: /var/www

Example: ${scriptFileName}
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

serverName=
webUser=
webGroup=
basicAuthUserName=
basicAuthPassword=
basicAuthUserFilePath="/var/www"
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${serverName}" ]]; then
  echo "No server name specified!"
  exit 1
fi

if [[ -z "${webUser}" ]]; then
  webUser="www-data"
fi

if [[ -z "${webGroup}" ]]; then
  webGroup="www-data"
fi

if [[ -z "${basicAuthUserName}" ]]; then
  echo "No basic auth user name specified!"
  exit 1
fi

if [[ -z "${basicAuthPassword}" ]]; then
  echo "No basic auth password specified!"
  exit 1
fi

if [[ -z "${basicAuthUserFilePath}" ]]; then
  basicAuthUserFilePath="/var/www"
fi

install-package apache2-utils

if [[ ! -d "${basicAuthUserFilePath}" ]]; then
  echo "Creating basic auth path: ${basicAuthUserFilePath}"
  mkdir -p "${basicAuthUserFilePath}"
fi

basicAuthUserFilePathUser=$(stat -c '%U' "${basicAuthUserFilePath}")
basicAuthUserFilePathGroup=$(stat -c '%G' "${basicAuthUserFilePath}")

if [[ "${webUser}" != "${basicAuthUserFilePathUser}" ]] || [[ "${webGroup}" != "${basicAuthUserFilePathGroup}" ]]; then
  echo "Setting owner of basic auth path: ${basicAuthUserFilePath} to: ${webUser}:${webGroup}"
  chown "${webUser}":"${webGroup}" "${basicAuthUserFilePath}"
fi

basicAuthUserFile="${basicAuthUserFilePath}/${serverName}.htpasswd"

if [[ -f "${basicAuthUserFile}" ]]; then
  echo "Using basic user in file at: ${basicAuthUserFile}"
  set +e
  # shellcheck disable=SC2091
  $(htpasswd -vb "${basicAuthUserFile}" "${basicAuthUserName}" "${basicAuthPassword}" >/dev/null 2>&1)
  result=$?
  set -e
  if [[ "${result}" -ne 0 ]]; then
    htpasswd -b "${basicAuthUserFile}" "${basicAuthUserName}" "${basicAuthPassword}"
  else
    echo "User already added"
  fi
else
  echo "Adding basic user in file at: ${basicAuthUserFile}"
  htpasswd -b -c "${basicAuthUserFile}" "${basicAuthUserName}" "${basicAuthPassword}"
fi

basicAuthUserFileUser=$(stat -c '%U' "${basicAuthUserFile}")
basicAuthUserFileGroup=$(stat -c '%G' "${basicAuthUserFile}")

if [[ "${webUser}" != "${basicAuthUserFileUser}" ]] || [[ "${webGroup}" != "${basicAuthUserFileGroup}" ]]; then
  chown "${webUser}":"${webGroup}" "${basicAuthUserFile}"
fi
