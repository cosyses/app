#!/bin/bash -e

# Cron 3.0 is the cron of Debian, here cronie takes its place: it reads the jobs in /etc/cron.d the same way (job.sh)

source "${cosysesPath}/Cron/cronie/install-base.sh"
