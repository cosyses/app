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
  --help            Show this message
  --serverName      Server name
  --fpmHostName     Host name of PHP FPM instance, default: localhost
  --fpmHostPort     Port of PHP FPM instance, default: 9000
  --fpmIndexScript  Index script of FPM server, default: index.php
  --phpPath         Path of PHP, default: \.php$

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

serverName=
fpmHostName=
fpmHostPort=
fpmIndexScript=
phpPath=
source "${cosysesPath}/prepare-parameters.sh"

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

if [[ -z "${phpPath}" ]]; then
  phpPath="\.php\$"
fi

configurationFile="/etc/nginx/conf.d/${serverName}.conf"

cat <<EOF | tee -a "${configurationFile}" > /dev/null
  location ~ ${phpPath} {
    try_files \$uri =404;
    fastcgi_split_path_info ^(.+\.php)(/.+)\$;
    fastcgi_pass ${fpmHostName}:${fpmHostPort};
    include fastcgi_params;
    fastcgi_index ${fpmIndexScript};
    fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
    fastcgi_param DOCUMENT_ROOT \$realpath_root;
    fastcgi_param PATH_INFO \$fastcgi_path_info;
    fastcgi_param QUERY_STRING \$query_string;
    fastcgi_buffers 1024 8k;
    fastcgi_buffer_size 128k;
    fastcgi_busy_buffers_size 128k;
  }
EOF
