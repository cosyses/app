#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Stores credentials for a Composer repository in the global Composer configuration (auth.json) of a user, for example
the access keys of repo.magento.com or a private Packagist. Composer has to be installed (cosyses Composer <version>).

usage: ${scriptFileName} options

OPTIONS:
  --help          Show this message
  --hostName      Host name of the repository, for example: repo.magento.com
  --authUser      User name or public key (http-basic)
  --authPassword  Password or private key (http-basic), or the token (bearer)
  --authType      http-basic or bearer, default: http-basic
  --user          System user whose configuration is changed, default: the current user

Example: ${scriptFileName} --hostName repo.magento.com --authUser <public key> --authPassword <private key> --user www-data
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

hostName=
authUser=
authPassword=
authType=
user=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${hostName}" ]]; then
  >&2 echo "No host name specified!"
  usage
  exit 1
fi

if [[ -z "${authType}" ]]; then
  authType="http-basic"
fi

if [[ "${authType}" != "http-basic" ]] && [[ "${authType}" != "bearer" ]]; then
  >&2 echo "Invalid auth type: ${authType}, use http-basic or bearer"
  usage
  exit 1
fi

if [[ "${authType}" == "http-basic" ]] && [[ -z "${authUser}" ]]; then
  >&2 echo "No auth user specified!"
  usage
  exit 1
fi

if [[ -z "${authPassword}" ]]; then
  >&2 echo "No auth password specified!"
  usage
  exit 1
fi

if [[ ! -x "$(command -v composer)" ]]; then
  >&2 echo "Composer not found, install it first (cosyses Composer <version>)"
  exit 1
fi

if [[ "${authType}" == "http-basic" ]]; then
  composerArguments=( config --global --no-interaction "http-basic.${hostName}" "${authUser}" "${authPassword}" )
else
  composerArguments=( config --global --no-interaction "bearer.${hostName}" "${authPassword}" )
fi

echo "Adding ${authType} credentials for host: ${hostName}"
if [[ -n "${user}" ]] && [[ "${user}" != "$(whoami)" ]]; then
  sudo -H -u "${user}" composer "${composerArguments[@]}"
else
  COMPOSER_ALLOW_SUPERUSER=1 composer "${composerArguments[@]}"
fi
