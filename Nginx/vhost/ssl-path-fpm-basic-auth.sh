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
  --help                   Show this message
  --sslPort                SSL port, default: 443
  --sslCertFile            SSL certificate file, default: /etc/ssl/certs/ssl-cert-snakeoil.pem
  --sslKeyFile             SSL key file, default: /etc/ssl/private/ssl-cert-snakeoil.key
  --webPath                Web path
  --webUser                Web user, default: www-data
  --webGroup               Web group, default: www-data
  --logPath                Log path, default: /var/log/nginx
  --logLevel               Log level, default: warn
  --serverName             Server name
  --fpmHostName            Host name of PHP FPM instance, default: localhost
  --fpmHostPort            Port of PHP FPM instance, default: 9000
  --fpmIndexScript         Index script of FPM server, default: index.php
  --rootPath               Path of root, default: /
  --rootPathIndex          Index of root path, default: /index.php
  --phpPath                Path of PHP, default: \.php$
  --basicAuthUserName      Basic auth user name
  --basicAuthPassword      Basic auth password
  --basicAuthUserFilePath  Basic auth user file path, default: /var/www
  --application            Install configuration for this application (optional)
  --append                 Append to existing configuration if configuration file already exists (yes/no), default: no

Example: ${scriptFileName} --webPath /var/www/project01/htdocs --serverName project01.net --fpmHostName fpm --basicAuthUserName login --basicAuthPassword password
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
fpmHostName=
fpmHostPort=
fpmIndexScript=
rootPath=
rootPathIndex=
phpPath=
basicAuthUserName=
basicAuthPassword=
basicAuthUserFilePath=
application=
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

if [[ -z "${fpmHostName}" ]]; then
  fpmHostName="localhost"
fi

if [[ -z "${fpmHostPort}" ]]; then
  fpmHostPort="9000"
fi

if [[ -z "${fpmIndexScript}" ]]; then
  fpmIndexScript="index.php"
fi

if [[ -z "${rootPath}" ]]; then
  rootPath="/"
fi

if [[ -z "${rootPathIndex}" ]]; then
  rootPathIndex="/index.php?\$args"
fi

if [[ -z "${phpPath}" ]]; then
  phpPath="\.php\$"
fi

if [[ -z "${basicAuthUserName}" ]]; then
  echo "No basic auth user name specified!"
fi

if [[ -z "${basicAuthPassword}" ]]; then
  echo "No basic auth password specified!"
fi

if [[ -z "${basicAuthUserFilePath}" ]]; then
  basicAuthUserFilePath="/var/www"
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
  --applicationScript "vhost/prepare/basic-auth-file.sh" \
  --serverName "${serverName}" \
  --webUser "${webUser}" \
  --webGroup "${webGroup}" \
  --basicAuthUserName "${basicAuthUserName}" \
  --basicAuthPassword "${basicAuthPassword}" \
  --basicAuthUserFilePath "${basicAuthUserFilePath}"

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript "vhost/prepare/configuration-file.sh" \
  --serverName "${serverName}" \
  --append "${append}"

configurationFile="/etc/nginx/conf.d/${serverName}.conf"
basicAuthUserFile="${basicAuthUserFilePath}/${serverName}.htpasswd"

echo "Creating SSL host at: ${configurationFile} with basic auth file: ${basicAuthUserFile}"

cat <<EOF | tee -a "${configurationFile}" > /dev/null
server {
  listen ${sslPort} ssl;
  server_name ${serverName};
  root ${webPath};
  index ${rootPathIndex};
  error_page 500 502 503 504 /50x.html;
  ssl_certificate ${sslCertFile};
  ssl_certificate_key ${sslKeyFile};
  ssl_session_cache shared:SSL:10m;
  ssl_session_timeout 10m;
  ssl_protocols SSLv3 TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
  ssl_ciphers ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv3:+EXP:!aNULL:!MD5;
  ssl_prefer_server_ciphers on;
  location ${rootPath} {
    try_files \$uri \$uri/ ${rootPathIndex};
    auth_basic "${serverName}";
    auth_basic_user_file ${basicAuthUserFile};
  }
EOF

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript "vhost/server/fpm.sh" \
  --serverName "${serverName}" \
  --fpmHostName "${fpmHostName}" \
  --fpmHostPort "${fpmHostPort}" \
  --fpmIndexScript "${fpmIndexScript}" \
  --phpPath "${phpPath}"

if [[ -n "${application}" ]] && [[ "${application}" != "no" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --applicationScript "vhost/server/${application}.sh" \
    --serverName "${serverName}" \
    --webPath "${webPath}" \
    --fpmHostName "${fpmHostName}" \
    --fpmHostPort "${fpmHostPort}" \
    --fpmIndexScript "${fpmIndexScript}"
fi

cat <<EOF | tee -a "${configurationFile}" > /dev/null
  error_log ${logPath}/${serverName}-nginx-ssl-error.log ${logLevel};
  access_log ${logPath}/${serverName}-nginx-ssl-access.log;
}
EOF
