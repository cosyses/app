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
  --help      Show this message
  --logPath   Log path, default: /var/log/nginx
  --webUser   Web user, default: www-data
  --webGroup  Web group, default: www-data

Example: ${scriptFileName} -l /var/www/project/log
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

logPath=
webUser=
webGroup=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${logPath}" ]]; then
  echo "No log path specified!"
  exit 1
fi

if [[ -z "${webUser}" ]]; then
  webUser="www-data"
fi

if [[ -z "${webGroup}" ]]; then
  webGroup="www-data"
fi

if [[ ! -d "${logPath}" ]]; then
  echo "Creating log path at: ${logPath}"
  mkdir -p "${logPath}"
fi

logPathUser=$(stat -c '%U' "${logPath}")
logPathGroup=$(stat -c '%G' "${logPath}")

if [[ "${webUser}" != "${logPathUser}" ]] || [[ "${webGroup}" != "${logPathGroup}" ]]; then
  echo "Setting owner of log path: ${logPath} to: ${webUser}:${webGroup}"
  chown "${webUser}":"${webGroup}" "${logPath}"
fi
