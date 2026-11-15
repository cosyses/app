#!/bin/bash -e

# Ubuntu 20.04 has Erlang 22.2, RabbitMQ 3.8.16 and later require Erlang 23.2 to 24.x
erlangVersion="24.3.4.17"

source "${cosysesPath}/RabbitMQ/3.8/Ubuntu/install-base.sh"
