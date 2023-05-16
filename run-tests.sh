#!/bin/bash
#? safer bash options
set -euo pipefail
export IFS=$'\n'

source util.sh

#? remove exit message
trap '' SIGINT SIGTERM EXIT

#? check all scripts for issues using shellcheck
mapfile -t scripts < <(find . -regex '.+\.sh')
fails=()
echo 'running script tests...'
for script in "${scripts[@]}"; do
    shellcheck -x "$script" || {
        fails+=("$script")
        echo "---------------- $script: FAIL ----------------"
    }

done

if [ -n "${fails[*]}" ]; then
    echo
    echo 'the following scripts did not pass shellcheck:'
    echo "${fails[*]}"
    exit 1
fi

#? run script unit tests
echo "running script unit tests..."
export TELESCOPE_TEST_MODE=true
./util.sh

#? check that the server and all the clients pass their tests
echo 'running server and client tests...'
run-tests server atmosphere comet flatland gravity magnetar manifold molecules orbit poltergeist protostar >/dev/null
