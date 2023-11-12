#!/bin/bash -e

install-package gnupg

server="${1}"
key="${2}"
apt-key adv --keyserver "${server}" --recv-keys "${key}"
