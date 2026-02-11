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
  --help     Show this message
  --webPath  Web path
  --webUser  Web user, default: www-data
  --webUser  Web group, default: www-data

Example: ${scriptFileName} --webPath /var/www/project/htdocs
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

webPath=
webUser=
webGroup=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${webPath}" ]]; then
  echo "No web path specified!"
  exit 1
elif [[ "${webPath}" != */ ]]; then
  webPath="${webPath}/"
fi

if [[ -z "${webUser}" ]]; then
  webUser="www-data"
fi

if [[ -z "${webGroup}" ]]; then
  webGroup="www-data"
fi

if [[ ! -d "${webPath}" ]]; then
  echo "Creating web path at: ${webPath}"
  mkdir -p "${webPath}"
fi

webPathUser=$(stat -c '%U' "${webPath}")
webPathGroup=$(stat -c '%G' "${webPath}")

if [[ "${webUser}" != "${webPathUser}" ]] || [[ "${webGroup}" != "${webPathGroup}" ]]; then
  echo "Setting owner of web path: ${webPath} to: ${webUser}:${webGroup}"
  chown "${webUser}":"${webGroup}" "${webPath}"
fi
