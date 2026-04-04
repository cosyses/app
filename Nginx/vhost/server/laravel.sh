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
  # Static Files Caching
  location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }
  # Security: Deny access to hidden files
  location ~ /\. {
    deny all;
  }
  # Security: Deny access to sensitive files
  location ~ /(\.env|\.git|composer\.(json|lock)|package\.json) {
   deny all;
  }
  location ~ /\.(?!well-known).* {
    deny all;
  }
  # Favicon and robots.txt
  location = /favicon.ico { access_log off; log_not_found off; }
  location = /robots.txt  { access_log off; log_not_found off; }
  # Security Headers
  add_header X-Frame-Options "SAMEORIGIN" always;
  add_header X-XSS-Protection "1; mode=block" always;
  add_header X-Content-Type-Options "nosniff" always;
  add_header Referrer-Policy "no-referrer-when-downgrade" always;
  add_header Content-Security-Policy "default-src 'self' http: https: data: blob;" always;
  # Gzip Compression
  gzip on;
  gzip_vary on;
  gzip_min_length 1024;
  gzip_proxied expired no-cache no-store private must-revalidate auth;
  gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss;
EOF
