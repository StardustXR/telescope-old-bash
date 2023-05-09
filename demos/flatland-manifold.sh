#!/bin/bash

# shellcheck disable=SC2154
#? disabled because the *_exe and *_log variables are generated procedurally
#  in util.sh

#? safer bash options
set -euo pipefail
export IFS=$'\n'

#? source utilities script
source util.sh

#? build server and clients to make sure they're up to date
build server atmosphere flatland gravity manifold

#? run server and clients
"$(repo-exe server)" |& strip-ansi >"$(repo-log server)" &
sleep 0.2

"$(repo-exe atmosphere)"                                     &>"$(repo-log atmosphere)" &
"$(repo-exe flatland)"                                       &>"$(repo-log flatland)" &
"$(repo-exe gravity)" -- 0 -0.5 -0.25 "$(repo-exe manifold)" &>"$(repo-log gravity)" &
sleep 0.1

# shellcheck disable=SC2016
#? disabled because $SHELL is intended to be treated literally
"$(terminal)" -e bash -c 'echo Click inside the black window back on your desktop to send keyboard and mouse input to this terminal!; echo; $SHELL' &>logs/terminal.log
