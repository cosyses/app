#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  --help              Show this message
  --bindAddress       Bind address, default: 127.0.0.1
  --port              Port, default: 6081
  --adminBindAddress  Bind address for admin access, default: 127.0.0.1
  --adminPort         Admin port, default: 6082

Example: ${scriptName} --bindAddress 0.0.0.0
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

bindAddress=
port=
adminBindAddress=
adminPort=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${bindAddress}" ]]; then
  bindAddress="127.0.0.1"
fi

if [[ -z "${port}" ]]; then
  port="6081"
fi

if [[ -z "${adminBindAddress}" ]]; then
  adminBindAddress="127.0.0.1"
fi

if [[ -z "${adminPort}" ]]; then
  adminPort="6082"
fi

install-package apt-transport-https
install-package debian-archive-keyring
install-package curl
install-package gnupg
install-package libssl3
install-package libssl-dev
install-package-from-deb libjemalloc1 3.6.0-2 https://repo.percona.com/apt/pool/main/j/jemalloc/libjemalloc1_3.6.0-2.focal_amd64.deb
add-gpg-repository "varnish-cache-7.2.list" "https://packagecloud.io/varnishcache/varnish72/ubuntu/" "jammy" "main" "https://packagecloud.io/varnishcache/varnish72/gpgkey" "y"
install-package varnish 7.2

cp /etc/varnish/default.vcl /etc/varnish/varnish.vcl

if [[ ! -f /etc/varnish/secret ]]; then
  mkdir -p /etc/varnish
  dd if=/dev/random of=/etc/varnish/secret count=1
fi

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/varnish.sh"
  cat <<EOF > /usr/local/bin/varnish.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Varnish"
  cat /var/run/varnish.pid | xargs kill -15
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Varnish"
/usr/sbin/varnishd -a ${bindAddress}:${port} -T ${adminBindAddress}:${adminPort} -f /etc/varnish/varnish.vcl -S /etc/varnish/secret -s malloc,256m -P /var/run/varnish.pid
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/varnish.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-varnish.sh"
    cat <<EOF > /usr/local/lib/start/10-varnish.sh
#!/usr/bin/env bash
echo "Starting Varnish"
/usr/sbin/varnishd -a ${bindAddress}:${port} -T ${adminBindAddress}:${adminPort} -f /etc/varnish/varnish.vcl -S /etc/varnish/secret -s malloc,256m -P /var/run/varnish.pid
EOF
    chmod +x /usr/local/lib/start/10-varnish.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-varnish.sh"
    cat <<EOF > /usr/local/lib/stop/10-varnish.sh
#!/usr/bin/env bash
echo "Stopping Varnish"
cat /var/run/varnish.pid | xargs kill -15
EOF
    chmod +x /usr/local/lib/stop/10-varnish.sh
  fi
else
  service varnish stop
  update-rc.d -f varnish remove

  if [[ -f /etc/systemd/system/varnish.service ]]; then
    reloadDaemon=1
  else
    reloadDaemon=0
  fi

  cat <<EOF > /etc/systemd/system/varnish.service
[Unit]
Description=Varnish Cache, a high-performance HTTP accelerator
[Service]
Type=forking
LimitNOFILE=131072
LimitMEMLOCK=85983232
LimitCORE=infinity
ExecStart=/usr/sbin/varnishd -a ${bindAddress}:${port} -T ${adminBindAddress}:${adminPort} -f /etc/varnish/varnish.vcl -S /etc/varnish/secret -s malloc,256m
ExecReload=/usr/share/varnish/reload-vcl
[Install]
WantedBy=multi-user.target
EOF

  if [[ "${reloadDaemon}" == 1 ]]; then
    systemctl daemon-reload
  fi

  echo "Enabling Varnish autostart"
  systemctl enable varnish.service

  echo "Starting Varnish"
  service varnish start
fi
