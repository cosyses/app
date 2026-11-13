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
  --sslPort      SSL port, default: 443
  --dynamicPath  Directory with the dynamic configuration (routers and services), watched for changes,
                 default: /etc/traefik/dynamic
  --logLevel     Log level (TRACE, DEBUG, INFO, WARN, ERROR), default: INFO
  --dashboard    Enable the dashboard and API (yes/no), default: no
                 They are only reached through a router with the service api@internal in the dynamic
                 configuration, the dashboard at the path /dashboard/

Example: ${scriptFileName} --httpPort 80 --sslPort 443 --dynamicPath /etc/traefik/dynamic --dashboard yes
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

httpPort=
sslPort=
dynamicPath=
logLevel=
dashboard=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${httpPort}" ]]; then
  httpPort="80"
fi

if [[ -z "${sslPort}" ]]; then
  sslPort="443"
fi

if [[ -z "${dynamicPath}" ]]; then
  dynamicPath="/etc/traefik/dynamic"
fi

if [[ -z "${logLevel}" ]]; then
  logLevel="INFO"
fi

if [[ -z "${dashboard}" ]]; then
  dashboard="no"
fi

if [[ "${dashboard}" != "yes" ]] && [[ "${dashboard}" != "no" ]]; then
  >&2 echo "Invalid value for dashboard: ${dashboard}, use yes or no"
  exit 1
fi

traefikVersion="3.7.17"

case "$(dpkg --print-architecture)" in
  amd64) traefikArchitecture="amd64";;
  arm64) traefikArchitecture="arm64";;
  *) >&2 echo "Unsupported architecture: $(dpkg --print-architecture)"; exit 1;;
esac

install-package ca-certificates
install-package wget

traefikArchive="traefik_v${traefikVersion}_linux_${traefikArchitecture}.tar.gz"
traefikDownloadUrl="https://github.com/traefik/traefik/releases/download/v${traefikVersion}"
traefikDownloadPath=$(mktemp -d)

echo "Downloading Traefik ${traefikVersion} from: ${traefikDownloadUrl}/${traefikArchive}"
wget -nv "${traefikDownloadUrl}/${traefikArchive}" -O "${traefikDownloadPath}/${traefikArchive}" 2>&1
wget -nv "${traefikDownloadUrl}/traefik_v${traefikVersion}_checksums.txt" -O "${traefikDownloadPath}/checksums.txt" 2>&1

echo "Verifying checksum of: ${traefikArchive}"
(cd "${traefikDownloadPath}" && grep " ${traefikArchive}\$" checksums.txt | sha256sum --check --strict)

tar -xzf "${traefikDownloadPath}/${traefikArchive}" -C "${traefikDownloadPath}" traefik
install -m 0755 "${traefikDownloadPath}/traefik" /usr/local/bin/traefik
rm -rf "${traefikDownloadPath}"
traefik version

mkdir -p /etc/traefik "${dynamicPath}" /var/log/traefik

echo "Creating configuration at: /etc/traefik/traefik.yml"
cat <<EOF >/etc/traefik/traefik.yml
entryPoints:
  web:
    address: ":${httpPort}"
  websecure:
    address: ":${sslPort}"
providers:
  file:
    directory: "${dynamicPath}"
    watch: true
log:
  level: "${logLevel}"
  noColor: true
accessLog:
  filePath: "/var/log/traefik/access.log"
global:
  checkNewVersion: false
  sendAnonymousUsage: false
EOF

if [[ "${dashboard}" == "yes" ]]; then
  echo "Enabling dashboard and API"
  cat <<EOF >>/etc/traefik/traefik.yml
api:
  dashboard: true
EOF
fi

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/traefik.sh"
  cat <<EOF > /usr/local/bin/traefik.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Traefik"
  cat /var/run/traefik.pid | xargs kill -15
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Traefik"
/usr/local/bin/traefik --configFile=/etc/traefik/traefik.yml >>/var/log/traefik/traefik.log 2>&1 &
echo "\$!" > /var/run/traefik.pid
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/traefik.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-traefik.sh"
    cat <<EOF > /usr/local/lib/start/10-traefik.sh
#!/usr/bin/env bash
echo "Starting Traefik"
nohup /usr/local/bin/traefik --configFile=/etc/traefik/traefik.yml >>/var/log/traefik/traefik.log 2>&1 &
echo "\$!" > /var/run/traefik.pid
EOF
    chmod +x /usr/local/lib/start/10-traefik.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-traefik.sh"
    cat <<EOF > /usr/local/lib/stop/10-traefik.sh
#!/usr/bin/env bash
echo "Stopping Traefik"
if [[ -f /var/run/traefik.pid ]]; then
  kill -15 "\$(cat /var/run/traefik.pid)" 2>/dev/null || true
  rm -f /var/run/traefik.pid
fi
EOF
    chmod +x /usr/local/lib/stop/10-traefik.sh
  fi
fi
