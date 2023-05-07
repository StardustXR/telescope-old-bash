[ -d repos/ ] || ./setup.sh
[ -f .hmd-setup ] || ./hmd-setup.sh
[ -f /tmp/telescope.log ] && rm /tmp/telescope.log
[ -d logs/ ] && rm -f logs/*

#? strip ANSI escape sequences from stdin
function strip-ansi() {
    sed 's/\x1b\[[0-9;]*m//g' -u
}

#? write to log
function log() {
    local fn="${FUNCNAME[1]} -"
    [ "$fn" = 'source -' ] && fn='-'

    [ "$1" = '' ] && {
        echo >> /tmp/telescope.log
    } || {
        echo "[$(basename $0)] $fn $1" >> /tmp/telescope.log
    }
}

#? build the named repo
function build() {
    log "building:" $@
    for repo in $@; do
        echo "building: $repo"
        log "building: $repo"
        pushd "repos/$repo" >/dev/null
        2>&1 >/dev/null cargo -q build --release
        popd >/dev/null
    done
}

#? run the named repo
function run() {
    log "running: $1"
    pushd "repos/$1" >/dev/null
    shift
    2>&1 >/dev/null cargo run --release $@ &
    popd >/dev/null
}

#? set WAYLAND_DISPLAY to ensure Wayland clients launch in Stardust
function wl_display() {
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

#? generate variables holding the absolute paths to each repo's executable and log locations
function gen_repo_vars() {
    pushd repos >/dev/null
    for repo in $(ls -1); do
        target_dir="$PWD/$repo/target/release/"
        log "$repo"

        [ -d "$target_dir" ] || {
            pushd ../ >/dev/null
            build "$repo"
            popd >/dev/null
        }

        pushd "$target_dir" >/dev/null
        for file in *; do
            [ -f "$file" ] && [ -x "$file" ] && {
                target_exe="$file"
            } && break
        done
        popd >/dev/null

        log "  ${repo}_exe=$target_dir/$target_exe"
        log "  ${repo}_log=$PWD/logs/$target_exe.log"
        eval "${repo}_exe=$target_dir/$target_exe"
        eval "${repo}_log=$PWD/../logs/$target_exe.log"

        log ''
    done
    popd >/dev/null
}

#? known working terminals
names=(alacritty kitty)

#? find which of those terminals are installed
terminals=()
for name in ${names[@]}; do
    >/dev/null command -v "$name" && terminals+=("$name")
done

[ -z "$terminals" ] && {
    echo 'no known working terminals found!'
    exit 1
}

#? only one known working terminal is found
[ "${#terminals[@]}" == 1 ] && {
    chosen_term=${terminals[0]}

#? multiple choices are available
} || {
    #? list known working terminals
    echo 'found terminal programs:'
    i=0
    for term in ${terminals[@]}; do
        ((i=i+1))

        echo "$i: $term"
    done

    #? prompt the user to choose a terminal to use from the list
    read -p 'choose a terminal (number): ' chosen_num
    chosen_term=${terminals[$((chosen_num - 1))]}
}

#? run setup functions automatically
wl_display
gen_repo_vars

#? print exit message and ensure all child processes are terminated when exiting
trap "echo -e '\rExiting Stardust XR'; trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

#? create logging folder
mkdir -p logs
