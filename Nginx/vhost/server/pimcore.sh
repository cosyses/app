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
  --webPath         Web path
  --fpmHostName     Host name of PHP FPM instance, default: localhost
  --fpmHostPort     Port of PHP FPM instance, default: 9000
  --fpmIndexScript  Index script of FPM server, default: index.php

Example: ${scriptFileName} --webPath /var/www/project01/htdocs --serverName project01.net
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

serverName=
webPath=
fpmHostName=
fpmHostPort=
fpmIndexScript=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${serverName}" ]]; then
  echo "No server name specified!"
  exit 1
fi

if [[ -z "${webPath}" ]]; then
  echo "No web path specified!"
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

configurationFile="/etc/nginx/conf.d/${serverName}.conf"

cat <<EOF | tee -a "${configurationFile}" > /dev/null
  # Pimcore Head-Link Cache-Busting
  rewrite ^/cache-buster-(?:\d+)/(.*) /\$1 last;
  location ~* /var/assets/.*\.php(/|\$) {
    return 404;
  }
  location ~* /\.(?!well-known/) {
    deny all;
    log_not_found off;
    access_log off;
  }
  location ~* (?:\.(?:bak|conf(ig)?|dist|fla|in[ci]|log|psd|sh|sql|sw[op])|~)\$ {
    deny all;
  }
  location ~* ^/admin/external {
    rewrite .* /index.php\$is_args\$args last;
  }
  location ~* .*/(image|video)-thumb__\d+__.* {
    try_files /var/tmp/thumbnails\$uri /index.php;
    expires 2w;
    access_log off;
    add_header Cache-Control "public";
  }
  location ~* ^(?!/admin|/asset/webdav)(.+?)\.((?:css|js)(?:\.map)?|jpe?g|gif|png|svgz?|eps|exe|gz|zip|mp\d|m4a|ogg|ogv|webp|webm|pdf|docx?|xlsx?|pptx?)\$ {
    try_files /var/assets\$uri \$uri =404;
    expires 2w;
    access_log off;
    log_not_found off;
    add_header Cache-Control "public";
  }
EOF
