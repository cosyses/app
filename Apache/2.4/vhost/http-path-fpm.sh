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
  --webPath      Web path
  --webUser      Web user, default: www-data
  --webGroup     Web group, default: www-data
  --indexFile    Name of index file, default: index.php
  --logPath      Log path, default: /var/log/apache2
  --logLevel     Log level, default: warn
  --serverName   Server name
  --serverAdmin  Server admin, default: webmaster@<server name>
  --fpmHostName  Host name of PHP FPM instance, default: localhost
  --fpmHostPort  Port of PHP FPM instance, default: 9000
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

httpPort=
webPath=
webUser=
webGroup=
indexFile=
logPath=
logLevel=
serverName=
serverAdmin=
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

if [[ -z "${indexFile}" ]]; then
  indexFile="index.php"
fi

if [[ -z "${logPath}" ]]; then
  logPath="/var/log/apache2"
fi

if [[ -z "${logLevel}" ]]; then
  logLevel="warn"
fi

if [[ -z "${serverName}" ]]; then
  echo "No server name specified!"
  exit 1
fi

if [[ -z "${serverAdmin}" ]]; then
  serverAdmin="webmaster@${serverName}"
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

configurationFile="/etc/apache2/sites-available/${serverName}.conf"

echo "Creating HTTP host at: ${configurationFile}"

cat <<EOF | tee -a "${configurationFile}" > /dev/null
<VirtualHost *:${httpPort}>
  ServerName ${serverName}
  ServerAdmin ${serverAdmin}
  DocumentRoot ${webPath}
  DirectoryIndex ${indexFile}
  <Directory ${webPath}>
    Options FollowSymLinks
    AllowOverride All
    Order Allow,Deny
    Allow from all
  </Directory>
  <FilesMatch \.php$>
    SetHandler "proxy:fcgi://${fpmHostName}:${fpmHostPort}"
  </FilesMatch>
  LogLevel ${logLevel}
  ErrorLog ${logPath}/${serverName}-apache-http-error.log
  CustomLog ${logPath}/${serverName}-apache-http-access.log combined
</VirtualHost>
EOF
