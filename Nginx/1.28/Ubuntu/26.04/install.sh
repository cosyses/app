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
  --sslPort      SSL Port, default: 443
  --sslCertFile  SSL certificate file, default: /etc/ssl/certs/ssl-cert-snakeoil.pem
  --sslKeyFile   SSL key file, default: /etc/ssl/private/ssl-cert-snakeoil.key

Example: ${scriptFileName} --httpPort 80 --sslPort 443
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

# nginx.org builds no 1.28 for Ubuntu 26.04 (its stable line there starts with 1.30), Ubuntu 26.04 itself has 1.28
nginxVersion="1.28"
nginxPidFile="/run/nginx.pid"

httpPort=
sslPort=
sslCertFile=
sslKeyFile=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${httpPort}" ]]; then
  httpPort="80"
fi

if [[ -z "${sslPort}" ]]; then
  sslPort="443"
fi

if [[ -n "${sslCertFile}" ]] && [[ ! -f "${sslCertFile}" ]]; then
  echo "Invalid SSL certificate file specified!"
  exit 1
fi

if [[ -z "${sslCertFile}" ]]; then
  sslCertFile="/etc/ssl/certs/ssl-cert-snakeoil.pem"
fi

if [[ -n "${sslKeyFile}" ]] && [[ ! -f "${sslKeyFile}" ]]; then
  echo "Invalid SSL key file specified!"
  exit 1
fi

if [[ -z "${sslKeyFile}" ]]; then
  sslKeyFile="/etc/ssl/private/ssl-cert-snakeoil.key"
fi

install-package ssl-cert
add-certificate "default" "${sslCertFile}" "${sslKeyFile}"

install-package nginx "${nginxVersion}"

# The package of Ubuntu runs as www-data and has a default site in sites-enabled, the configurations of the vhost
# scripts are added to conf.d as with the packages of nginx.org
rm -f /etc/nginx/sites-enabled/default

add-file-content-before /etc/security/limits.conf "www-data    soft    nofile  32768" "# End of file" 1
add-file-content-before /etc/security/limits.conf "www-data    hard    nofile  65536" "# End of file" 1
if [[ -f /etc/sysctl.conf ]]; then
  sysctl -p
fi

service nginx stop

rm -rf /var/log/nginx/*

replace-file-content /etc/nginx/nginx.conf "nginx-access.log" "access.log"
replace-file-content /etc/nginx/nginx.conf "nginx-error.log" "error.log"
replace-file-content /etc/nginx/nginx.conf "sendfile off" "sendfile on"
replace-file-content /etc/nginx/nginx.conf "worker_connections  32768;" "worker_connections  1024;"
add-file-content-after /etc/nginx/nginx.conf "worker_rlimit_nofile 32768;" "pid        ${nginxPidFile};" 1

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
else
  service nginx start
fi

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript default.sh \
  --httpPort "${httpPort}" \
  --sslPort "${sslPort}" \
  --sslCertFile "${sslCertFile}" \
  --sslKeyFile "${sslKeyFile}"
