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
  --help                      Show this message
  --sslPort                   SSL port, default: 443
  --webUser                   Web user, default: www-data
  --webGroup                  Web group, default: www-data
  --logPath                   Log path, default: /var/log/nginx
  --logLevel                  Log level, default: warn
  --serverName                Server name
  --redirectTargetProtocol    Protocol of redirect target, default: https
  --redirectTargetServerName  Server name of target
  --append                    Append to existing configuration if configuration file already exists (yes/no), default: no

Example: ${scriptFileName} --serverName project01.net
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
logPath=
logLevel=
serverName=
redirectTargetProtocol=
redirectTargetServerName=
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

if [[ -z "${redirectTargetProtocol}" ]]; then
  redirectTargetProtocol="https"
fi

if [[ -z "${redirectTargetServerName}" ]]; then
  echo "No redirect target server name specified!"
  exit 1
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
  --applicationScript "vhost/prepare/configuration-file.sh" \
  --serverName "${serverName}" \
  --append "${append}"

configurationFile="/etc/nginx/conf.d/${serverName}.conf"

echo "Creating SSL redirect at: ${configurationFile}"

cat <<EOF | tee -a "${configurationFile}" > /dev/null
server {
  listen ${sslPort};
  server_name ${serverName};
  return 301 ${redirectTargetProtocol}://${redirectTargetServerName}\$request_uri;
  error_log ${logPath}/${serverName}-nginx-ssl-error.log ${logLevel};
  access_log ${logPath}/${serverName}-nginx-ssl-access.log;
}
EOF
