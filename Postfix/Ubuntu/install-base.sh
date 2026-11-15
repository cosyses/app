#!/bin/bash -e

# Set by the version specific install.sh which sources this script
if [[ -z "${postfixVersion}" ]]; then
  >&2 echo "No Postfix version set!"
  echo ""
  exit 1
fi

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Installs Postfix and the mail command (mailutils) from the packages of the release.

usage: ${scriptFileName} options

OPTIONS:
  --help            Show this message
  --mailName        Domain of the mail addresses of this host (/etc/mailname), default: fully qualified host name
  --mailerType      Type of the mail server (Internet Site, Satellite system), default: Internet Site
  --relayHost       Host to send all mails to (optional, required for Satellite system), e.g. [smtp.example.com]:587
  --inetInterfaces  Interfaces to receive mails on, default: all (Internet Site) or loopback-only (Satellite system)

Example: ${scriptFileName} --mailName example.com --mailerType "Satellite system" --relayHost "[smtp.example.com]:587"
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

mailName=
mailerType=
relayHost=
inetInterfaces=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${mailName}" ]]; then
  mailName=$(hostname -f 2>/dev/null || hostname)
fi

if [[ -z "${mailerType}" ]]; then
  mailerType="Internet Site"
fi

if [[ "${mailerType}" != "Internet Site" ]] && [[ "${mailerType}" != "Satellite system" ]]; then
  >&2 echo "Invalid mailer type: ${mailerType}"
  usage
  exit 1
fi

if [[ "${mailerType}" == "Satellite system" ]] && [[ -z "${relayHost}" ]]; then
  >&2 echo "No relay host specified!"
  usage
  exit 1
fi

if [[ -z "${inetInterfaces}" ]]; then
  if [[ "${mailerType}" == "Satellite system" ]]; then
    inetInterfaces="loopback-only"
  else
    inetInterfaces="all"
  fi
fi

echo "Preparing installation of Postfix with mail name: ${mailName} and type: ${mailerType}"
debconf-set-selections <<< "postfix postfix/mailname string ${mailName}"
debconf-set-selections <<< "postfix postfix/main_mailer_type select ${mailerType}"
debconf-set-selections <<< "postfix postfix/relayhost string ${relayHost}"

install-package postfix "${postfixVersion}"
install-package mailutils

# The answers above only apply to the first installation, so the settings are also written directly
echo "Setting mail name: ${mailName}"
echo "${mailName}" > /etc/mailname

echo "Setting relay host: ${relayHost}"
postconf -e "relayhost = ${relayHost}"

echo "Setting interfaces: ${inetInterfaces}"
postconf -e "inet_interfaces = ${inetInterfaces}"

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/postfix.sh"
  cat <<EOF > /usr/local/bin/postfix.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Postfix"
  postfix stop
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Postfix"
postfix start
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/postfix.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-postfix.sh"
    cat <<EOF > /usr/local/lib/start/10-postfix.sh
#!/usr/bin/env bash
echo "Starting Postfix"
postfix start
EOF
    chmod +x /usr/local/lib/start/10-postfix.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-postfix.sh"
    cat <<EOF > /usr/local/lib/stop/10-postfix.sh
#!/usr/bin/env bash
echo "Stopping Postfix"
postfix stop
EOF
    chmod +x /usr/local/lib/stop/10-postfix.sh
  fi
else
  echo "Restarting Postfix"
  service postfix restart

  echo "Enabling autostart"
  systemctl enable postfix
fi
