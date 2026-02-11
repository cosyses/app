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
  --sslPort      SSL port, default: 443
  --sslCertFile  SSL certificate file, default: /etc/ssl/certs/ssl-cert-snakeoil.pem
  --sslKeyFile   SSL key file, default: /etc/ssl/private/ssl-cert-snakeoil.key
  --webPath      Web path
  --webUser      Web user, default: www-data
  --webGroup     Web group, default: www-data
  --logPath      Log path, default: /var/log/nginx
  --logLevel     Log level, default: warn
  --serverName   Server name
  --append       Append to existing configuration if configuration file already exists (yes/no), default: no

Example: ${scriptFileName} --webPath /var/www/project01/htdocs --serverName project01.net
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

if [[ -z "${applicationName}" ]]; then
  >&2 echo "No application name exported!"
  echo ""
  exit 1
fi

if [[ -z "${applicationVersion}" ]]; then
  >&2 echo "No application version exported!"
  echo ""
  exit 1
fi

sslPort=
sslCertFile=
sslKeyFile=
webPath=
webUser=
webGroup=
logPath=
logLevel=
serverName=
append=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${sslPort}" ]]; then
  sslPort=443
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

if [[ -z "${logPath}" ]]; then
  logPath="/var/log/nginx"
fi

if [[ -z "${logLevel}" ]]; then
  logLevel="warn"
fi

if [[ -z "${serverName}" ]]; then
  echo "No server name specified!"
  exit 1
fi

if [[ -z "${append}" ]]; then
  append="no"
fi

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript "vhost/prepare/web-path.sh" \
  --webPath "${webPath}" \
  --webUser "${webUser}" \
  --webGroup "${webGroup}"

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript "vhost/prepare/log-path.sh" \
  --logPath "${logPath}" \
  --webUser "${webUser}" \
  --webGroup "${webGroup}"

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript "vhost/prepare/configuration-file.sh" \
  --serverName "${serverName}" \
  --append "${append}"

configurationFile="/etc/nginx/conf.d/${serverName}.conf"

echo "Creating SSL host at: ${configurationFile}"

cat <<EOF | tee -a "${configurationFile}" > /dev/null
server {
  listen ${sslPort} ssl;
  server_name ${serverName};
  root ${webPath};
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
  error_log ${logPath}/${serverName}-nginx-ssl-error.log ${logLevel};
  access_log ${logPath}/${serverName}-nginx-ssl-access.log;
}
EOF
