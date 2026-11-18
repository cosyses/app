#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Installs Playwright (browser automation for Node.js) with the npm package playwright below
/usr/local/lib/npm-tools/playwright (the command playwright in /usr/local/bin) and the browsers it drives, with the
system packages they need (for example libasound2), into a directory shared by all users. Node.js has to be installed
(cosyses Node.js <version>).

Scripts find the browsers with the environment variable PLAYWRIGHT_BROWSERS_PATH, set for login shells in
/etc/profile.d/playwright.sh (pass it yourself elsewhere, for example to docker exec). A script imports the package by
its path, for example:
  import { chromium } from '/usr/local/lib/npm-tools/playwright/node_modules/playwright/index.mjs';

usage: ${scriptFileName} options

OPTIONS:
  --help          Show this message
  --browsers      Comma separated browsers to install, default: chromium-headless-shell
                  (chromium, chromium-headless-shell, firefox, webkit)
  --browsersPath  Directory of the browsers, default: /usr/local/lib/ms-playwright

Example: ${scriptFileName} --browsers chromium-headless-shell,firefox
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

browsers=
browsersPath=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${browsers}" ]]; then
  browsers="chromium-headless-shell"
fi

if [[ -z "${browsersPath}" ]]; then
  browsersPath="/usr/local/lib/ms-playwright"
fi

cosyses --applicationName Node.js --applicationScript tool.sh --packageName playwright --packageVersion "~1.65.0"

echo "Installing the browsers ${browsers} with their system packages into: ${browsersPath}"
mkdir -p "${browsersPath}"
update-packages
IFS=',' read -r -a browserList <<< "${browsers}"
DEBIAN_FRONTEND=noninteractive PLAYWRIGHT_BROWSERS_PATH="${browsersPath}" playwright install --with-deps "${browserList[@]}"
chmod -R a+rX "${browsersPath}"

echo "Setting PLAYWRIGHT_BROWSERS_PATH in: /etc/profile.d/playwright.sh"
echo "export PLAYWRIGHT_BROWSERS_PATH=\"${browsersPath}\"" > /etc/profile.d/playwright.sh
