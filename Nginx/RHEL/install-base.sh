#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs Nginx from the mainline or stable repository of nginx.org for RHEL, which keep all versions of their current
lines. Fedora uses the packages for RHEL 10 (nginx.org has none for Fedora).

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

# Set by the version specific install.sh which sources this script
if [[ -z "${nginxVersion}" ]]; then
  >&2 echo "No Nginx version specified!"
  echo ""
  exit 1
fi

if [[ "${nginxRepository}" != "mainline" ]] && [[ "${nginxRepository}" != "stable" ]]; then
  >&2 echo "No Nginx repository (mainline/stable) specified!"
  echo ""
  exit 1
fi

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

# The self-signed certificate Ubuntu's package ssl-cert creates
install-package openssl
add-certificate "default" "${sslCertFile}" "${sslKeyFile}"

distributionId=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
if [[ "${distributionId}" == "fedora" ]]; then
  repositoryRelease="10"
else
  repositoryRelease=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | tr -d '"' | cut -d. -f1)
fi

# The priority hides the nginx packages of the distribution (Fedora's have a higher epoch), module_hotfixes the module
# streams of RHEL
if [[ "${nginxRepository}" == "mainline" ]]; then
  add-dnf-repository nginx "https://nginx.org/packages/mainline/rhel/${repositoryRelease}/\$basearch/" https://nginx.org/keys/nginx_signing.key module_hotfixes=1 priority=10
else
  add-dnf-repository nginx "https://nginx.org/packages/rhel/${repositoryRelease}/\$basearch/" https://nginx.org/keys/nginx_signing.key module_hotfixes=1 priority=10
fi
install-package nginx "${nginxVersion}"

rm -rf /var/log/nginx/*

nginxPidFile=$(awk '$1 == "pid" {print $2}' /etc/nginx/nginx.conf | tr -d ';' | head -n 1)
if [[ -z "${nginxPidFile}" ]]; then
  nginxPidFile="/run/nginx.pid"
fi

replace-file-content /etc/nginx/nginx.conf "nginx-access.log" "access.log"
replace-file-content /etc/nginx/nginx.conf "nginx-error.log" "error.log"
replace-file-content /etc/nginx/nginx.conf "sendfile off" "sendfile on"
replace-file-content /etc/nginx/nginx.conf "worker_connections  32768;" "worker_connections  1024;"
add-file-content-after /etc/nginx/nginx.conf "worker_rlimit_nofile 32768;" "pid        ${nginxPidFile};" 1

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
else
  systemctl enable nginx
  systemctl restart nginx
fi

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript default.sh \
  --httpPort "${httpPort}" \
  --sslPort "${sslPort}" \
  --sslCertFile "${sslCertFile}" \
  --sslKeyFile "${sslKeyFile}"
