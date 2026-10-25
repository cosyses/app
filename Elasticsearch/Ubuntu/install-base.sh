#!/bin/bash -e

# Set by the version specific install.sh which sources this script
if [[ -z "${elasticsearchVersion}" ]]; then
  >&2 echo "No Elasticsearch version set!"
  echo ""
  exit 1
fi

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

Example: ${scriptName} --applicationName Elasticsearch --applicationVersion ${applicationVersion} --bindAddress 0.0.0.0 --port 9200
EOF
}

helpRequested=
bindAddress=
port=
source "${cosysesPath}/prepare-parameters.sh"

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

elasticsearchMajorVersion="${elasticsearchVersion%%.*}"

add-repository "elastic-${elasticsearchMajorVersion}.x.list" "https://artifacts.elastic.co/packages/${elasticsearchMajorVersion}.x/apt" "stable" "main" "https://artifacts.elastic.co/GPG-KEY-elasticsearch" "n"

echo "Installing Elasticsearch ${elasticsearchVersion}"
install-package elasticsearch "${elasticsearchVersion}"

if [[ "${elasticsearchContainerSupport}" == 1 ]]; then
  sysctl -w vm.max_map_count=262144
fi

echo "Setting bind address to: ${bindAddress}"
replace-file-content /etc/elasticsearch/elasticsearch.yml "network.host: ${bindAddress}" "#network.host: 192.168.0.1" 0

echo "Setting port to: ${port}"
replace-file-content /etc/elasticsearch/elasticsearch.yml "http.port: ${port}" "#http.port: 9200" 0

if [[ "${elasticsearchContainerSupport}" == 1 ]] && [[ -f /.dockerenv ]]; then
  echo "Stopping Elasticsearch"
  /etc/init.d/elasticsearch stop

  echo "Removing service"
  systemctl disable elasticsearch.service

  echo "Creating start script at: /usr/local/bin/elasticsearch.sh"
  cat <<EOF > /usr/local/bin/elasticsearch.sh
#!/bin/bash -e
mkdir -p /var/run/elasticsearch && chown elasticsearch:elasticsearch /var/run/elasticsearch
ulimit -n 65535
sysctl -w vm.max_map_count=262144
sudo -H -u elasticsearch bash -c "/usr/share/elasticsearch/bin/elasticsearch --pidfile /var/run/elasticsearch/elasticsearch.pid"
EOF
  chmod +x /usr/local/bin/elasticsearch.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-elasticsearch.sh"
    cat <<EOF > /usr/local/lib/start/10-elasticsearch.sh
#!/usr/bin/env bash
echo "Starting Elasticsearch"
ulimit -n 65535
sysctl -w vm.max_map_count=262144
mkdir -p /var/run/elasticsearch/
chown elasticsearch: /var/run/elasticsearch/
sudo -H -u elasticsearch bash -c "/usr/share/elasticsearch/bin/elasticsearch --pidfile /var/run/elasticsearch/elasticsearch.pid --daemonize"
EOF
    chmod +x /usr/local/lib/start/10-elasticsearch.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-elasticsearch.sh"
    cat <<EOF > /usr/local/lib/stop/10-elasticsearch.sh
#!/usr/bin/env bash
echo "Stopping Elasticsearch"
cat /var/run/elasticsearch/elasticsearch.pid | xargs kill -15 && until test ! -f /var/run/elasticsearch/elasticsearch.pid; do sleep 1; done
EOF
    chmod +x /usr/local/lib/stop/10-elasticsearch.sh
  fi
else
  echo "Restarting Elasticsearch"
  service elasticsearch restart

  echo "Adding autostart"
  systemctl enable elasticsearch.service
fi
