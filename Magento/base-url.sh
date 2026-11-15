#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Changes the base URL of an installed Magento 2 shop, e.g. after importing the database of another system. Base URLs
of websites and store views which equal the old default ones are removed first, so that they use the new default.
The database is accessed with the connection in app/etc/env.php.

usage: ${scriptFileName} options

OPTIONS:
  --help           Show this message
  --appPath        Path of the Magento installation, default: /var/www/magento/htdocs
  --user           System user who owns the installation and runs bin/magento, default: www-data
  --baseUrl        New base URL, for example: https://shop.local/
  --secureBaseUrl  New secure base URL, default: the base URL

Example: ${scriptFileName} --appPath /var/www/magento/htdocs --baseUrl https://shop.local/
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

appPath=
user=
baseUrl=
secureBaseUrl=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  appPath="/var/www/magento/htdocs"
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ -z "${baseUrl}" ]]; then
  >&2 echo "No base URL specified!"
  usage
  exit 1
fi

if [[ "${baseUrl}" != */ ]]; then
  baseUrl="${baseUrl}/"
fi

if [[ -z "${secureBaseUrl}" ]]; then
  secureBaseUrl="${baseUrl}"
fi

if [[ "${secureBaseUrl}" != */ ]]; then
  secureBaseUrl="${secureBaseUrl}/"
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

echo "Removing base URLs of websites and store views which equal the default ones"
runQuery "DELETE FROM {prefix}core_config_data WHERE path LIKE 'web/%/base_url' AND scope_id <> 0 AND value IN (SELECT value FROM (SELECT DISTINCT value FROM {prefix}core_config_data WHERE path LIKE 'web/%/base_url' AND scope_id = 0) AS default_base_urls)"

echo "Setting base URL: ${baseUrl} and secure base URL: ${secureBaseUrl}"
runMagento setup:store-config:set \
  --no-interaction \
  "--base-url=${baseUrl}" \
  "--base-url-secure=${secureBaseUrl}"

runMagento cache:clean
