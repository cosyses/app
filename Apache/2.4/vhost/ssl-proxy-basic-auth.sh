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
  --webUser                Web user, default: www-data
  --webGroup               Web group, default: www-data
  --proxyHostPath          Proxy host path), default: /
  --proxyProtocol          Proxy protocol, default: http
  --proxyHost              Proxy host
  --proxyPort              Proxy port, default: 80 (http) or 443 (https)
  --proxyPath              Proxy path, default: /
  --logPath                Log path, default: /var/log/apache2
  --logLevel               Log level, default: warn
  --serverName             Server name
  --serverAdmin            Server admin, default: webmaster@<server name>
  --basicAuthUserName      Basic auth user name
  --basicAuthPassword      Basic auth password
  --basicAuthUserFilePath  Basic auth user file path, default: /var/www
  --append                 Append to existing configuration if configuration file already exists (yes/no), default: no

Example: ${scriptFileName} --proxyHost hostname --proxyPort 8080 --serverName project01.net --basicAuthUserName login --basicAuthPassword password
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
webUser=
webGroup=
proxyHostPath=
proxyProtocol=
proxyHost=
proxyPort=
proxyPath=
logPath=
logLevel=
serverName=
serverAdmin=
append=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${sslPort}" ]]; then
  sslPort=443
fi

if [[ -z "${webUser}" ]]; then
  webUser="www-data"
fi

if [[ -z "${webGroup}" ]]; then
  webGroup="www-data"
fi

if [[ -z "${proxyHostPath}" ]]; then
  proxyHostPath="/"
fi

if [[ -z "${proxyProtocol}" ]]; then
  proxyProtocol="http"
fi

if [[ -z "${proxyHost}" ]]; then
  echo "No proxy host specified!"
  exit 1
fi

if [[ -z "${proxyPort}" ]]; then
  if [[ "${proxyProtocol}" == "http" ]]; then
    proxyPort=80
  elif [[ "${proxyProtocol}" == "https" ]]; then
    proxyPort=443
  else
    echo "No proxy port specified!"
    exit 1
  fi
fi

if [[ -z "${proxyPath}" ]] || [[ "${proxyPath}" == "-" ]]; then
  proxyPath="/"
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

if [[ $(apache2ctl -M | tail -n +2 | awk '{print $1}' | grep 'ssl_module' | wc -l) == 0 ]]; then
  echo "Enabling SSL module"
  a2enmod ssl
fi

if [[ $(apache2ctl -M | tail -n +2 | awk '{print $1}' | grep 'headers_module' | wc -l) == 0 ]]; then
  echo "Enabling headers module"
  a2enmod headers
fi

if [[ $(apache2ctl -M | tail -n +2 | awk '{print $1}' | grep 'expires_module' | wc -l) == 0 ]]; then
  echo "Enabling expires module"
  a2enmod expires
fi

if [[ $(apache2ctl -M | tail -n +2 | awk '{print $1}' | grep 'proxy_module' | wc -l) == 0 ]]; then
  echo "Enabling proxy module"
  a2enmod proxy
fi

if [[ $(apache2ctl -M | tail -n +2 | awk '{print $1}' | grep 'proxy_http_module' | wc -l) == 0 ]]; then
  echo "Enabling proxy HTTP module"
  a2enmod proxy_http
fi

if [[ $(apache2ctl -M | tail -n +2 | awk '{print $1}' | grep 'auth_basic_module' | wc -l) == 0 ]]; then
  echo "Enabling basic auth module"
  a2enmod auth_basic
fi

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

echo "Creating SSL proxy at: ${configurationFile} to: ${proxyProtocol}://${proxyHost}:${proxyPort}${proxyPath} with basic auth file: ${basicAuthUserFile}"

cat <<EOF | tee -a "${configurationFile}" > /dev/null
<IfModule mod_ssl.c>
  <VirtualHost *:${sslPort}>
    SSLEngine on
    ServerName ${serverName}
    ServerAdmin ${serverAdmin}
    ProxyPass "${proxyHostPath}" "${proxyProtocol}://${proxyHost}:${proxyPort}${proxyPath}"
    ProxyPassReverse "${proxyHostPath}" "${proxyProtocol}://${proxyHost}:${proxyPort}${proxyPath}"
    ProxyPreserveHost On
    ProxyRequests Off
    RequestHeader unset Authorization
    <Proxy *>
      AuthType Basic
      AuthName "${serverName}"
      AuthBasicProvider file
      AuthUserFile "${basicAuthUserFile}"
      Require valid-user
      RewriteEngine On
      RewriteRule .* - [E=PROXY_USER:%{LA-U:REMOTE_USER},NS]
      RequestHeader set X-WEBAUTH-USER "%{PROXY_USER}e"
    </Proxy>
    LogLevel ${logLevel}
    ErrorLog ${logPath}/${serverName}-apache-ssl-error.log
    CustomLog ${logPath}/${serverName}-apache-ssl-access.log combined
  </VirtualHost>
</IfModule>
EOF
