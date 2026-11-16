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

# PHP of RHEL and Fedora reads the files in /etc/php.d for the CLI and FPM
configurationPath="/etc/php.d"

if [[ ! -d "${configurationPath}" ]]; then
  >&2 echo "PHP is not installed!"
  exit 1
fi

echo "Creating configuration at: ${configurationPath}/90-mhsendmail.ini"
echo "sendmail_path = /usr/bin/mhsendmail --smtp-addr ${host}:${port} --from ${sender} -t" > "${configurationPath}/90-mhsendmail.ini"

if [[ ! -f /.dockerenv ]]; then
  if systemctl is-active --quiet php-fpm; then
    echo "Restarting PHP FPM"
    systemctl restart php-fpm
  fi

  if systemctl is-active --quiet httpd; then
    echo "Restarting Apache"
    systemctl restart httpd
  fi
fi
