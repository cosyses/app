#!/bin/bash -e

# Uses the package of the distribution where it has version 0.19 (Ubuntu 22.04 and later, Debian, Fedora), the release
# binary of Tini otherwise
echo "Installing Tini"
if [[ -n "$(get-available-package-versions tini 0.19)" ]]; then
  install-package tini 0.19
else
  case "$(uname -m)" in
    x86_64) architecture="amd64"; tiniChecksum="93dcc18adc78c65a028a84799ecf8ad40c936fdfc5f2a57b1acda5a8117fa82c" ;;
    aarch64) architecture="arm64"; tiniChecksum="07952557df20bfd2a95f9bef198b445e006171969499a1d361bd9e6f8e5e0e81" ;;
    *)
      >&2 echo "Unsupported architecture: $(uname -m)"
      exit 1
      ;;
  esac

  tiniFile=$(mktemp)
  wget -nv "https://github.com/krallin/tini/releases/download/v0.19.0/tini-${architecture}" -O "${tiniFile}" 2>&1
  echo "Verifying checksum of: tini-${architecture}"
  echo "${tiniChecksum}  ${tiniFile}" | sha256sum --check --strict
  install -m 0755 "${tiniFile}" /usr/local/bin/tini
  rm -f "${tiniFile}"
fi
