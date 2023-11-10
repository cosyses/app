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
  --webPath                Web path
  --webUser                Web user, default: www-data
  --webGroup               Web group, default: www-data
  --indexFile              Name of index file, default: index.php
  --logPath                Log path, default: /var/log/apache2
  --logLevel               Log level, default: warn
  --serverName             Server name
  --serverAdmin            Server admin, default: webmaster@<server name>
  --fpmHostName            Host name of PHP FPM instance, default: localhost
  --fpmHostPort            Port of PHP FPM instance, default: 9000
  --basicAuthUserName      Basic auth user name
  --basicAuthPassword      Basic auth password
  --basicAuthUserFilePath  Basic auth user file path, default: /var/www
  --append                 Append to existing configuration if configuration file already exists (yes/no), default: no

Example: ${scriptFileName} --webPath /var/www/project01/htdocs --serverName project01.net --basicAuthUserName login --basicAuthPassword password
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
basicAuthUserName=
basicAuthPassword=
basicAuthUserFilePath=
append=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${sslPort}" ]]; then
  sslPort=443
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

configurationFile="/etc/apache2/sites-available/${serverName}.conf"
basicAuthUserFile="${basicAuthUserFilePath}/${serverName}.htpasswd"

echo "Creating SSL host at: ${configurationFile} with basic auth file: ${basicAuthUserFile}"

cat <<EOF | tee -a "${configurationFile}" > /dev/null
<IfModule mod_ssl.c>
  <VirtualHost *:${sslPort}>
    SSLEngine on
    ServerName ${serverName}
    ServerAdmin ${serverAdmin}
    DocumentRoot ${webPath}
    DirectoryIndex ${indexFile}
    <Directory ${webPath}>
      AuthType Basic
      AuthName "${serverName}"
      AuthUserFile "${basicAuthUserFile}"
      Require valid-user
      Options FollowSymLinks
      AllowOverride All
      Order Allow,Deny
      Allow from all
    </Directory>
    <FilesMatch \.php$>
      SetHandler "proxy:fcgi://${fpmHostName}:${fpmHostPort}"
    </FilesMatch>
    LogLevel ${logLevel}
    ErrorLog ${logPath}/${serverName}-apache-ssl-error.log
    CustomLog ${logPath}/${serverName}-apache-ssl-access.log combined
  </VirtualHost>
</IfModule>
EOF
