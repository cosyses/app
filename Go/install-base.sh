#!/bin/bash -e

# Installs the official Go release archive for the machine's architecture (amd64, arm64), checked against its SHA-256,
# to /usr/local/go and links go and gofmt to /usr/local/bin. Distribution-independent (needs curl, tar, sha256sum).
# Set by the version's wrapper: goVersion (the full release, e.g. 1.27.4), goChecksumAmd64, goChecksumArm64.

if [[ -z "${goVersion}" ]] || [[ -z "${goChecksumAmd64}" ]] || [[ -z "${goChecksumArm64}" ]]; then
  >&2 echo "No Go version and checksums set!"
  exit 1
fi

if [[ -x /usr/local/go/bin/go ]] && [[ "$(/usr/local/go/bin/go env GOVERSION)" == "go${goVersion}" ]]; then
  echo "Go ${goVersion} already installed"
else
  case "$(uname -m)" in
    x86_64) goArchitecture="amd64"; goChecksum="${goChecksumAmd64}" ;;
    aarch64) goArchitecture="arm64"; goChecksum="${goChecksumArm64}" ;;
    *)
      >&2 echo "Unsupported architecture: $(uname -m)"
      exit 1
      ;;
  esac

  goFile=$(mktemp)
  echo "Downloading Go ${goVersion} for ${goArchitecture}"
  curl -Lsf "https://go.dev/dl/go${goVersion}.linux-${goArchitecture}.tar.gz" -o "${goFile}"
  echo "Verifying checksum of: go${goVersion}.linux-${goArchitecture}.tar.gz"
  echo "${goChecksum}  ${goFile}" | sha256sum --check --strict

  echo "Installing Go ${goVersion}"
  rm -rf /usr/local/go
  tar -C /usr/local -xzf "${goFile}"
  rm -f "${goFile}"
fi

ln -sf /usr/local/go/bin/go /usr/local/bin/go
ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
go version
