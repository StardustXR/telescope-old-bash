#!/bin/bash
#? safer bash options
set -euo pipefail

function pull() {
    pushd "$1" >/dev/null
    git pull -q
    popd >/dev/null
    echo "updated $1"
}

pushd repos/ >/dev/null
for repo in *; do
    pull $repo &
done
wait
popd >/dev/null
