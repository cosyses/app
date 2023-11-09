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
  --help    Show this message
  --host    Host name to use, default: localhost
  --port    Port to use, default: 1025
  --sender  Mail of the sender, default: webmaster@localhost.local

Example: ${scriptFileName}
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

host=
port=
sender=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${host}" ]]; then
  host="localhost"
fi

if [[ -z "${port}" ]]; then
  port=1025
fi

if [[ -z "${sender}" ]]; then
  sender="webmaster@localhost.local"
fi

cosyses \
  --applicationName mhsendmail \
  --applicationVersion 0.2

phpVersion=$(php -v 2>/dev/null | grep --only-matching --perl-regexp "(PHP )\d+\.\\d+\.\\d+" | cut -c 5-7)

configurationPath="/etc/php/${phpVersion}/mods-available"

if [[ ! -d "${configurationPath}" ]]; then
  >&2 echo "Unsupported PHP version: ${phpVersion}"
  exit 1
fi

echo "Creating configuration at: ${configurationPath}/mhsendmail.ini"
echo "sendmail_path = /usr/bin/mhsendmail --smtp-addr ${host}:${port} --from ${sender}" > "${configurationPath}/mhsendmail.ini"

if [[ -n $(which phpenmod) ]]; then
  echo "Enabling module mhsendmail"
  phpenmod mhsendmail
fi

if [[ ! -f /.dockerenv ]]; then
  if [[ -n $(get-installed-package-version apache2) ]]; then
    echo "Restarting Apache"
    service apache2 restart
  fi

  if [[ -n $(get-installed-package-version nginx) ]]; then
    echo "Restarting Nginx"
    service nginx restart
  fi
fi
