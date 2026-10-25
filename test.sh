#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi
repositoryPath=$(cd -P "$(dirname "${scriptFileName}")" && pwd)

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} [options] <Name> [<Version> [<Release>]] [-- <script options>]

Runs install scripts of this checkout in fresh cosyses/ubuntu containers.
Without a version, every version of the application is tested.
Without a release, every release with an own directory below <Name>/<Version>/Ubuntu or listed in <Name>/<Version>/Ubuntu/releases is tested.

OPTIONS:
  --help             Show this message
  --script <file>    Script to run, default: install.sh
  --release <list>   Comma separated releases, used if not detected from directories, default: 22.04
  --arm              Use the arm64 images (<release>-arm)
  --image <name>     Image name, default: cosyses/ubuntu
  --logPath <path>   Path of the log files, default: ${TMPDIR:-/tmp}/cosyses-test
  --prepare <cmd>    Install a dependency first, e.g. "PHP 8.4", can be used multiple times
  --shell            Open a shell in the container after the script finished (single run only)

Example: ${scriptFileName} Varnish 7.7 22.04
Example: ${scriptFileName} Tini 0.19
Example: ${scriptFileName} --prepare "PHP 8.4" Composer 2.9 22.04
Example: ${scriptFileName} --script vhost.sh Nginx 1.29 22.04 -- --serverName test.local --webPath /var/www/htdocs
EOF
}

applicationScript="install.sh"
defaultReleases="22.04"
arm=0
image="cosyses/ubuntu"
logPath="${TMPDIR:-/tmp}/cosyses-test"
shell=0
prepareCommands=( )
positionalParameters=( )
scriptParameters=( )

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
    --help|-\?) usage; exit 0 ;;
    --script) applicationScript="${2}"; shift 2 ;;
    --release) defaultReleases="${2}"; shift 2 ;;
    --arm) arm=1; shift ;;
    --image) image="${2}"; shift 2 ;;
    --logPath) logPath="${2}"; shift 2 ;;
    --prepare) prepareCommands+=( "${2}" ); shift 2 ;;
    --shell) shell=1; shift ;;
    --) shift; scriptParameters=( "$@" ); break ;;
    -*) >&2 echo "Unknown option: ${1}"; usage; exit 1 ;;
    *) positionalParameters+=( "${1}" ); shift ;;
  esac
done

applicationName="${positionalParameters[0]}"
applicationVersion="${positionalParameters[1]}"
applicationRelease="${positionalParameters[2]}"

if [[ -z "${applicationName}" ]]; then
  >&2 echo "No application name specified!"
  usage
  exit 1
fi

if [[ ! -d "${repositoryPath}/${applicationName}" ]]; then
  >&2 echo "Unknown application: ${applicationName}"
  exit 1
fi

if ! [[ -x "$(command -v docker)" ]]; then
  >&2 echo "Docker is required"
  exit 1
fi

IFS=',' read -r -a defaultReleaseList <<< "${defaultReleases}"

# Collect all combinations of version and release to test
combinations=( )
if [[ -n "${applicationVersion}" ]]; then
  applicationVersions=( "${applicationVersion}" )
else
  applicationVersions=( $(find "${repositoryPath}/${applicationName}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | grep -E '^[0-9]' | sort -V) )
  if [[ "${#applicationVersions[@]}" -eq 0 ]]; then
    applicationVersions=( "" )
  fi
fi

for version in "${applicationVersions[@]}"; do
  if [[ -n "${applicationRelease}" ]]; then
    releases=( "${applicationRelease}" )
  else
    releases=( )
    if [[ -n "${version}" ]] && [[ -d "${repositoryPath}/${applicationName}/${version}/Ubuntu" ]]; then
      for releasePath in "${repositoryPath}/${applicationName}/${version}/Ubuntu"/*/; do
        if [[ -f "${releasePath}${applicationScript}" ]]; then
          releases+=( "$(basename "${releasePath}")" )
        fi
      done
      # Scripts shared between releases list them in a releases file
      if [[ -f "${repositoryPath}/${applicationName}/${version}/Ubuntu/${applicationScript}" ]] && [[ -f "${repositoryPath}/${applicationName}/${version}/Ubuntu/releases" ]]; then
        while read -r sharedRelease; do
          if [[ -n "${sharedRelease}" ]] && [[ ! " ${releases[*]} " =~ \ ${sharedRelease}\  ]]; then
            releases+=( "${sharedRelease}" )
          fi
        done < "${repositoryPath}/${applicationName}/${version}/Ubuntu/releases"
      fi
    fi
    if [[ "${#releases[@]}" -eq 0 ]]; then
      releases=( "${defaultReleaseList[@]}" )
    fi
  fi
  for release in "${releases[@]}"; do
    combinations+=( "${version}|${release}" )
  done
done

if [[ "${shell}" == 1 ]] && [[ "${#combinations[@]}" -gt 1 ]]; then
  >&2 echo "Option --shell requires a single version and release"
  exit 1
fi

mkdir -p "${logPath}"

if [[ -t 0 ]] && [[ -t 1 ]]; then
  dockerTerminal=( -it )
else
  dockerTerminal=( -i )
fi

# Stop the running container if this script is interrupted, docker run does not do so by itself
containerName=
stopContainer()
{
  if [[ -n "${containerName}" ]]; then
    docker stop -t 2 "${containerName}" > /dev/null 2>&1 || true
  fi
}
trap 'stopContainer; exit 130' INT TERM HUP

results=( )
failed=0
for combination in "${combinations[@]}"; do
  version="${combination%%|*}"
  release="${combination##*|}"

  if [[ "${arm}" == 1 ]]; then
    imageTag="${release}-arm"
    platform="linux/arm64"
  else
    imageTag="${release}"
    platform="linux/amd64"
  fi

  label="${applicationName} ${version:-(latest)} ${applicationScript} on Ubuntu ${imageTag}"
  logFile="${logPath}/${applicationName}-${version:-latest}-${applicationScript//\//_}-${imageTag}.log"

  cosysesCommand=( cosyses --applicationName "${applicationName}" --applicationScript "${applicationScript}" )
  if [[ -n "${version}" ]]; then
    cosysesCommand+=( --applicationVersion "${version}" )
  fi
  cosysesCommand+=( "${scriptParameters[@]}" )

  # Use the mounted checkout instead of the release the image would download on start
  containerScript=$(cat << EOF
set -e
ln -sfn /usr/local/lib/cosyses/local /usr/local/lib/cosyses/current
update-packages
cosyses --applicationName Cosyses --applicationScript functions.sh
$(for prepareCommand in "${prepareCommands[@]}"; do echo "cosyses ${prepareCommand}"; done)
$(printf '%q ' "${cosysesCommand[@]}")
EOF
)
  if [[ "${shell}" == 1 ]]; then
    containerScript+=$'\n'"echo 'Opening shell, exit to remove the container'; exec bash"
  fi

  echo "=== Testing ${label}"
  echo "=== Log file: ${logFile}"
  containerName="cosyses-test-$$-${RANDOM}"
  set +e
  if [[ "${shell}" == 1 ]]; then
    docker run --rm --name "${containerName}" "${dockerTerminal[@]}" \
      --platform "${platform}" \
      -v "${repositoryPath}:/usr/local/lib/cosyses/local:ro" \
      --entrypoint bash \
      "${image}:${imageTag}" -c "${containerScript}"
    result=$?
  else
    # Run in background and wait, so the trap can stop the container when interrupted
    docker run --rm --name "${containerName}" -i \
      --platform "${platform}" \
      -v "${repositoryPath}:/usr/local/lib/cosyses/local:ro" \
      --entrypoint bash \
      "${image}:${imageTag}" -c "${containerScript}" < /dev/null > >(tee "${logFile}") 2>&1 &
    wait $!
    result=$?
  fi
  set -e
  containerName=

  if [[ "${result}" == 0 ]]; then
    results+=( "PASS  ${label}" )
  else
    results+=( "FAIL  ${label} (exit code ${result}, see ${logFile})" )
    failed=1
  fi
done

echo ""
echo "=== Results"
printf '%s\n' "${results[@]}"

exit "${failed}"
