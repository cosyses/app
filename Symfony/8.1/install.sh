#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Creates a Symfony 8.1 project (symfony/skeleton) with additional bundles in a directory, or installs its dependencies
if it exists (e.g. created before with cosyses Composer create-project.sh), and writes .env.local with APP_ENV and a
generated APP_SECRET if it is missing (an existing .env.local only gets an APP_SECRET if it has none). PHP (cosyses
PHP 8.4 symfony.sh) and Composer have to be installed.

usage: ${scriptFileName} options

OPTIONS:
  --help            Show this message
  --appPath         Directory of the project
  --user            System user who owns the project and runs Composer, default: www-data
  --symfonyVersion  Version constraint of symfony/skeleton for a new project, default: 8.1.*
                    The Symfony packages follow it (extra.symfony.require of the skeleton).
                    Tested: 8.1.* and 7.4.* (PHP 8.4), other versions are untested
  --bundles         Comma separated packages to add to a new project, with optional constraint, "-" for none,
                    default: symfony/twig-bundle,symfony/webpack-encore-bundle
  --appEnv          Environment written to a new .env.local (prod or dev), default: prod

Example: ${scriptFileName} --appPath /var/www/symfony --bundles symfony/twig-bundle,symfony/orm-pack
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

appPath=
user=
symfonyVersion=
bundles=
appEnv=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  >&2 echo "No app path specified!"
  usage
  exit 1
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ -z "${symfonyVersion}" ]]; then
  symfonyVersion="8.1.*"
fi

if [[ -z "${bundles}" ]]; then
  bundles="symfony/twig-bundle,symfony/webpack-encore-bundle"
elif [[ "${bundles}" == "-" ]]; then
  bundles=
fi

if [[ -z "${appEnv}" ]]; then
  appEnv="prod"
fi

if ! id "${user}" > /dev/null 2>&1; then
  >&2 echo "User: ${user} does not exist!"
  exit 1
fi

if [[ ! -x "$(command -v php)" ]]; then
  >&2 echo "PHP not found, install it first (cosyses PHP 8.4 and cosyses PHP 8.4 symfony.sh)"
  exit 1
fi

createArguments=( --packageName symfony/skeleton --packageVersion "${symfonyVersion}" --appPath "${appPath}" --binaries bin/console --user "${user}" )
if [[ -n "${bundles}" ]]; then
  createArguments+=( --requirePackages "${bundles}" )
fi

cosyses \
  --applicationName Composer \
  --applicationScript create-project.sh \
  "${createArguments[@]}"

envFile="${appPath}/.env.local"
if [[ ! -f "${envFile}" ]]; then
  echo "Writing settings to: ${envFile}"
  cat <<EOF > "${envFile}"
APP_ENV=${appEnv}
APP_SECRET=$(php -r 'echo bin2hex(random_bytes(32));')
EOF
  chown "${user}": "${envFile}"
  chmod 0640 "${envFile}"
elif ! grep -qE "^APP_SECRET=.+" "${envFile}"; then
  echo "Adding APP_SECRET to: ${envFile}"
  # Rewrite in place to keep owner and permissions of the file
  envContent=$(grep -vE "^APP_SECRET=" "${envFile}" || true)
  echo "${envContent}" > "${envFile}"
  echo "APP_SECRET=$(php -r 'echo bin2hex(random_bytes(32));')" >> "${envFile}"
else
  echo "Settings already exist: ${envFile}"
fi
