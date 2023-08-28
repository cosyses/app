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

if [[ -z "${sslCertFile}" ]]; then
  sslCertFile="/etc/ssl/certs/ssl-cert-snakeoil.pem"
fi

if [[ ! -f "${sslCertFile}" ]]; then
  echo "Invalid SSL certificate file specified!"
  exit 1
fi

if [[ -z "${sslKeyFile}" ]]; then
  sslKeyFile="/etc/ssl/private/ssl-cert-snakeoil.key"
fi

if [[ ! -f "${sslKeyFile}" ]]; then
  echo "Invalid SSL key file specified!"
  exit 1
fi

echo "Creating configuration at: /etc/apache2/sites-available/000-default.conf"
cat << EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:${httpPort}>
  ServerAdmin webmaster@localhost.local
  DocumentRoot /var/www/html/
  <Directory /var/www/html/>
    Options Indexes FollowSymLinks MultiViews
    AllowOverride None
    Order allow,deny
    Allow from all
  </Directory>
  LogLevel warn
  ErrorLog \${APACHE_LOG_DIR}/default-http-error.log
  CustomLog \${APACHE_LOG_DIR}/default-http-access.log combined
</VirtualHost>
<IfModule mod_ssl.c>
  SSLCertificateFile ${sslCertFile}
  SSLCertificateKeyFile ${sslKeyFile}
  BrowserMatch \"MSIE [2-6]\" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0
  BrowserMatch \"MSIE [17-9]\" ssl-unclean-shutdown
  <FilesMatch \"\.(cgi|shtml|phtml|php)\$\">
    SSLOptions +StdEnvVars
  </FilesMatch>
  <VirtualHost *:${sslPort}>
    SSLEngine on
    ServerAdmin webmaster@localhost.local
    DocumentRoot /var/www/html/
    <Directory /var/www/html/>
      Options Indexes FollowSymLinks MultiViews
      AllowOverride None
      Order allow,deny
      Allow from all
    </Directory>
    LogLevel warn
    ErrorLog \${APACHE_LOG_DIR}/default-ssl-error.log
    CustomLog \${APACHE_LOG_DIR}/default-ssl-access.log combined
  </VirtualHost>
</IfModule>
EOF

if [[ -f /.dockerenv ]]; then
  echo "Reloading Apache"
  sudo service apache2 reload
else
  echo "Restarting Apache"
  sudo service apache2 restart
fi
