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
  --help           Show this message
  --httpPort       HTTP port, default: 80
  --webPath        Web path
  --webUser        Web user, default: www-data
  --webGroup       Web group, default: www-data
  --logPath        Log path, default: /var/log/nginx
  --logLevel       Log level, default: warn
  --serverName     Server name
  --fpmHostName    Host name of PHP FPM instance, default: localhost
  --fpmHostPort    Port of PHP FPM instance, default: 9000
  --rootPath       Path of root, default: /
  --rootPathIndex  Index of root path, default: /index.php
  --phpPath        Path of PHP, default: \.php$
  --append         Append to existing configuration if configuration file already exists (yes/no), default: no

Example: ${scriptFileName} --webPath /var/www/project01/htdocs --serverName project01.net --fpmHostName fpm
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

httpPort=
webPath=
webUser=
webGroup=
logPath=
logLevel=
serverName=
fpmHostName=
fpmHostPort=
append=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${httpPort}" ]]; then
  httpPort=80
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

echo "Creating HTTP host at: ${configurationFile}"

cat <<EOF | tee -a "${configurationFile}" > /dev/null
server {
  listen ${httpPort};
  server_name ${serverName};
  root ${webPath};
  index index.php index.html index.htm;
  error_page 500 502 503 504  /50x.html;
  location / {
    try_files \$uri \$uri/ /index.html;
  }
  location ~ \.php$ {
    try_files \$uri =404;
    fastcgi_split_path_info ^(.+\.php)(/.+)\$;
    fastcgi_pass ${fpmHostName}:${fpmHostPort};
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    fastcgi_param PATH_INFO \$fastcgi_path_info;
  }
  error_log ${logPath}/${serverName}-nginx-http-error.log ${logLevel};
  access_log ${logPath}/${serverName}-nginx-http-access.log;
}
EOF
