#!/bin/bash -e

gemName="${1}"

gem list --local "${gemName}" | grep -P "^${gemName}\s" | grep -ohP "[0-9]+(\.[0-9]+)*" | cat
