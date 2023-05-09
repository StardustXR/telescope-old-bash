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
build server atmosphere poltergeist orbit gravity manifold

#? run server and clients
"$(repo-exe server)" |& strip-ansi >"$(repo-log server)" &
sleep 0.2

"$(repo-exe atmosphere)"                                          &>"$(repo-log atmosphere)" &
"$(repo-exe gravity)" -- 0 0 -0.25      "$(repo-exe poltergeist)" &>"$(repo-log gravity).1" &
"$(repo-exe gravity)" -- 0.5 0.25 -0.25 "$(repo-exe orbit)"       &>"$(repo-log gravity).2" &
"$(repo-exe gravity)" -- 0 -0.5 -0.25   "$(repo-exe manifold)"    &>"$(repo-log gravity).3" &
sleep 0.1

# shellcheck disable=SC2016
#? disabled because $SHELL is intended to be treated literally
"$(terminal)" -e bash -c 'echo Click inside the black window back on your desktop to send keyboard and mouse input to this terminal!; echo; $SHELL' &>logs/terminal.log
