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
  --help      Show this message
  --smtpIp    IP address of SMTP Server, default: 0.0.0.0
  --smtpPort  Port of SMTP Server, default: 1025
  --httpIp    IP address of HTTP Server, default: 0.0.0.0
  --httpPort  Port of HTTP Server, default: 1080

Example: ${scriptFileName} --smtpPort 1025 --httpPort 1080
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

smtpIp=
smtpPort=
httpIp=
httpPort=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${smtpIp}" ]]; then
  smtpIp="0.0.0.0"
fi

if [[ -z "${smtpPort}" ]]; then
  smtpPort=1025
fi

if [[ -z "${httpIp}" ]]; then
  httpIp="0.0.0.0"
fi

if [[ -z "${httpPort}" ]]; then
  httpPort=1080
fi

cosyses \
  --applicationName Ruby

install-package openssl
install-package libssl-dev
install-package libreadline-dev
install-package libgdbm-dev
install-package libsqlite3-dev
install-package make
install-package gcc
install-package g++

install-gem mime-types 2.99.1
install-gem mailcatcher 0.6.5

if [[ ! -f /.dockerenv ]]; then
  echo "Creating service at: /etc/systemd/system/mailcatcher.service"
  cat <<EOF > /etc/systemd/system/mailcatcher.service
[Unit]
Description = MailCatcher
After=network.target
After=systemd-user-sessions.service
[Service]
Type=simple
Restart=on-failure
User=root
ExecStart=$(which mailcatcher) --foreground --smtp-ip ${smtpIp} --smtp-port ${smtpPort} --http-ip ${httpIp} --http-port ${httpPort}
[Install]
WantedBy=multi-user.target
EOF
  chmod 744 /etc/systemd/system/mailcatcher.service

  echo "Enabling mailcatcher service"
  systemctl enable mailcatcher.service

  echo "Starting mailcatcher service"
  service mailcatcher start
  service mailcatcher status
else
  install-package lsof

  echo "Creating start script at: /usr/local/bin/mailcatcher.sh"
  cat <<EOF > /usr/local/bin/mailcatcher.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping MailCatcher"
  lsof -nP -iTCP:${smtpPort} -sTCP:LISTEN | awk 'NR > 1 {print \$2}' | xargs kill -15
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting MailCatcher"
$(which mailcatcher) \
  --smtp-ip ${smtpIp} \
  --smtp-port ${smtpPort} \
  --http-ip ${httpIp} \
  --http-port ${httpPort} &
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/mailcatcher.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-mailcatcher.sh"
    cat <<EOF > /usr/local/lib/start/10-mailcatcher.sh
#!/usr/bin/env bash
echo "Starting MailCatcher"
$(which mailcatcher) \
  --smtp-ip ${smtpIp} \
  --smtp-port ${smtpPort} \
  --http-ip ${httpIp} \
  --http-port ${httpPort} &
EOF
    chmod +x /usr/local/lib/start/10-mailcatcher.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-mailcatcher.sh"
    cat <<EOF > /usr/local/lib/stop/10-mailcatcher.sh
#!/usr/bin/env bash
echo "Stopping MailCatcher"
lsof -nP -iTCP:${smtpPort} -sTCP:LISTEN | awk 'NR > 1 {print \$2}' | xargs kill -15
EOF
    chmod +x /usr/local/lib/stop/10-mailcatcher.sh
  fi
fi
