#!/bin/bash -e

# Installs the statically linked release binary of ShellCheck, the same version on every distribution (the packages of
# the distributions are older, for example 0.8 in Ubuntu 22.04 and 0.9 in Ubuntu 24.04)
echo "Installing ShellCheck"
case "$(uname -m)" in
  x86_64) architecture="x86_64"; shellcheckChecksum="b7af85e41cc99489dcc21d66c6d5f3685138f06d34651e6d34b42ec6d54fe6f6" ;;
  aarch64) architecture="aarch64"; shellcheckChecksum="68a8133197a50beb8803f8d42f9908d1af1c5540d4bb05fdfca8c1fa47decefc" ;;
  *)
    >&2 echo "Unsupported architecture: $(uname -m)"
    exit 1
    ;;
esac

shellcheckArchive="shellcheck-v0.11.0.linux.${architecture}.tar.gz"
shellcheckPath=$(mktemp -d)
wget -nv "https://github.com/koalaman/shellcheck/releases/download/v0.11.0/${shellcheckArchive}" \
  -O "${shellcheckPath}/${shellcheckArchive}" 2>&1
echo "Verifying checksum of: ${shellcheckArchive}"
echo "${shellcheckChecksum}  ${shellcheckPath}/${shellcheckArchive}" | sha256sum --check --strict
tar -xzf "${shellcheckPath}/${shellcheckArchive}" -C "${shellcheckPath}"
install -m 0755 "${shellcheckPath}/shellcheck-v0.11.0/shellcheck" /usr/local/bin/shellcheck
rm -rf "${shellcheckPath}"

shellcheck --version
