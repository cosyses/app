#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs Nginx from the stable repository of nginx.org, which keeps all versions of its current line.

OPTIONS:
  --help Show this message

Example: ${scriptFileName}
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

source "${cosysesPath}/prepare-parameters.sh"

nginxVersion="1.30"
release=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | tr -d '"' | cut -f1-2 -d".")

add-apk-repository "https://nginx.org/packages/alpine/v${release}/main" "https://nginx.org/keys/nginx_signing.rsa.pub"
install-package nginx "${nginxVersion}"

rm -rf /var/log/nginx/*

replace-file-content /etc/nginx/nginx.conf "sendfile        on" "sendfile        off"

usermod -a -G www-data nginx

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/nginx.sh"
  cat <<EOF > /usr/local/bin/nginx.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Nginx"
  /usr/sbin/nginx -s quit
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Nginx"
/usr/sbin/nginx -c /etc/nginx/nginx.conf &
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/nginx.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-nginx.sh"
    cat <<EOF > /usr/local/lib/start/10-nginx.sh
#!/usr/bin/env bash
echo "Starting Nginx"
/usr/sbin/nginx -c /etc/nginx/nginx.conf
EOF
    chmod +x /usr/local/lib/start/10-nginx.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-nginx.sh"
    cat <<EOF > /usr/local/lib/stop/10-nginx.sh
#!/usr/bin/env bash
echo "Stopping Nginx"
/usr/sbin/nginx -s quit
EOF
    chmod +x /usr/local/lib/stop/10-nginx.sh
  fi
elif [[ -x "$(command -v rc-service)" ]]; then
  echo "Starting service"
  rc-update add nginx default
  rc-service nginx restart
fi
