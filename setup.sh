#!/bin/bash
#? safer bash options
set -euo pipefail

#? list of Stardust XR repos to download/link
mkdir -p repos
repos=(
    server
    atmosphere
    comet
    flatland
    gravity
    magnetar
    manifold
    molecules
    orbit
    poltergeist
    protostar
)

repo_url="https://github.com/StardustXR"

#? shortcut for cloning a repo by name
function clone() {
    git clone --quiet "$repo_url/$1/" "$1"
}

#? temporarily enter repos/
pushd repos/ >/dev/null

#? ensure each repo is available in repos/
to_clone=()
prev_location=""
first_prompt=true
for repo in ${repos[@]}; do
    #? repo is already available
    [ -e $repo ] && {
        echo "found: $repo"

        #? fancy prompt shenanigans
        echo
        echo -e '\e[2A'

    #? repo isn't already available
    } || {
        echo "not found: $repo"

        $first_prompt && {
            echo "Leave blank to download automatically, or provide an absolute path."
            first_prompt=false
        }

        #? fancy prompt shenanigans
        read -p '-> ' -i "$prev_location" -e location
        echo -e '\e[1A\e[0K\n'

        #? if user left the prompt blank, add the repo to the list to be cloned
        [ -z "$location" ] && {
            to_clone+=("$repo")

        #? else, symlink the location they provided to its respective place
        } || {
            processed_location="$(echo $location | sed "s|~|$HOME|g")"
            ln -s "$processed_location" "$repo"

            prev_location="$location"
        }

        #? fancy prompt shenanigans
        echo -e '\e[3A'
    }
done
echo

#? fetch each repo to be cloned in parallel
[ -n "${to_clone:-}" ] && {
    echo "cloning:"
    for repo in ${to_clone[@]}; do
        echo "  - $repo_url/$repo/"
        clone "$repo" &
    done
    wait
    echo
}

#? check for missing repos, this won't happen unless the script has a bug
missing=()
for repo in ${repos[@]}; do
    [ -d $repo ] || missing+=("$repo")
done

[ -n "${missing:-}" ] && {
    echo "error: missing repos: ${missing[@]}" 2>&1
    exit 1
}

#? return from repos/
popd >/dev/null
