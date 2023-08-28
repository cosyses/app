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

install-package apache2-bin 2.4
install-package apache2-data 2.4
install-package apache2 2.4
a2enmod rewrite ssl headers expires

service apache2 stop

rm -rf /var/log/apache2/*

echo "ServerName localhost" > /etc/apache2/conf-available/server.conf
echo "EnableSendfile off" >> /etc/apache2/conf-available/server.conf
a2enconf server.conf

replace-file-content /etc/apache2/ports.conf "Listen ${httpPort}" "Listen 80"
replace-file-content /etc/apache2/ports.conf "Listen ${sslPort}" "Listen 443"

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/apache.sh"
  cat <<EOF > /usr/local/bin/apache.sh
#!/bin/bash -e
/usr/sbin/apache2ctl -D FOREGROUND
EOF
  chmod +x /usr/local/bin/apache.sh
else
  echo "Starting Apache"
  service apache2 start
fi

mkdir -p /opt/install/
crudini --set /opt/install/env.properties apache version "${applicationVersion}"
crudini --set /opt/install/env.properties apache httpPort "${httpPort}"
crudini --set /opt/install/env.properties apache sslPort "${sslPort}"

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript default.sh \
  --httpPort "${httpPort}" \
  --sslPort "${sslPort}" \
  --sslCertFile "${sslCertFile}" \
  --sslKeyFile "${sslKeyFile}"
