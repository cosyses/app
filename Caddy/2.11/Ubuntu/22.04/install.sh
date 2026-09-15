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

add-gpg-repository "caddy.list" "https://dl.cloudsmith.io/public/caddy/stable/deb/debian" "any-version" "main" "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" "n"
install-package caddy 2.11

echo "Creating configuration at: /etc/caddy/Caddyfile"
cat <<EOF >/etc/caddy/Caddyfile
{
  local_certs
  skip_install_trust
  http_port ${httpPort}
  https_port ${sslPort}
  auto_https off
  default_bind 0.0.0.0
}
EOF

rm -rf /var/log/caddy/*

usermod -a -G www-data caddy

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/caddy.sh"
  cat <<EOF > /usr/local/bin/caddy.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Caddy"
  cat /var/run/caddy.pid | xargs kill -15
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Caddy"
/usr/bin/caddy run --config /etc/caddy/Caddyfile --pidfile /var/run/caddy.pid &
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/caddy.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-caddy.sh"
    cat <<EOF > /usr/local/lib/start/10-caddy.sh
#!/usr/bin/env bash
echo "Starting Caddy"
/usr/bin/caddy start --config /etc/caddy/Caddyfile --pidfile /var/run/caddy.pid
EOF
    chmod +x /usr/local/lib/start/10-caddy.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-caddy.sh"
    cat <<EOF > /usr/local/lib/stop/10-caddy.sh
#!/usr/bin/env bash
echo "Stopping Caddy"
caddy stop --config /etc/caddy/Caddyfile
EOF
    chmod +x /usr/local/lib/stop/10-caddy.sh
  fi
fi

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript default.sh \
  --httpPort "${httpPort}" \
  --sslPort "${sslPort}" \
  --sslCertFile "${sslCertFile}" \
  --sslKeyFile "${sslKeyFile}"
