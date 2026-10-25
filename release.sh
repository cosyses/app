#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} [major|minor|patch] [message] [--yes]

Commits all changes, tags the next version, pushes and creates a GitHub release.

ARGUMENTS:
  major|minor|patch  Part of the version to increase (default: minor)
  message            Commit message and release title
                     (required when there are uncommitted changes,
                     otherwise defaults to the subject of the last commit)

OPTIONS:
  --yes              Do not ask for confirmation

Example: ${scriptName} "Fixed user action path"
Example: ${scriptName} patch "Fixed typo in usage"
EOF
}

bump="minor"
message=
confirmed=0

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
    -h|--help|-\?) usage; exit 0;;
    --yes|-y) confirmed=1;;
    major|minor|patch) bump="${1}";;
    -*) >&2 echo "Unknown option: ${1}"; usage; exit 1;;
    *)
      if [[ -n "${message}" ]]; then
        >&2 echo "Message already defined, quote it if it contains spaces"
        usage
        exit 1
      fi
      message="${1}"
      ;;
  esac
  shift
done

for requiredCommand in git gh shellcheck; do
  if [[ $(which "${requiredCommand}" | wc -l) == 0 ]]; then
    >&2 echo "Please install required package: ${requiredCommand}"
    exit 1
  fi
done

releasePath=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${releasePath}"

branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "${branch}" != "master" ]]; then
  >&2 echo "Releases are only created from master, current branch: ${branch}"
  exit 1
fi

echo "Fetching remote state"
git fetch --quiet --tags origin master

if ! git merge-base --is-ancestor origin/master HEAD; then
  >&2 echo "Local master is behind or diverged from origin/master, please pull first"
  exit 1
fi

lastVersion=$(git tag -l | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)
if [[ -z "${lastVersion}" ]]; then
  lastVersion="0.0.0"
fi

readarray -d . -t versionParts < <(printf '%s' "${lastVersion}")
major="${versionParts[0]}"
minor="${versionParts[1]}"
patch="${versionParts[2]}"

case "${bump}" in
  major) version="$((major+1)).0.0";;
  minor) version="${major}.$((minor+1)).0";;
  patch) version="${major}.${minor}.$((patch+1))";;
esac

if git rev-parse --quiet --verify "refs/tags/${version}" >/dev/null; then
  >&2 echo "Tag already exists: ${version}"
  exit 1
fi

changes=$(git status --porcelain)

if [[ -n "${changes}" ]]; then
  if [[ -z "${message}" ]]; then
    >&2 echo "There are uncommitted changes, please specify a message"
    usage
    exit 1
  fi
else
  if [[ "${lastVersion}" != "0.0.0" ]] && [[ $(git rev-list -n 1 "${lastVersion}") == $(git rev-parse HEAD) ]]; then
    >&2 echo "Nothing to release, HEAD is already tagged as: ${lastVersion}"
    exit 1
  fi
  if [[ -z "${message}" ]]; then
    message=$(git log -1 --format=%s)
  fi
fi

if [[ "${lastVersion}" != "0.0.0" ]]; then
  changedFiles=$( { git diff --name-only --diff-filter=d "${lastVersion}"; git ls-files --others --exclude-standard; } | grep -E '\.sh$' | sort -u)
else
  changedFiles=$(git ls-files --cached --others --exclude-standard | grep -E '\.sh$' | sort -u)
fi

if [[ -n "${changedFiles}" ]]; then
  echo "Checking changed scripts with shellcheck"
  readarray -t changedFileList < <(printf '%s\n' "${changedFiles}")
  if ! shellcheck --severity=error "${changedFileList[@]}"; then
    >&2 echo "Shellcheck found errors, release aborted"
    exit 1
  fi
fi

echo ""
echo "Version: ${lastVersion} -> ${version}" | sed $'s,.*,\e[1;37m&\e[m,'
echo "Message: ${message}"
if [[ -n "${changes}" ]]; then
  echo "Changes to commit:"
  echo "${changes}"
else
  echo "Commits to release:"
  if [[ "${lastVersion}" != "0.0.0" ]]; then
    git log --oneline "${lastVersion}..HEAD"
  else
    git log --oneline
  fi
fi
echo ""

if [[ "${confirmed}" == 0 ]]; then
  read -r -p "Create release ${version}? [y/N] " answer < /dev/tty
  if [[ "${answer}" != "y" ]] && [[ "${answer}" != "Y" ]]; then
    echo "Release aborted"
    exit 1
  fi
fi

if [[ -n "${changes}" ]]; then
  git add -A
  git commit --quiet -m "${message}"
  echo "Committed changes: $(git log -1 --format='%h %s')"
fi

git tag "${version}"
echo "Created tag: ${version}"

git push --quiet origin master
git push --quiet origin "${version}"
echo "Pushed master and tag: ${version}"

if ! gh release create "${version}" --verify-tag --title "${message}" --notes ""; then
  >&2 echo "Could not create release, retry with:"
  >&2 echo "gh release create ${version} --verify-tag --title \"${message}\" --notes \"\""
  exit 1
fi

echo "Successfully created release: ${version}" | sed $'s,.*,\e[0;32m&\e[m,'
