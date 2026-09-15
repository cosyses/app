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
  --help         Show this message
  --httpPort     HTTP port, default: 80
  --sslPort      SSL Port, default: 443
  --sslCertFile  SSL certificate file, default: /etc/ssl/certs/ssl-cert-snakeoil.pem
  --sslKeyFile   SSL key file, default: /etc/ssl/private/ssl-cert-snakeoil.key

Example: ${scriptFileName} --httpPort 80 --sslPort 443
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

httpPort=
sslPort=
sslCertFile=
sslKeyFile=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${httpPort}" ]]; then
  httpPort="80"
fi

if [[ -z "${sslPort}" ]]; then
  sslPort="443"
fi

if [[ -z "${sslCertFile}" ]]; then
  sslCertFile="/etc/ssl/certs/ssl-cert-snakeoil.pem"
fi

if [[ ! -f "${sslCertFile}" ]]; then
  echo "Invalid SSL certificate file specified!"
  exit 1
fi

if [[ -z "${sslKeyFile}" ]]; then
  sslKeyFile="/etc/ssl/private/ssl-cert-snakeoil.key"
fi

if [[ ! -f "${sslKeyFile}" ]]; then
  echo "Invalid SSL key file specified!"
  exit 1
fi

echo "Adding to configuration at: /etc/caddy/Caddyfile"
cat <<EOF | tee -a /etc/caddy/Caddyfile > /dev/null
*:${httpPort} {
  root * /usr/share/caddy
  file_server {
    hide *.php
  }
  log {
    output file /var/log/caddy/caddy.log
  }
}
*:${sslPort} {
  root * /usr/share/caddy
  tls ${sslCertFile} ${sslKeyFile}
  file_server {
    hide *.php
  }
  log {
    output file /var/log/caddy/access.log
  }
}
EOF

if [[ ! -f /.dockerenv ]]; then
  echo "Restarting Caddy"
  service caddy restart
else
  if [[ -f /var/run/caddy.pid ]]; then
    echo "Reloading Caddy"
    caddy reload --config /etc/caddy/Caddyfile
  fi
fi
