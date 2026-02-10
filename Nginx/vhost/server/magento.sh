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
  location ~* ^/setup(\$|/) {
    root ${webPath};
    location ~ ^/setup/index.php {
      # Prevent blank magento setup screen. Maybe remove this if you have problems.
      fastcgi_split_path_info ^(.+?\.php)(/.*)\$;
      fastcgi_pass ${fpmHostName}:${fpmHostPort};
      fastcgi_index ${fpmIndexScript};
      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
      include fastcgi_params;
    }
    location ~ ^/setup/(?!pub/). {
      deny all;
    }
    location ~ ^/setup/pub/ {
      add_header X-Frame-Options "SAMEORIGIN";
    }
  }
  location ~* ^/update(\$|/) {
    root ${webPath};
    location ~ ^/update/index.php {
      fastcgi_split_path_info ^(/update/index.php)(/.+)\$;
      fastcgi_pass ${fpmHostName}:${fpmHostPort};
      fastcgi_index ${fpmIndexScript};
      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
      fastcgi_param PATH_INFO \$fastcgi_path_info;
      include fastcgi_params;
    }
    # Deny everything but index.php
    location ~ ^/update/(?!pub/). {
      deny all;
    }
    location ~ ^/update/pub/ {
      add_header X-Frame-Options "SAMEORIGIN";
    }
  }
  location / {
    try_files \$uri \$uri/ /index.php?\$args;
  }
  location /pub/ {
    location ~ ^/pub/media/(downloadable|customer|import|theme_customization/.*\.xml) {
      deny all;
    }
    alias ${webPath}/pub/;
    add_header X-Frame-Options "SAMEORIGIN";
  }
  location /static/ {
    expires max;
    location ~ ^/static/version {
      rewrite ^/static/(version\d*/)?(.*)\$ /static/\$2 last;
    }
    location ~* \.(ico|jpg|jpeg|png|gif|svg|js|css|swf|eot|ttf|otf|woff|woff2)\$ {
      add_header Cache-Control "public";
      add_header X-Frame-Options "SAMEORIGIN";
      expires +1y;
      if (!-f \$request_filename) {
        rewrite ^/static/(version\d*/)?(.*)\$ /static.php?resource=\$2 last;
      }
    }
    location ~* \.(zip|gz|gzip|bz2|csv|xml)\$ {
      add_header Cache-Control "no-store";
      add_header X-Frame-Options "SAMEORIGIN";
      expires off;
      if (!-f \$request_filename) {
        rewrite ^/static/(version\d*/)?(.*)\$ /static.php?resource=\$2 last;
      }
    }
    if (!-f \$request_filename) {
      rewrite ^/static/(version\d*/)?(.*)\$ /static.php?resource=\$2 last;
    }
    add_header X-Frame-Options "SAMEORIGIN";
  }
  location /media/ {
    try_files \$uri \$uri/ /get.php?\$args;
    location ~ ^/media/theme_customization/.*\.xml {
      deny all;
    }
    location ~* \.(ico|jpg|jpeg|png|gif|svg|js|css|swf|eot|ttf|otf|woff|woff2)\$ {
      add_header Cache-Control "public";
      add_header X-Frame-Options "SAMEORIGIN";
      expires +1y;
      try_files \$uri \$uri/ /get.php?\$args;
    }
    location ~* \.(zip|gz|gzip|bz2|csv|xml)\$ {
      add_header Cache-Control "no-store";
      add_header X-Frame-Options "SAMEORIGIN";
      expires off;
      try_files \$uri \$uri/ /get.php?\$args;
    }
    add_header X-Frame-Options "SAMEORIGIN";
  }
  location /media/customer/ {
    deny all;
  }
  location /media/downloadable/ {
    deny all;
  }
  location /media/import/ {
    deny all;
  }
  location ~* (\.php\$|\.htaccess\$|\.git) {
    deny all;
  }
  gzip on;
  gzip_disable "msie6";
  gzip_comp_level 6;
  gzip_min_length 1100;
  gzip_buffers 16 8k;
  gzip_proxied any;
  gzip_types
    text/plain
    text/css
    text/js
    text/xml
    text/javascript
    application/javascript
    application/x-javascript
    application/json
    application/xml
    application/xml+rss
      image/svg+xml;
  gzip_vary on;
EOF
