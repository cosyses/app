#!/bin/bash -e

# MailCatcher 0.6 needs Ruby before 3.2 (thin 1.5 uses Fixnum). The dependencies are pinned: mime-types 2.99 as in the
# Ubuntu routine, eventmachine and thin to the versions MailCatcher 0.6 resolves to, sqlite3 1.4, mini_mime 1.1.2 and
# mail 2.7 as versions that still support Ruby 2.5 (gem of Ruby 2.5 would pick the latest versions).
mailcatcherVersion="0.6.5"
mailcatcherDependencies="mime-types:2.99.1 eventmachine:1.0.9.1 thin:1.5.1 sqlite3:1.4.4 mini_mime:1.1.2 mail:2.7.1"

source "${cosysesPath}/MailCatcher/gem/install-base.sh"
