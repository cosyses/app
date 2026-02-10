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
  --httpPort               HTTP port, default: 80
  --webUser                Web user, default: www-data
  --webGroup               Web group, default: www-data
  --proxyHostPath          Proxy host path, default: /
  --proxyProtocol          Proxy protocol, default: http
  --proxyHost              Proxy host
  --proxyPort              Proxy port, default: 80 (http) or 443 (https)
  --proxyPath              Proxy path, default: /
  --logPath                Log path, default: /var/log/nginx
  --logLevel               Log level, default: warn
  --serverName             Server name
  --basicAuthUserName      Basic auth user name
  --basicAuthPassword      Basic auth password
  --basicAuthUserFilePath  Basic auth user file path, default: /var/www
  --append                 Append to existing configuration if configuration file already exists (yes/no), default: no

Example: ${scriptFileName} --serverName project01.net --proxyHost remote --proxyPort 8080 --basicAuthUserName login --basicAuthPassword password
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
basicAuthUserName=
basicAuthPassword=
basicAuthUserFilePath=
append=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${httpPort}" ]]; then
  httpPort=80
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
  logPath="/var/log/nginx"
fi

if [[ -z "${logLevel}" ]]; then
  logLevel="warn"
fi

if [[ -z "${serverName}" ]]; then
  echo "No server name specified!"
  exit 1
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

echo "Creating HTTP host with proxy at: ${configurationFile} with basic auth file: ${basicAuthUserFile}"

cat <<EOF | tee -a "${configurationFile}" > /dev/null
server {
  listen ${httpPort};
  server_name ${serverName};
  index index.html index.htm;
  error_page 500 502 503 504  /50x.html;
  location ${proxyHostPath} {
    auth_basic "${serverName}";
    auth_basic_user_file ${basicAuthUserFile};
    proxy_pass ${proxyProtocol}://${proxyHost}:${proxyPort}${proxyPath};
    proxy_set_header Host \$http_host;
  }
  error_log ${logPath}/${serverName}-nginx-http-error.log ${logLevel};
  access_log ${logPath}/${serverName}-nginx-http-access.log;
}
EOF
