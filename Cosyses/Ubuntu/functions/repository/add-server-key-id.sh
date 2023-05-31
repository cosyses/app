#!/bin/bash -e

server="${1}"
key="${2}"
apt-key adv --keyserver "${server}" --recv-keys "${key}"
