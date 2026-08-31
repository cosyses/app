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
  --help            Show this message
  --serverName      Server name
  --webPath         Web path
  --fpmHostName     Host name of PHP FPM instance, default: localhost
  --fpmHostPort     Port of PHP FPM instance, default: 9000
  --fpmIndexScript  Index script of FPM server, default: index.php

Example: ${scriptFileName} --webPath /var/www/project01/htdocs --serverName project01.net
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

serverName=
webPath=
fpmHostName=
fpmHostPort=
fpmIndexScript=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${serverName}" ]]; then
  echo "No server name specified!"
  exit 1
fi

if [[ -z "${webPath}" ]]; then
  echo "No web path specified!"
  exit 1
fi

if [[ -z "${fpmHostName}" ]]; then
  fpmHostName="localhost"
fi

if [[ -z "${fpmHostPort}" ]]; then
  fpmHostPort="9000"
fi

if [[ -z "${fpmIndexScript}" ]]; then
  fpmIndexScript="index.php"
fi

configurationFile="/etc/nginx/conf.d/${serverName}.conf"

cat <<EOF | tee -a "${configurationFile}" > /dev/null
  gzip on;
  gzip_proxied any;
  gzip_types text/plain text/css application/xml application/javascript application/x-javascript;
  gzip_proxied no-cache no-store private expired auth;
  gzip_min_length 100;
  location ~* ^.+\.(?:css|cur|js|jpe?g|gif|ico|png|svg|webp|html|woff|woff2|xml)\$ {
    expires 1y;
    add_header Cache-Control "public, must-revalidate, proxy-revalidate";
    access_log off;
    log_not_found off;
    tcp_nodelay off;
    open_file_cache max=3000 inactive=120s;
    open_file_cache_valid 45s;
    open_file_cache_min_uses 2;
    open_file_cache_errors off;
    try_files \$uri /index.php\$is_args\$args;
  }
  location ~* ^.+\.svg\$ {
    add_header Content-Security-Policy "script-src 'none'";
  }
  location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)\$ {
    expires 5d;
    try_files \$uri \$uri/ /index.php?q=\$uri&\$args;
  }
  location ~ /\. {
    log_not_found off;
    deny all;
  }
EOF
