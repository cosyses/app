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
  --bindAddress  Bind address, default: 127.0.0.1
  --port         Port, default: 9200
  --userName     Name of user to create, default: opensearch
  --userId       Id of user to create, default: 10001
  --groupName    Name of group to create, default: opensearch

Example: ${scriptFileName} --bindAddress 0.0.0.0
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

bindAddress=
port=
userName=
userId=
groupName=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${bindAddress}" ]]; then
  bindAddress="127.0.0.1"
fi

if [[ -z "${port}" ]]; then
  port="9200"
fi

if [[ -z "${userName}" ]]; then
  userName="opensearch"
fi

if [[ -z "${userId}" ]]; then
  userId="10001"
fi

if [[ -z "${groupName}" ]]; then
  groupName="opensearch"
fi

adduser --system --shell /bin/bash -U "${userId}" --no-create-home "${userName}"
groupadd "${groupName}"
usermod -aG "${groupName}" "${userName}"
mkdir -p "/home/${userName}"
chown -R "${userName}" "/home/${userName}"

wget -nv https://artifacts.opensearch.org/releases/bundle/opensearch/2.9.0/opensearch-2.9.0-linux-x64.tar.gz
tar xf opensearch-2.9.0-linux-x64.tar.gz
mv opensearch-2.9.0 /opt/opensearch
chown -R opensearch /opt/opensearch

echo "Setting bind address to: ${bindAddress}"
replace-file-content /opt/opensearch/config/opensearch.yml "network.host: ${bindAddress}" "#network.host: 192.168.0.1" 0

echo "Setting port to: ${port}"
replace-file-content /opt/opensearch/config/opensearch.yml "http.port: ${port}" "#http.port: 9200" 0

echo "Setting discovery seed hosts to: single-node"
replace-file-content /opt/opensearch/config/opensearch.yml "discovery.type: single-node" "#discovery.seed_hosts: [\"host1\", \"host2\"]" 0

echo "plugins.security.disabled: true" >> /opt/opensearch/config/opensearch.yml

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/opensearch.sh"
  cat <<EOF > /usr/local/bin/opensearch.sh
#!/bin/bash -e
ulimit -n 65535
sysctl -w vm.max_map_count=262144
sudo -H -u ${userName} bash -c "/opt/opensearch/opensearch-tar-install.sh"
EOF
  chmod +x /usr/local/bin/opensearch.sh
fi
