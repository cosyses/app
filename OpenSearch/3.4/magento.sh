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
  --help  Show this message
  --port  Port, default: 9200

Example: ${scriptFileName} --port 9200
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

port=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${port}" ]]; then
  port="9200"
fi

cd /opt/opensearch || exit 1

if [[ $(bin/opensearch-plugin list | grep "analysis-phonetic" | wc -l) -eq 0 ]]; then
  echo "Installing OpenSearch plugin: analysis-phonetic"
  bin/opensearch-plugin install analysis-phonetic
else
  echo "OpenSearch plugin: analysis-phonetic already installed"
fi

if [[ $(bin/opensearch-plugin list | grep "analysis-icu" | wc -l) -eq 0 ]]; then
  echo "Installing OpenSearch plugin: analysis-icu"
  bin/opensearch-plugin install analysis-icu
else
  echo "OpenSearch plugin: analysis-icu already installed"
fi

if [[ -f /.dockerenv ]]; then
  echo "Updating OpenSearch settings for indexing"
  curl -XPUT -H "Content-Type: application/json" "http://localhost:${port}/_cluster/settings" -d '{"persistent": {"cluster.blocks.create_index": false}}'
fi
