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

echo "Creating configuration at: /etc/nginx/conf.d/default.conf"
cat <<EOF >/etc/nginx/conf.d/default.conf
server {
  listen ${httpPort};
  server_name localhost;
  root /usr/share/nginx/html;
  index index.html index.htm;
  error_page 500 502 503 504  /50x.html;
  location / {
    try_files \$uri \$uri/ /index.html;
  }
}
server {
  listen ${sslPort} ssl;
  server_name localhost;
  root /usr/share/nginx/html;
  index index.html index.htm;
  error_page 500 502 503 504  /50x.html;
  ssl_certificate ${sslCertFile};
  ssl_certificate_key ${sslKeyFile};
  ssl_session_cache shared:SSL:10m;
  ssl_session_timeout 10m;
  ssl_protocols SSLv3 TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
  ssl_ciphers ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv3:+EXP:!aNULL:!MD5;
  ssl_prefer_server_ciphers on;
  location / {
    try_files \$uri \$uri/ /index.html;
  }
}
EOF

if [[ ! -f /.dockerenv ]]; then
  echo "Restarting Nginx"
  service nginx restart
else
  echo "Reloading Nginx"
  nginx -s reload
fi
