#!/bin/bash -e

userName="${1}"
shift
command="${1}"
shift
parameters=("$@")

for parameter in "${parameters[@]}"; do
  command+=" \"${parameter}\""
done

sudo -H -u "${userName}" bash -c "if [[ \$(which ini-parse | wc -l) -eq 0 ]]; then if [[ -f ~/.profile ]]; then source ~/.profile; elif [[ -f ~/.bash_profile ]]; then source ~/.bash_profile; fi; fi; ${command}"
