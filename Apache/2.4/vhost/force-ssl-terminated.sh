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
  --sslPort      SSL port, default: 443
  --webPath      Web path
  --webUser      Web user, default: www-data
  --webGroup     Web group, default: www-data
  --logPath      Log path, default: /var/log/apache2
  --logLevel     Log level, default: warn
  --serverName   Server name
  --serverAdmin  Server admin, default: webmaster@<server name>
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
sslPort=
webPath=
webUser=
webGroup=
logPath=
logLevel=
serverName=
serverAdmin=
append=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${httpPort}" ]]; then
  httpPort=80
fi

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

if [[ -z "${append}" ]]; then
  append="no"
fi

if [[ $(apache2ctl -M | tail -n +2 | awk '{print $1}' | grep 'rewrite_module' | wc -l) == 0 ]]; then
  echo "Enabling rewrite module"
  a2enmod rewrite
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

echo "Creating HTTP to SSL redirect with terminated SSL at: ${configurationFile}"

cat <<EOF | tee -a "${configurationFile}" > /dev/null
<VirtualHost *:${httpPort}>
  ServerName ${serverName}
  ServerAdmin ${serverAdmin}
  DocumentRoot ${webPath}
  <Directory ${webPath}>
    Options FollowSymLinks
    AllowOverride All
    Order Allow,Deny
    Allow from all
  </Directory>
  RewriteEngine On
  RewriteCond %{HTTP:X-Forwarded-Proto} =http
  RewriteRule .* https://%{HTTP:Host}:${sslPort}%{REQUEST_URI} [L,R=permanent]
  SetEnv HTTPS on
  LogLevel ${logLevel}
  ErrorLog ${logPath}/${serverName}-apache-http-error.log
  CustomLog ${logPath}/${serverName}-apache-http-access.log combined
</VirtualHost>
EOF
