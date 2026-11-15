#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Downloads the latest WordPress 7.1 release with WP-CLI into a directory, creates wp-config.php and installs the site
with an admin user. Steps already done (files downloaded, wp-config.php exists, site installed) are skipped. The
database server has to be running and the database and its user have to exist (cosyses MariaDB <version>
create-user.sh). PHP has to be installed (cosyses PHP 8.4 wordpress.sh), WP-CLI is installed if missing.

usage: ${scriptFileName} options

OPTIONS:
  --help              Show this message
  --appPath           Directory of the site
  --user              System user who owns the site and runs WP-CLI, default: www-data
  --wordpressVersion  Exact version to download, e.g. 7.1.1, default: the latest 7.1 release
                      Tested: 7.1 releases and 7.0 (PHP 8.4, MariaDB 11.4), older versions are untested
  --appUrl           URL of the site, default: http://localhost
  --title             Title of the site, default: WordPress
  --locale            Language of the site, default: en_US
  --databaseHost      Database host, default: localhost
  --databasePort      Database port, default: 3306
  --databaseName      Database name, default: wordpress
  --databaseUser      Database user
  --databasePassword  Database password
  --tablePrefix       Prefix of the database tables, default: wp_
  --adminUser         Name of the admin user, default: admin
  --adminPassword     Password of the admin user, default: <generated and printed>
  --adminEmail        Email address of the admin user, default: admin@example.com

Example: ${scriptFileName} --appPath /var/www/wordpress --appUrl https://www.example.com --databaseUser wordpress --databasePassword secret
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

appPath=
user=
wordpressVersion=
appUrl=
title=
locale=
databaseHost=
databasePort=
databaseName=
databaseUser=
databasePassword=
tablePrefix=
adminUser=
adminPassword=
adminEmail=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  >&2 echo "No app path specified!"
  usage
  exit 1
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ -z "${appUrl}" ]]; then
  appUrl="http://localhost"
fi

if [[ -z "${title}" ]]; then
  title="WordPress"
fi

if [[ -z "${locale}" ]]; then
  locale="en_US"
fi

if [[ -z "${databaseHost}" ]]; then
  databaseHost="localhost"
fi

if [[ -z "${databasePort}" ]]; then
  databasePort="3306"
fi

if [[ -z "${databaseName}" ]]; then
  databaseName="wordpress"
fi

if [[ -z "${databaseUser}" ]]; then
  >&2 echo "No database user specified!"
  usage
  exit 1
fi

if [[ -z "${databasePassword}" ]]; then
  >&2 echo "No database password specified!"
  usage
  exit 1
fi

if [[ -z "${tablePrefix}" ]]; then
  tablePrefix="wp_"
fi

if [[ -z "${adminUser}" ]]; then
  adminUser="admin"
fi

if [[ -z "${adminEmail}" ]]; then
  adminEmail="admin@example.com"
fi

if ! id "${user}" > /dev/null 2>&1; then
  >&2 echo "User: ${user} does not exist!"
  exit 1
fi

if [[ ! -x "$(command -v php)" ]]; then
  >&2 echo "PHP not found, install it first (cosyses PHP 8.4 and cosyses PHP 8.4 wordpress.sh)"
  exit 1
fi

if [[ ! -x "$(command -v wp)" ]]; then
  cosyses \
    --applicationName WP-CLI \
    --applicationVersion 2.12
fi

# Runs WP-CLI as the site user in the site directory
runWp()
{
  if [[ "${user}" != "$(whoami)" ]]; then
    sudo -H -u "${user}" wp --path="${appPath}" "$@"
  elif [[ "${user}" == "root" ]]; then
    wp --path="${appPath}" --allow-root "$@"
  else
    wp --path="${appPath}" "$@"
  fi
}

if [[ ! -d "${appPath}" ]]; then
  echo "Creating app path: ${appPath}"
  mkdir -p "${appPath}"
  chown "${user}": "${appPath}"
fi

if [[ -f "${appPath}/wp-includes/version.php" ]]; then
  echo "WordPress is already downloaded to: ${appPath}"
else
  if [[ -z "${wordpressVersion}" ]]; then
    # The latest patch release of this version
    wordpressVersion=$(curl -fsS https://api.wordpress.org/core/version-check/1.7/ | grep -oE '"version":"7\.1(\.[0-9]+)?"' | cut -d'"' -f4 | sort -V | tail -n 1)
    if [[ -z "${wordpressVersion}" ]]; then
      >&2 echo "Could not determine the latest release of WordPress 7.1"
      exit 1
    fi
  fi

  echo "Downloading WordPress ${wordpressVersion} with locale: ${locale} to: ${appPath}"
  runWp core download --locale="${locale}" --version="${wordpressVersion}"
fi

if [[ -f "${appPath}/wp-config.php" ]]; then
  echo "WordPress is already configured (wp-config.php exists)"
else
  echo "Creating configuration: ${appPath}/wp-config.php"
  runWp config create \
    --dbname="${databaseName}" \
    --dbuser="${databaseUser}" \
    --dbpass="${databasePassword}" \
    --dbhost="${databaseHost}:${databasePort}" \
    --dbprefix="${tablePrefix}" \
    --locale="${locale}"
  chmod 0640 "${appPath}/wp-config.php"
fi

if runWp core is-installed > /dev/null 2>&1; then
  echo "WordPress is already installed"
else
  if [[ -z "${adminPassword}" ]]; then
    adminPassword=$(php -r 'echo bin2hex(random_bytes(8));')
    echo "Using generated admin password: ${adminPassword}"
  fi

  echo "Installing WordPress at URL: ${appUrl}"
  runWp core install \
    --url="${appUrl}" \
    --title="${title}" \
    --admin_user="${adminUser}" \
    --admin_password="${adminPassword}" \
    --admin_email="${adminEmail}" \
    --skip-email
fi
