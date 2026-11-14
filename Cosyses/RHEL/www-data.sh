#!/bin/bash -e

# Ubuntu and Debian have the user www-data (uid 33), which many scripts use for web servers and PHP. Distributions
# without it get it with the same uid if it is free, the group gets its own id (gid 33 is tape on RHEL and Fedora).
if ! getent group www-data >/dev/null 2>&1; then
  echo "Creating group: www-data"
  groupadd --system www-data
fi
if ! id www-data >/dev/null 2>&1; then
  echo "Creating user: www-data"
  if getent passwd 33 >/dev/null 2>&1; then
    useradd --system --gid www-data --home-dir /var/www --no-create-home --shell /sbin/nologin www-data
  else
    useradd --system --uid 33 --gid www-data --home-dir /var/www --no-create-home --shell /sbin/nologin www-data
  fi
fi
