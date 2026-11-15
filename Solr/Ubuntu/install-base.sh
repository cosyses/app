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
  --bindAddress  Bind address, default: 127.0.0.1 or 0.0.0.0 if docker environment
  --port         Port, default: 8983
  --serviceName  Name of the service, also used for the installation (/opt/<name>) and data path (/var/<name>), default: solr
  --userName     Name of the user running Solr, default: solr
  --heapSize     Heap size of the JVM, e.g. 2g, default: 512m (Solr default)

Example: ${scriptFileName} --port 8984 --serviceName solr2 --heapSize 1g
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

bindAddress=
port=
serviceName=
userName=
heapSize=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${bindAddress}" ]]; then
  if [[ -f /.dockerenv ]]; then
    bindAddress="0.0.0.0"
  else
    bindAddress="127.0.0.1"
  fi
fi

if [[ -z "${port}" ]]; then
  port="8983"
fi

if [[ -z "${serviceName}" ]]; then
  serviceName="solr"
fi

if [[ -z "${userName}" ]]; then
  userName="solr"
fi

# Set by the version specific install.sh which sources this script
if [[ -z "${solrVersion}" ]]; then
  >&2 echo "No Solr version specified!"
  echo ""
  exit 1
fi

if [[ -z "${solrJavaPackage}" ]]; then
  >&2 echo "No Java package for Solr specified!"
  echo ""
  exit 1
fi

solrMajorVersion="${solrVersion%%.*}"
if [[ "${solrMajorVersion}" -lt 9 ]]; then
  solrDownloadUrl="https://archive.apache.org/dist/lucene/solr/${solrVersion}"
  solrKeysUrl="https://archive.apache.org/dist/lucene/KEYS"
else
  solrDownloadUrl="https://archive.apache.org/dist/solr/solr/${solrVersion}"
  solrKeysUrl="https://archive.apache.org/dist/solr/KEYS"
fi

install-package "${solrJavaPackage}"
install-package lsof
install-package procps
install-package gnupg

if [[ ! -e "/opt/${serviceName}" ]]; then
  downloadPath=$(mktemp -d)
  cd "${downloadPath}"

  echo "Downloading Solr ${solrVersion}"
  wget -nv "${solrDownloadUrl}/solr-${solrVersion}.tgz"
  wget -nv "${solrDownloadUrl}/solr-${solrVersion}.tgz.sha512"
  wget -nv "${solrDownloadUrl}/solr-${solrVersion}.tgz.asc"
  wget -nv -O KEYS "${solrKeysUrl}"

  echo "Checking checksum"
  sha512sum -c "solr-${solrVersion}.tgz.sha512"

  echo "Checking signature"
  mkdir -m 700 gnupg
  gpg --batch --quiet --homedir gnupg --import KEYS 2>/dev/null || true
  gpg --batch --homedir gnupg --verify "solr-${solrVersion}.tgz.asc" "solr-${solrVersion}.tgz"

  echo "Unpacking Solr"
  tar xzf "solr-${solrVersion}.tgz" "solr-${solrVersion}/bin/install_solr_service.sh"

  serviceOptions=( -p "${port}" -s "${serviceName}" -u "${userName}" )
  if [[ -f /.dockerenv ]]; then
    # The service is not used in containers, a start script is created below instead
    serviceOptions+=( -n )
  fi

  echo "Creating Solr service with name \"${serviceName}\" on port ${port}"
  "solr-${solrVersion}/bin/install_solr_service.sh" "solr-${solrVersion}.tgz" "${serviceOptions[@]}"

  cd /
  rm -rf "${downloadPath}"

  echo "Setting bind address to: ${bindAddress}"
  if [[ "${solrMajorVersion}" -lt 9 ]]; then
    echo "SOLR_OPTS=\"\$SOLR_OPTS -Djetty.host=${bindAddress}\"" >> "/etc/default/${serviceName}.in.sh"
  else
    echo "SOLR_JETTY_HOST=\"${bindAddress}\"" >> "/etc/default/${serviceName}.in.sh"
  fi

  if [[ -n "${heapSize}" ]]; then
    echo "Setting heap size to: ${heapSize}"
    echo "SOLR_HEAP=\"${heapSize}\"" >> "/etc/default/${serviceName}.in.sh"
  fi

  if [[ ! -f /.dockerenv ]]; then
    echo "Restarting Solr service with name \"${serviceName}\""
    service "${serviceName}" restart
  fi
else
  echo "Solr is already installed at: /opt/${serviceName}"
fi

if [[ -f /.dockerenv ]]; then
  startCommand="ulimit -n 65535 2>/dev/null || true
su -s /bin/bash -c \"SOLR_INCLUDE=/etc/default/${serviceName}.in.sh /opt/${serviceName}/bin/solr start\" ${userName}"
  stopCommand="su -s /bin/bash -c \"SOLR_INCLUDE=/etc/default/${serviceName}.in.sh /opt/${serviceName}/bin/solr stop -p ${port}\" ${userName}"

  echo "Creating start script at: /usr/local/bin/${serviceName}.sh"
  cat <<EOF > "/usr/local/bin/${serviceName}.sh"
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Solr"
  ${stopCommand}
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Solr"
${startCommand}
tail -f /dev/null & wait \$!
EOF
  chmod +x "/usr/local/bin/${serviceName}.sh"

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-${serviceName}.sh"
    cat <<EOF > "/usr/local/lib/start/10-${serviceName}.sh"
#!/usr/bin/env bash
echo "Starting Solr"
${startCommand}
EOF
    chmod +x "/usr/local/lib/start/10-${serviceName}.sh"
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-${serviceName}.sh"
    cat <<EOF > "/usr/local/lib/stop/10-${serviceName}.sh"
#!/usr/bin/env bash
echo "Stopping Solr"
${stopCommand}
EOF
    chmod +x "/usr/local/lib/stop/10-${serviceName}.sh"
  fi
fi
