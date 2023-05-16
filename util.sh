#!/bin/bash

[ -d repos/ ] || ./setup.sh
[ -f .hmd-setup ] || ./hmd-setup.sh
[ -f /tmp/telescope.log ] && rm /tmp/telescope.log
[ -d logs/ ] && rm -f logs/*

#? write to stderr
function echoerr() {
    echo "$@" 1>&2
    return 1
}

#? strip ANSI escape sequences from stdin
function strip-ansi() {
    sed 's/\x1b\[[0-9;]*m//g' -u
}

#? write to log
function log() {
    local fn="${FUNCNAME[1]} -"
    [ "$fn" = 'source -' ] && fn='-'

    if [ "$1" = '' ]; then
        echo >> /tmp/telescope.log
    else
        echo "[$(basename "$0")] $fn $1" >> /tmp/telescope.log
    fi
}

#? build the named repo
function build() {
    log "building:" "$@"
    for repo in "$@"; do
        echo "building: $repo"
        log "building: $repo"
        pushd "repos/$repo" >/dev/null || exit $?
        cargo build --release >/dev/null 2>&1
        popd >/dev/null || exit $?
    done
}

#? run the named repo
function run() {
    log "running: $1"
    pushd "repos/$1" >/dev/null || exit $?
    shift
    cargo run --release "$@" >/dev/null 2>&1 &
    popd >/dev/null || exit $?
}

#? run the named repos' tests
function run-tests() {
    export IFS=' '
    log "testing: $*"
    failed=false
    for repo in "$@"; do
        echo "testing: $repo"
        pushd "repos/$repo" >/dev/null || exit $?

        if cargo test |& strip-ansi > "../../logs/$repo-tests"; then
            log "PASS : $repo"
        else
            echo "$repo: FAIL - check logs/$repo-tests" 1>&2
            log "FAIL : $repo"
            failed=true
        fi

        popd >/dev/null || exit $?
    done

    $failed && return 1
}

#? set WAYLAND_DISPLAY to ensure Wayland clients launch in Stardust
function wl-display() {
    for i in {0..32}; do
        lockfile="${XDG_RUNTIME_DIR:-/run/user/$UID}/wayland-$i.lock"
        ! [ -f "$lockfile" ] || flock -w 0.01 "$lockfile" true && {
            export WAYLAND_DISPLAY="wayland-$i"
            set_display_success=true
            log "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
            log ''
            break
        }
    done
    ${set_display_success:-false} || echo "warning: failed to set WAYLAND_DISPLAY properly; Wayland apps probably won't work"
}

#? return the exe path for the named repo
function repo-exe() {
    target_exe=''
    pushd "repos/$1/target/release" >/dev/null || exit $?
    for file in *; do
        [ -f "$file" ] && [ -x "$file" ] && {
            target_exe="$file"
        } && break
    done

    [ -z "$target_exe" ] && {
        echo "unable to determine executable path for $repo" 1>&2
        exit 1
    }

    readlink -e "$target_exe"
    popd >/dev/null || exit $?
}

#? return the log path for the named repo
function repo-log() {
    echo -n "$(readlink -f "$PWD/logs/$1.log")"
}

#? generate variables holding the absolute paths to each repo's executable and log locations
function gen_repo_vars() {
    pushd repos >/dev/null || exit $?
    for repo in *; do
        target_dir="$PWD/$repo/target/release/"
        log "$repo"

        [ -d "$target_dir" ] || {
            pushd ../ >/dev/null
            build "$repo"
            popd >/dev/null || exit $?
        }

        pushd "$target_dir" >/dev/null || exit $?
        for file in *; do
            [ -f "$file" ] && [ -x "$file" ] && {
                target_exe="$file"
            } && break
        done
        popd >/dev/null || exit $?

        log "  ${repo}_exe=$target_dir/$target_exe"
        log "  ${repo}_log=$PWD/logs/$target_exe.log"
        eval "${repo}_exe=$target_dir/$target_exe"
        eval "${repo}_log=$PWD/../logs/$target_exe.log"

        log ''
    done
    popd >/dev/null || exit $?
}

#? pick a terminal to use
function terminal() {
    #? known working terminals
    names=(alacritty kitty)

    terminals=()
    for name in "${names[@]}"; do
        >/dev/null command -v "$name" && terminals+=("$name")
    done

    [ -z "${terminals[*]}" ] && {
        echo 'no known working terminals found!'
        exit 1
    }

    #? only one known working terminal is found
    if [ "${#terminals[@]}" == 1 ]; then
        chosen_term=${terminals[0]}
        echo -n "$chosen_term"

    #? multiple choices are available
    else
        #? list known working terminals
        echo 'found terminal programs:'
        i=0
        for term in "${terminals[@]}"; do
            ((i=i+1))

            echo "$i: $term"
        done

        #? prompt the user to choose a terminal to use from the list
        read -rp 'choose a terminal (number): ' chosen_num
        chosen_term=${terminals[$((chosen_num - 1))]}

        echo -n "$chosen_term"
    fi
}

#? run setup functions automatically
wl-display
# gen_repo_vars

#? print exit message and ensure all child processes are terminated when exiting
trap 'echo -e '"'\rExiting Stardust XR'"'; trap - SIGTERM && kill -- -$$' SIGINT SIGTERM EXIT

#? create logging folder
mkdir -p logs

#? unit tests
# shellcheck disable=SC2015
#? disabled because the behavior is intended
[ "${TELESCOPE_TEST_MODE:-}" = true ] && {
    trap '' SIGINT SIGTERM EXIT
    fails=()

    #? strip-ansi
    {
        [ "$(echo -e "\033[1;32mtest text\033[0m" | strip-ansi)" = 'test text' ] \
        || echoerr "error: strip-ansi returned '$(echo -e "\033[1;32mtest text\033[0m" | strip-ansi)' instead of 'test text'"
    } || fails+=('strip-ansi')

    #? log
    {
        log '[logging test]'
        grep -q '[logging test]' /tmp/telescope.log \
        || echoerr 'error: test entry was not found in /tmp/telescope.log'
    } || fails+=('log')

    #? build
    {
        mkdir -p repos/build-test
        pushd repos/build-test >/dev/null || exit $?
        cargo init >/dev/null 2>&1 ||:
        popd >/dev/null || exit $?

        build build-test >/dev/null
        [ -e repos/build-test/target/release/build-test ] \
        || echoerr 'error: unable to locate built executable'
    } || fails+=('build')
    rm -rf repos/build-test/

    #? run
    {
        mkdir -p repos/run-test
        pushd repos/run-test >/dev/null || exit $?
        cargo init >/dev/null 2>&1 ||:
        popd >/dev/null || exit $?

        run run-test
        wait
        [ -e repos/run-test/target/release/run-test ] \
        || echoerr 'error: unable to locate built executable'
    } || fails+=('run')
    rm -rf repos/run-test/

    #? wl-display
    #NOTE: i'm not sure how to test this..

    #? repo-exe
    {
        mkdir -p repos/repo-exe-test
        pushd repos/repo-exe-test >/dev/null || exit $?
        cargo init >/dev/null 2>&1 ||:
        cargo build -q --release >/dev/null
        popd >/dev/null || exit $?

        returned="$(repo-exe repo-exe-test)"
        expected="$(readlink -f "$PWD/repos/repo-exe-test/target/release/repo-exe-test")"

        [ "$returned" = "$expected" ] \
        || echoerr -e "error:\n  returned '$returned'\n  expected '$expected'"
    } || fails+=('repo-exe')
    rm -rf repos/repo-exe-test/


    #? repo-log
    {
        mkdir -p repos/repo-log-test
        pushd repos/repo-log-test >/dev/null || exit $?
        cargo init >/dev/null 2>&1 ||:
        cargo build -q --release >/dev/null
        popd >/dev/null || exit $?

        returned="$(repo-log repo-log-test)"
        expected="$(readlink -f "$PWD/logs/repo-log-test.log")"

        [ "$returned" = "$expected" ] \
        || echoerr -e "error:\n  returned '$returned'\n  expected '$expected'"
    } || fails+=('repo-log')
    rm -rf repos/repo-log-test/

    [ -n "${fails[*]}" ] && {
        echo
        echo "$0: unit tests failed:" 1>&2
        echo "${fails[*]}"
        exit 1
    }
} ||: