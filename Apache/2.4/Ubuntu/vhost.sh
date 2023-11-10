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
  --sslPort                SSL port, default: 443
  --webPath                Web path, required if no proxy data
  --webUser                Web user, default: www-data
  --webGroup               Web group, default: www-data
  --proxyHostPath          Proxy host path (optional), default: /
  --proxyProtocol          Proxy protocol (optional), default: http
  --proxyHost              Proxy host (optional)
  --proxyPort              Proxy port (optional), default: 80 (http) or 443 (https)
  --proxyPath              Proxy path (optional), default: /
  --logPath                Log path, default: /var/log/apache2
  --logLevel               Log level, default: warn
  --serverName             Server name
  --serverAdmin            Server admin, default: webmaster@<server name>
  --sslTerminated          SSL terminated (yes/no), default: no
  --forceSsl               Force SSL (yes/no), default: yes
  --basicAuthUserName      Basic auth user name (optional)
  --basicAuthPassword      Basic auth password (optional)
  --basicAuthUserFilePath  Basic auth user file path (optional), default: /var/www
  --fpmHostName            Host name of PHP FPM instance
  --fpmHostPort            Port of PHP FPM instance
  --overwrite              Overwrite existing files (yes/no), default: no

Example: ${scriptFileName} --webPath /var/www/project01/htdocs --serverName project01.net --sslTerminated no --forceSsl yes
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
proxyHostPath=
proxyProtocol=
proxyHost=
proxyPort=
proxyPath=
logPath=
logLevel=
serverName=
serverAdmin=
sslTerminated=
forceSsl=
basicAuthUserName=
basicAuthPassword=
basicAuthUserFilePath=
fpmHostName=
fpmHostPort=
overwrite=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${httpPort}" ]]; then
  httpPort=80
fi

if [[ -z "${sslPort}" ]]; then
  sslPort=443
fi

if [[ -z "${webPath}" ]] || [[ "${webPath}" == "-" ]]; then
  if [[ -z "${proxyHost}" ]] || [[ "${proxyHost}" == "-" ]]; then
    echo "No web path or proxy specified!"
    exit 1
  else
    webPath="-"
  fi
elif [[ "${webPath}" != */ ]]; then
  webPath="${webPath}/"
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
  proxyHost="-"
fi

if [[ -z "${proxyPort}" ]]; then
  if [[ "${proxyProtocol}" == "http" ]]; then
    proxyPort=80
  elif [[ "${proxyProtocol}" == "https" ]]; then
    proxyPort=443
  else
    proxyPort="-"
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

if [[ -z "${sslTerminated}" ]]; then
  sslTerminated="no"
fi

if [[ -z "${forceSsl}" ]]; then
  forceSsl="yes"
fi

if [[ -z "${basicAuthUserName}" ]]; then
  basicAuthUserName="-"
fi

if [[ -z "${basicAuthPassword}" ]]; then
  basicAuthPassword="-"
fi

if [[ -z "${basicAuthUserFilePath}" ]]; then
  basicAuthUserFilePath="/var/www"
fi

if [[ -z "${overwrite}" ]]; then
  overwrite="no"
fi

if [[ "${overwrite}" == 1 ]]; then
  overwrite="yes"
fi

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript "vhost/prepare/configuration-file.sh" \
  --serverName "${serverName}" \
  --overwrite "${overwrite}"

if [[ ${forceSsl} == "yes" ]]; then
  if [[ ${sslTerminated} == "yes" ]]; then
    if [[ -n "${basicAuthUserName}" ]] && [[ "${basicAuthUserName}" != "-" ]]; then
      cosyses \
        --applicationName "${applicationName}" \
        --applicationVersion "${applicationVersion}" \
        --applicationScript "vhost/force-ssl-terminated-basic-auth.sh" \
        --httpPort "${httpPort}" \
        --sslPort "${sslPort}" \
        --webPath "${webPath}" \
        --webUser "${webUser}" \
        --webGroup "${webGroup}" \
        --logPath "${logPath}" \
        --logLevel "${logLevel}" \
        --serverName "${serverName}" \
        --serverAdmin "${serverAdmin}" \
        --basicAuthUserName "${basicAuthUserName}" \
        --basicAuthPassword "${basicAuthPassword}" \
        --basicAuthUserFilePath "${basicAuthUserFilePath}" \
        --append yes
    else
      cosyses \
        --applicationName "${applicationName}" \
        --applicationVersion "${applicationVersion}" \
        --applicationScript "vhost/force-ssl-terminated.sh" \
        --httpPort "${httpPort}" \
        --sslPort "${sslPort}" \
        --webPath "${webPath}" \
        --webUser "${webUser}" \
        --webGroup "${webGroup}" \
        --logPath "${logPath}" \
        --logLevel "${logLevel}" \
        --serverName "${serverName}" \
        --serverAdmin "${serverAdmin}" \
        --append yes
    fi
  else
    if [[ -n "${basicAuthUserName}" ]] && [[ "${basicAuthUserName}" != "-" ]]; then
      cosyses \
        --applicationName "${applicationName}" \
        --applicationVersion "${applicationVersion}" \
        --applicationScript "vhost/force-ssl-basic-auth.sh" \
        --httpPort "${httpPort}" \
        --sslPort "${sslPort}" \
        --webUser "${webUser}" \
        --webGroup "${webGroup}" \
        --logPath "${logPath}" \
        --logLevel "${logLevel}" \
        --serverName "${serverName}" \
        --serverAdmin "${serverAdmin}" \
        --basicAuthUserName "${basicAuthUserName}" \
        --basicAuthPassword "${basicAuthPassword}" \
        --basicAuthUserFilePath "${basicAuthUserFilePath}" \
        --append yes
    else
      cosyses \
        --applicationName "${applicationName}" \
        --applicationVersion "${applicationVersion}" \
        --applicationScript "vhost/force-ssl.sh" \
        --httpPort "${httpPort}" \
        --sslPort "${sslPort}" \
        --webUser "${webUser}" \
        --webGroup "${webGroup}" \
        --logPath "${logPath}" \
        --logLevel "${logLevel}" \
        --serverName "${serverName}" \
        --serverAdmin "${serverAdmin}" \
        --append yes
    fi
  fi
else
  if [[ -n "${proxyHost}" ]] && [[ "${proxyHost}" != "-" ]]; then
    if [[ -n "${basicAuthUserName}" ]] && [[ "${basicAuthUserName}" != "-" ]]; then
      cosyses \
        --applicationName "${applicationName}" \
        --applicationVersion "${applicationVersion}" \
        --applicationScript "vhost/http-proxy-basic-auth.sh" \
        --httpPort "${httpPort}" \
        --webUser "${webUser}" \
        --webGroup "${webGroup}" \
        --proxyHostPath "${proxyHostPath}" \
        --proxyProtocol "${proxyProtocol}" \
        --proxyHost "${proxyHost}" \
        --proxyPort "${proxyPort}" \
        --proxyPath "${proxyPath}" \
        --logPath "${logPath}" \
        --logLevel "${logLevel}" \
        --serverName "${serverName}" \
        --serverAdmin "${serverAdmin}" \
        --basicAuthUserName "${basicAuthUserName}" \
        --basicAuthPassword "${basicAuthPassword}" \
        --basicAuthUserFilePath "${basicAuthUserFilePath}" \
        --append yes
    else
      cosyses \
        --applicationName "${applicationName}" \
        --applicationVersion "${applicationVersion}" \
        --applicationScript "vhost/http-proxy.sh" \
        --httpPort "${httpPort}" \
        --webUser "${webUser}" \
        --webGroup "${webGroup}" \
        --proxyHostPath "${proxyHostPath}" \
        --proxyProtocol "${proxyProtocol}" \
        --proxyHost "${proxyHost}" \
        --proxyPort "${proxyPort}" \
        --proxyPath "${proxyPath}" \
        --logPath "${logPath}" \
        --logLevel "${logLevel}" \
        --serverName "${serverName}" \
        --serverAdmin "${serverAdmin}" \
        --append yes
    fi
  else
    if [[ -n "${basicAuthUserName}" ]] && [[ "${basicAuthUserName}" != "-" ]]; then
      if [[ -n "${fpmHostName}" ]] && [[ "${fpmHostName}" != "-" ]] && [[ -n "${fpmHostPort}" ]] && [[ "${fpmHostPort}" != "-" ]]; then
        cosyses \
          --applicationName "${applicationName}" \
          --applicationVersion "${applicationVersion}" \
          --applicationScript "vhost/http-path-fpm-basic-auth.sh" \
          --httpPort "${httpPort}" \
          --webPath "${webPath}" \
          --webUser "${webUser}" \
          --webGroup "${webGroup}" \
          --logPath "${logPath}" \
          --logLevel "${logLevel}" \
          --serverName "${serverName}" \
          --serverAdmin "${serverAdmin}" \
          --fpmHostName "${fpmHostName}" \
          --fpmHostPort "${fpmHostPort}" \
          --basicAuthUserName "${basicAuthUserName}" \
          --basicAuthPassword "${basicAuthPassword}" \
          --basicAuthUserFilePath "${basicAuthUserFilePath}" \
          --append yes
      else
        cosyses \
          --applicationName "${applicationName}" \
          --applicationVersion "${applicationVersion}" \
          --applicationScript "vhost/http-path-basic-auth.sh" \
          --httpPort "${httpPort}" \
          --webPath "${webPath}" \
          --webUser "${webUser}" \
          --webGroup "${webGroup}" \
          --logPath "${logPath}" \
          --logLevel "${logLevel}" \
          --serverName "${serverName}" \
          --serverAdmin "${serverAdmin}" \
          --basicAuthUserName "${basicAuthUserName}" \
          --basicAuthPassword "${basicAuthPassword}" \
          --basicAuthUserFilePath "${basicAuthUserFilePath}" \
          --append yes
      fi
    else
      if [[ -n "${fpmHostName}" ]] && [[ "${fpmHostName}" != "-" ]] && [[ -n "${fpmHostPort}" ]] && [[ "${fpmHostPort}" != "-" ]]; then
        cosyses \
          --applicationName "${applicationName}" \
          --applicationVersion "${applicationVersion}" \
          --applicationScript "vhost/http-path-fpm.sh" \
          --httpPort "${httpPort}" \
          --webPath "${webPath}" \
          --webUser "${webUser}" \
          --webGroup "${webGroup}" \
          --logPath "${logPath}" \
          --logLevel "${logLevel}" \
          --serverName "${serverName}" \
          --serverAdmin "${serverAdmin}" \
          --fpmHostName "${fpmHostName}" \
          --fpmHostPort "${fpmHostPort}" \
          --append yes
      else
        cosyses \
          --applicationName "${applicationName}" \
          --applicationVersion "${applicationVersion}" \
          --applicationScript "vhost/http-path.sh" \
          --httpPort "${httpPort}" \
          --webPath "${webPath}" \
          --webUser "${webUser}" \
          --webGroup "${webGroup}" \
          --logPath "${logPath}" \
          --logLevel "${logLevel}" \
          --serverName "${serverName}" \
          --serverAdmin "${serverAdmin}" \
          --append yes
      fi
    fi
  fi
fi

if [[ ${sslTerminated} == "no" ]]; then
  if [[ -n "${proxyHost}" ]] && [[ "${proxyHost}" != "-" ]]; then
    if [[ -n "${basicAuthUserName}" ]] && [[ "${basicAuthUserName}" != "-" ]]; then
      cosyses \
        --applicationName "${applicationName}" \
        --applicationVersion "${applicationVersion}" \
        --applicationScript "vhost/ssl-proxy-basic-auth.sh" \
        --sslPort "${sslPort}" \
        --webUser "${webUser}" \
        --webGroup "${webGroup}" \
        --proxyHostPath "${proxyHostPath}" \
        --proxyProtocol "${proxyProtocol}" \
        --proxyHost "${proxyHost}" \
        --proxyPort "${proxyPort}" \
        --proxyPath "${proxyPath}" \
        --logPath "${logPath}" \
        --logLevel "${logLevel}" \
        --serverName "${serverName}" \
        --serverAdmin "${serverAdmin}" \
        --basicAuthUserName "${basicAuthUserName}" \
        --basicAuthPassword "${basicAuthPassword}" \
        --basicAuthUserFilePath "${basicAuthUserFilePath}" \
        --append yes
    else
      cosyses \
        --applicationName "${applicationName}" \
        --applicationVersion "${applicationVersion}" \
        --applicationScript "vhost/ssl-proxy.sh" \
        --sslPort "${sslPort}" \
        --webUser "${webUser}" \
        --webGroup "${webGroup}" \
        --proxyHostPath "${proxyHostPath}" \
        --proxyProtocol "${proxyProtocol}" \
        --proxyHost "${proxyHost}" \
        --proxyPort "${proxyPort}" \
        --proxyPath "${proxyPath}" \
        --logPath "${logPath}" \
        --logLevel "${logLevel}" \
        --serverName "${serverName}" \
        --serverAdmin "${serverAdmin}" \
        --append yes
    fi
  else
    if [[ -n "${basicAuthUserName}" ]] && [[ "${basicAuthUserName}" != "-" ]]; then
      if [[ -n "${fpmHostName}" ]] && [[ "${fpmHostName}" != "-" ]] && [[ -n "${fpmHostPort}" ]] && [[ "${fpmHostPort}" != "-" ]]; then
        cosyses \
          --applicationName "${applicationName}" \
          --applicationVersion "${applicationVersion}" \
          --applicationScript "vhost/ssl-path-fpm-basic-auth.sh" \
          --sslPort "${sslPort}" \
          --webPath "${webPath}" \
          --webUser "${webUser}" \
          --webGroup "${webGroup}" \
          --logPath "${logPath}" \
          --logLevel "${logLevel}" \
          --serverName "${serverName}" \
          --serverAdmin "${serverAdmin}" \
          --fpmHostName "${fpmHostName}" \
          --fpmHostPort "${fpmHostPort}" \
          --basicAuthUserName "${basicAuthUserName}" \
          --basicAuthPassword "${basicAuthPassword}" \
          --basicAuthUserFilePath "${basicAuthUserFilePath}" \
          --append yes
      else
        cosyses \
          --applicationName "${applicationName}" \
          --applicationVersion "${applicationVersion}" \
          --applicationScript "vhost/ssl-path-basic-auth.sh" \
          --sslPort "${sslPort}" \
          --webPath "${webPath}" \
          --webUser "${webUser}" \
          --webGroup "${webGroup}" \
          --logPath "${logPath}" \
          --logLevel "${logLevel}" \
          --serverName "${serverName}" \
          --serverAdmin "${serverAdmin}" \
          --basicAuthUserName "${basicAuthUserName}" \
          --basicAuthPassword "${basicAuthPassword}" \
          --basicAuthUserFilePath "${basicAuthUserFilePath}" \
          --append yes
      fi
    else
      if [[ -n "${fpmHostName}" ]] && [[ "${fpmHostName}" != "-" ]] && [[ -n "${fpmHostPort}" ]] && [[ "${fpmHostPort}" != "-" ]]; then
        cosyses \
          --applicationName "${applicationName}" \
          --applicationVersion "${applicationVersion}" \
          --applicationScript "vhost/ssl-path-fpm.sh" \
          --sslPort "${sslPort}" \
          --webPath "${webPath}" \
          --webUser "${webUser}" \
          --webGroup "${webGroup}" \
          --logPath "${logPath}" \
          --logLevel "${logLevel}" \
          --serverName "${serverName}" \
          --serverAdmin "${serverAdmin}" \
          --fpmHostName "${fpmHostName}" \
          --fpmHostPort "${fpmHostPort}" \
          --append yes
      else
        cosyses \
          --applicationName "${applicationName}" \
          --applicationVersion "${applicationVersion}" \
          --applicationScript "vhost/ssl-path.sh" \
          --sslPort "${sslPort}" \
          --webPath "${webPath}" \
          --webUser "${webUser}" \
          --webGroup "${webGroup}" \
          --logPath "${logPath}" \
          --logLevel "${logLevel}" \
          --serverName "${serverName}" \
          --serverAdmin "${serverAdmin}" \
          --append yes
      fi
    fi
  fi
fi

if [[ ! -f "/etc/apache2/sites-enabled/${serverName}.conf" ]]; then
  echo "Enabling configuration at: /etc/apache2/sites-enabled/${serverName}.conf"
  a2ensite "${serverName}.conf"
fi

if [[ ! -f /.dockerenv ]]; then
  echo "Restarting Apache"
  service apache2 restart
else
  echo "Reloading Apache"
  service apache2 reload
fi
