#!/bin/bash
#? safer bash options
set -euo pipefail
export IFS=$'\n'

function clean() {
    pushd "$1" >/dev/null
    cargo clean &>/dev/null
    popd >/dev/null
    echo "cleaned $1"
}

pushd repos/ >/dev/null
[ -z "$*" ] && repos=(*) || repos=("$@")
for repo in "${repos[@]}"; do
    clean "$repo" &
done
wait
popd >/dev/null
