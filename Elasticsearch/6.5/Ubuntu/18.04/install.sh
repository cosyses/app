#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  --help                Show this message
  --applicationName     Name of application
  --applicationVersion  Version of application (optional)
  --applicationScript   Name of script, default: install.sh
  --bindAddress         Bind address, default: 127.0.0.1
  --port                Port, default: 9200

Example: ${scriptName} --applicationName Elasticsearch --applicationVersion 6.5 --bindAddress 0.0.0.0 --port 9200
EOF
}

helpRequested=
bindAddress=
port=
source "${currentPath}/../../../../prepare-parameters.sh"

if [[ "${helpRequested}" == 1 ]]; then
  usage
  exit 0
fi

if [[ -z "${bindAddress}" ]]; then
  bindAddress="127.0.0.1"
fi

if [[ -z "${port}" ]] || [[ "${port}" == "-" ]]; then
  port="9200"
fi

echo "Installing Java 8"
install-package python3-software-properties
install-package debconf-utils
install-package openjdk-8-jre

add-repository "elastic-6.x.list" "https://artifacts.elastic.co/packages/6.x/apt" "stable" "main" "https://artifacts.elastic.co/GPG-KEY-elasticsearch" "n"

echo "Installing Elasticsearch 6.5.4"
install-package elasticsearch 6.5.4

echo "Setting bind address to: ${bindAddress}"
replace-file-content /etc/elasticsearch/elasticsearch.yml "network.host: ${bindAddress}" "#network.host: 192.168.0.1" 0

echo "Setting port to: ${port}"
replace-file-content /etc/elasticsearch/elasticsearch.yml "http.port: ${port}" "#http.port: 9200" 0

echo "Restarting Elasticsearch"
service elasticsearch restart

echo "Adding autostart"
systemctl enable elasticsearch.service

mkdir -p /opt/install/
crudini --set /opt/install/env.properties elasticsearch version "6.8"
crudini --set /opt/install/env.properties elasticsearch port "${port}"
