#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Prepares an installed Magento 2 shop for development: sets the deploy mode, disables the two factor authentication of
the admin area (including Magento_AdminAdobeImsTwoFactorAuth from 2.4.6) and the admin usage tracking and its popup.
The database is accessed with the connection in app/etc/env.php.

usage: ${scriptFileName} options

OPTIONS:
  --help                   Show this message
  --appPath                Path of the Magento installation, default: /var/www/magento/htdocs
  --user                   System user who owns the installation and runs bin/magento, default: www-data
  --deployMode             Deploy mode (developer, default or production, "-" to keep it), default: developer
  --disableTwoFactorAuth   Disable the two factor authentication modules (yes/no), default: yes
  --disableAdminUsage      Disable the admin usage tracking (yes/no), default: yes

Example: ${scriptFileName} --appPath /var/www/magento/htdocs --deployMode developer
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

appPath=
user=
deployMode=
disableTwoFactorAuth=
disableAdminUsage=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  appPath="/var/www/magento/htdocs"
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ -z "${deployMode}" ]]; then
  deployMode="developer"
fi

if [[ -z "${disableTwoFactorAuth}" ]]; then
  disableTwoFactorAuth="yes"
fi

if [[ -z "${disableAdminUsage}" ]]; then
  disableAdminUsage="yes"
fi

if [[ ! -f "${appPath}/app/etc/env.php" ]]; then
  >&2 echo "No Magento installation found in: ${appPath}"
  exit 1
fi

runAsUser()
{
  if [[ "${user}" != "$(whoami)" ]]; then
    sudo -H -u "${user}" "$@"
  else
    "$@"
  fi
}

runMagento()
{
  runAsUser php "${appPath}/bin/magento" "$@" 2>&1
}

# Runs a query with the database connection of app/etc/env.php and prints the rows tab separated
runQuery()
{
  # shellcheck disable=SC2016
  runAsUser php -r '
$env = include $argv[1] . "/app/etc/env.php";
$connection = $env["db"]["connection"]["default"];
$host = $connection["host"];
if (strpos($host, "/") === 0) {
    $dsn = "mysql:unix_socket=" . $host;
} else {
    $hostParts = explode(":", $host, 2);
    $dsn = "mysql:host=" . $hostParts[0] . (isset($hostParts[1]) ? ";port=" . $hostParts[1] : "");
}
$pdo = new PDO($dsn . ";dbname=" . $connection["dbname"], $connection["username"], $connection["password"] ?? "", [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
$statement = $pdo->query(str_replace("{prefix}", $env["db"]["table_prefix"] ?? "", $argv[2]));
if ($statement->columnCount() > 0) {
    foreach ($statement->fetchAll(PDO::FETCH_NUM) as $row) {
        echo implode("\t", $row) . PHP_EOL;
    }
}
' -- "${appPath}" "$1"
}

cd "${appPath}"

magentoVersion=$(runMagento --version | awk '{print $NF}')
echo "Magento version: ${magentoVersion}"

if [[ "${deployMode}" != "-" ]]; then
  echo "Setting deploy mode: ${deployMode}"
  runMagento deploy:mode:set "${deployMode}"
  runMagento cache:clean
fi

if [[ "${disableTwoFactorAuth}" == "yes" ]]; then
  twoFactorAuthModules=( Magento_TwoFactorAuth )
  if version-compare "${magentoVersion}" -ge 2.4.6; then
    twoFactorAuthModules=( Magento_AdminAdobeImsTwoFactorAuth Magento_TwoFactorAuth )
  fi
  echo "Disabling modules: ${twoFactorAuthModules[*]}"
  runMagento module:disable "${twoFactorAuthModules[@]}"
  runMagento cache:clean
fi

if [[ "${disableAdminUsage}" == "yes" ]]; then
  echo "Disabling admin usage tracking"
  runMagento config:set admin/usage/enabled 0
  tableName=$(runQuery "SHOW TABLES LIKE '{prefix}admin_analytics_usage_version_log'")
  if [[ -n "${tableName}" ]]; then
    echo "Hiding admin usage popup for version: ${magentoVersion}"
    runQuery "REPLACE INTO ${tableName} (last_viewed_in_version) VALUES ('${magentoVersion}')"
  fi
  runMagento cache:clean
fi
