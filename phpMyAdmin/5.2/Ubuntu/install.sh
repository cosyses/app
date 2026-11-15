#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Installs phpMyAdmin from the release archive (checksum verified) into a path, creates the control user and the tables of
the phpMyAdmin configuration storage and writes config.inc.php with a generated blowfish secret. PHP must be installed
first, the PHP extensions phpMyAdmin needs are added. With a server name, a virtual host of Nginx or Apache is created.

usage: ${scriptFileName} options

OPTIONS:
  --help                  Show this message
  --installPath           Path to install phpMyAdmin to (replaced if it exists), default: /var/www/phpmyadmin
  --phpVersion            PHP version, default: version of the php command
  --databaseType          Database server (MySQL, MariaDB), default: MySQL
  --databaseVersion       Version of the database routines, default: 8.4 (MySQL) or 11.4 (MariaDB)
  --databaseHost          Database host, default: 127.0.0.1
  --databasePort          Database port, default: 3306
  --databaseRootUser      Root user to create the control user and tables, default: root
  --databaseRootPassword  Root password
  --controlUser           Name of the control user, default: pma
  --controlPassword       Password of the control user, default: <generated>, required if the user already exists
  --controlDatabase       Database of the configuration storage, default: phpmyadmin
  --serverName            Server name of the virtual host (optional, no virtual host without it)
  --webServer             Web server of the virtual host (Nginx, Apache), default: Nginx
  --webServerVersion      Version of the web server routines, default: version of the installed web server
  --httpPort              HTTP port of the virtual host, default of vhost.sh: 80
  --sslPort               SSL port of the virtual host, default of vhost.sh: 443
  --sslTerminated         SSL terminated (yes/no), default of vhost.sh: no
  --forceSsl              Force SSL (yes/no), default of vhost.sh: yes
  --fpmHostName           Host name of PHP FPM, default: 127.0.0.1 (Nginx)
  --fpmHostPort           Port of PHP FPM, default: 3000 (Nginx, the port of the Cosyses PHP FPM installation)
  --basicAuthUserName     Basic auth user name (optional)
  --basicAuthPassword     Basic auth password (optional)
  --overwrite             Overwrite an existing virtual host (yes/no), default: no

Example: ${scriptFileName} --databaseRootPassword secret --serverName pma.example.com --forceSsl no
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

installPath=
phpVersion=
databaseType=
databaseVersion=
databaseHost=
databasePort=
databaseRootUser=
databaseRootPassword=
controlUser=
controlPassword=
controlDatabase=
serverName=
webServer=
webServerVersion=
httpPort=
sslPort=
sslTerminated=
forceSsl=
fpmHostName=
fpmHostPort=
basicAuthUserName=
basicAuthPassword=
overwrite=
source "${cosysesPath}/prepare-parameters.sh"

phpmyadminVersion="5.2.3"
phpmyadminChecksum="2d2e13c735366d318425c78e4ee2cc8fc648d77faba3ddea2cd516e43885733f"

if [[ -z "${installPath}" ]]; then
  installPath="/var/www/phpmyadmin"
fi
installPath="${installPath%/}"

if [[ -z "${phpVersion}" ]]; then
  if [[ -z "$(command -v php)" ]]; then
    >&2 echo "No PHP installed!"
    usage
    exit 1
  fi
  phpVersion=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')
fi

if [[ -z "${databaseType}" ]]; then
  databaseType="MySQL"
fi

if [[ -z "${databaseVersion}" ]]; then
  if [[ "${databaseType}" == "MariaDB" ]]; then
    databaseVersion="11.4"
  else
    databaseVersion="8.4"
  fi
fi

if [[ -z "${databaseHost}" ]] || [[ "${databaseHost}" == "localhost" ]]; then
  databaseHost="127.0.0.1"
fi

if [[ -z "${databasePort}" ]]; then
  databasePort="3306"
fi

if [[ -z "${databaseRootUser}" ]]; then
  databaseRootUser="root"
fi

if [[ -z "${databaseRootPassword}" ]]; then
  >&2 echo "No database root password specified!"
  usage
  exit 1
fi

if [[ -z "${controlUser}" ]]; then
  controlUser="pma"
fi

if [[ -z "${controlDatabase}" ]]; then
  controlDatabase="phpmyadmin"
fi

if [[ -z "${webServer}" ]]; then
  webServer="Nginx"
fi

if [[ "${webServer}" != "Nginx" ]] && [[ "${webServer}" != "Apache" ]]; then
  >&2 echo "Invalid web server: ${webServer}"
  usage
  exit 1
fi

if [[ -n "${serverName}" ]] && [[ -z "${webServerVersion}" ]]; then
  if [[ "${webServer}" == "Nginx" ]] && [[ -n "$(command -v nginx)" ]]; then
    webServerVersion=$(nginx -v 2>&1 | grep -oP '(?<=nginx/)\d+\.\d+')
  elif [[ "${webServer}" == "Apache" ]] && [[ -n "$(command -v apache2)" ]]; then
    webServerVersion=$(apache2 -v | grep -oP '(?<=Apache/)\d+\.\d+')
  fi
  if [[ -z "${webServerVersion}" ]]; then
    >&2 echo "No ${webServer} installed!"
    usage
    exit 1
  fi
fi

if [[ "${webServer}" == "Nginx" ]]; then
  if [[ -z "${fpmHostName}" ]]; then
    fpmHostName="127.0.0.1"
  fi
  if [[ -z "${fpmHostPort}" ]]; then
    fpmHostPort="3000"
  fi
fi

if [[ -z "$(command -v mysql)" ]]; then
  >&2 echo "No MySQL client installed!"
  exit 1
fi

export MYSQL_PWD="${databaseRootPassword}"
controlUserCount=$(mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -N -B -e "SELECT COUNT(*) FROM mysql.user WHERE User = '${controlUser}';")
unset MYSQL_PWD

if [[ "${controlUserCount}" -gt 0 ]] && [[ -z "${controlPassword}" ]]; then
  >&2 echo "The control user: ${controlUser} already exists, its password must be specified!"
  exit 1
fi

echo "Installing PHP extensions for phpMyAdmin"
cosyses \
  --applicationName PHP \
  --applicationVersion "${phpVersion}" \
  --applicationScript "extension.sh" \
  --extensions "mysql,mbstring,xml,zip,gd,curl,bz2"

# a running FPM or Apache only loads the new extensions after a restart
if [[ -f /.dockerenv ]]; then
  fpmPid=$(pgrep -f "php-fpm: master process.*/${phpVersion}/" || true)
  if [[ -n "${fpmPid}" ]]; then
    echo "Reloading PHP FPM"
    kill -USR2 "${fpmPid}"
  fi
  if [[ -d "/etc/php/${phpVersion}/apache2" ]] && pgrep -x apache2 >/dev/null; then
    echo "Reloading Apache"
    apache2ctl graceful
  fi
else
  if [[ -d "/etc/php/${phpVersion}/fpm" ]]; then
    echo "Restarting PHP FPM"
    service "php${phpVersion}-fpm" restart
  fi
  if [[ -d "/etc/php/${phpVersion}/apache2" ]] && [[ -n "$(command -v apache2)" ]]; then
    echo "Restarting Apache"
    service apache2 restart
  fi
fi

install-package wget
install-package unzip

downloadPath=$(mktemp -d)
archiveName="phpMyAdmin-${phpmyadminVersion}-all-languages"
echo "Downloading phpMyAdmin ${phpmyadminVersion}"
wget -nv -O "${downloadPath}/${archiveName}.zip" "https://files.phpmyadmin.net/phpMyAdmin/${phpmyadminVersion}/${archiveName}.zip"
echo "Checking checksum of: ${archiveName}.zip"
echo "${phpmyadminChecksum}  ${downloadPath}/${archiveName}.zip" | sha256sum -c -
unzip -q "${downloadPath}/${archiveName}.zip" -d "${downloadPath}"

if [[ -e "${installPath}" ]]; then
  echo "Removing previous installation at: ${installPath}"
  rm -rf "${installPath}"
fi
echo "Installing phpMyAdmin ${phpmyadminVersion} to: ${installPath}"
mkdir -p "$(dirname "${installPath}")"
mv "${downloadPath}/${archiveName}" "${installPath}"
rm -rf "${downloadPath}"
mkdir -p "${installPath}/tmp"
chown -hR www-data: "${installPath}"

if [[ "${controlUserCount}" -gt 0 ]]; then
  echo "Control user: ${controlUser} already exists"
else
  if [[ -z "${controlPassword}" ]]; then
    controlPassword=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
    echo "Using generated password of control user: ${controlPassword}"
  fi
  cosyses \
    --applicationName "${databaseType}" \
    --applicationVersion "${databaseVersion}" \
    --applicationScript "create-user.sh" \
    --databaseHost "${databaseHost}" \
    --databasePort "${databasePort}" \
    --databaseRootUser "${databaseRootUser}" \
    --databaseRootPassword "${databaseRootPassword}" \
    --databaseUser "${controlUser}" \
    --databasePassword "${controlPassword}"
fi

echo "Creating tables of the configuration storage in database: ${controlDatabase}"
export MYSQL_PWD="${databaseRootPassword}"
sed "s/\`phpmyadmin\`/\`${controlDatabase}\`/g" "${installPath}/sql/create_tables.sql" | \
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}"
unset MYSQL_PWD

cosyses \
  --applicationName "${databaseType}" \
  --applicationVersion "${databaseVersion}" \
  --applicationScript "grant-user.sh" \
  --databaseHost "${databaseHost}" \
  --databasePort "${databasePort}" \
  --databaseRootUser "${databaseRootUser}" \
  --databaseRootPassword "${databaseRootPassword}" \
  --databaseUser "${controlUser}" \
  --databaseName "${controlDatabase}"

# phpMyAdmin 5.2 needs a secret of exactly 32 bytes
blowfishSecret=$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')

echo "Writing configuration to: ${installPath}/config.inc.php"
cat <<EOF > "${installPath}/config.inc.php"
<?php
\$cfg['blowfish_secret'] = sodium_hex2bin('${blowfishSecret}');
\$cfg['TempDir'] = '${installPath}/tmp';
\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = '${databaseHost}';
\$cfg['Servers'][\$i]['port'] = '${databasePort}';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
\$cfg['Servers'][\$i]['controlhost'] = '${databaseHost}';
\$cfg['Servers'][\$i]['controlport'] = '${databasePort}';
\$cfg['Servers'][\$i]['controluser'] = '${controlUser}';
\$cfg['Servers'][\$i]['controlpass'] = '${controlPassword}';
\$cfg['Servers'][\$i]['pmadb'] = '${controlDatabase}';
\$cfg['Servers'][\$i]['bookmarktable'] = 'pma__bookmark';
\$cfg['Servers'][\$i]['relation'] = 'pma__relation';
\$cfg['Servers'][\$i]['table_info'] = 'pma__table_info';
\$cfg['Servers'][\$i]['table_coords'] = 'pma__table_coords';
\$cfg['Servers'][\$i]['pdf_pages'] = 'pma__pdf_pages';
\$cfg['Servers'][\$i]['column_info'] = 'pma__column_info';
\$cfg['Servers'][\$i]['history'] = 'pma__history';
\$cfg['Servers'][\$i]['table_uiprefs'] = 'pma__table_uiprefs';
\$cfg['Servers'][\$i]['tracking'] = 'pma__tracking';
\$cfg['Servers'][\$i]['userconfig'] = 'pma__userconfig';
\$cfg['Servers'][\$i]['recent'] = 'pma__recent';
\$cfg['Servers'][\$i]['favorite'] = 'pma__favorite';
\$cfg['Servers'][\$i]['users'] = 'pma__users';
\$cfg['Servers'][\$i]['usergroups'] = 'pma__usergroups';
\$cfg['Servers'][\$i]['navigationhiding'] = 'pma__navigationhiding';
\$cfg['Servers'][\$i]['savedsearches'] = 'pma__savedsearches';
\$cfg['Servers'][\$i]['central_columns'] = 'pma__central_columns';
\$cfg['Servers'][\$i]['designer_settings'] = 'pma__designer_settings';
\$cfg['Servers'][\$i]['export_templates'] = 'pma__export_templates';
EOF
chown root:www-data "${installPath}/config.inc.php"
chmod 0640 "${installPath}/config.inc.php"

if [[ -n "${serverName}" ]]; then
  vhostParameters=( --webPath "${installPath}" --serverName "${serverName}" )
  if [[ -n "${httpPort}" ]]; then
    vhostParameters+=( --httpPort "${httpPort}" )
  fi
  if [[ -n "${sslPort}" ]]; then
    vhostParameters+=( --sslPort "${sslPort}" )
  fi
  if [[ -n "${sslTerminated}" ]]; then
    vhostParameters+=( --sslTerminated "${sslTerminated}" )
  fi
  if [[ -n "${forceSsl}" ]]; then
    vhostParameters+=( --forceSsl "${forceSsl}" )
  fi
  if [[ -n "${fpmHostName}" ]]; then
    vhostParameters+=( --fpmHostName "${fpmHostName}" )
  fi
  if [[ -n "${fpmHostPort}" ]]; then
    vhostParameters+=( --fpmHostPort "${fpmHostPort}" )
  fi
  if [[ -n "${basicAuthUserName}" ]]; then
    vhostParameters+=( --basicAuthUserName "${basicAuthUserName}" --basicAuthPassword "${basicAuthPassword}" )
  fi
  if [[ -n "${overwrite}" ]]; then
    vhostParameters+=( --overwrite "${overwrite}" )
  fi
  if [[ "${webServer}" == "Apache" ]]; then
    # the virtual hosts without FPM use index.html as directory index and allow overrides
    echo "Writing directory index to: ${installPath}/.htaccess"
    echo "DirectoryIndex index.php" > "${installPath}/.htaccess"
    chown www-data: "${installPath}/.htaccess"
  fi
  cosyses \
    --applicationName "${webServer}" \
    --applicationVersion "${webServerVersion}" \
    --applicationScript "vhost.sh" \
    "${vhostParameters[@]}"
fi
