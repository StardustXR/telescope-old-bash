[ -d repos/ ] || ./setup.sh
[ -f .hmd-setup ] || ./hmd-setup.sh
[ -f /tmp/telescope.log ] && rm /tmp/telescope.log

#? build the named repo
function build() {
    echo "[util.sh] build - building: $@" >> /tmp/telescope.log
    for repo in $@; do
        echo "[util.sh] build - built: $repo" >> /tmp/telescope.log
        pushd "repos/$repo" >/dev/null
        2>&1 >/dev/null cargo build --release
        popd >/dev/null
    done
}

#? run the named repo
function run() {
    echo "[util.sh] run - $1" >> /tmp/telescope.log
    pushd "repos/$1" >/dev/null
    shift
    2>&1 >/dev/null cargo run --release $@ &
    popd >/dev/null
}

#? set WAYLAND_DISPLAY to ensure Wayland clients launch in Stardust
for i in {0..32}; do
    lockfile="${XDG_RUNTIME_DIR:-/run/user/$UID}/wayland-$i.lock"
    ! [ -f "$lockfile" ] || flock -w 0.01 "$lockfile" true && {
        export WAYLAND_DISPLAY="wayland-$i"
        set_display_success=true
        echo "[util.sh] - WAYLAND_DISPLAY=$WAYLAND_DISPLAY" >> /tmp/telescope.log
        echo >> /tmp/telescope.log
        break
    }
done
${set_display_success:-false} || echo "warning: failed to set WAYLAND_DISPLAY properly; Wayland apps probably won't work"

#? generate variables holding the absolute path to each repo's executable
pushd repos >/dev/null
for repo in $(ls -1); do
    echo "[util.sh] setup - $repo" >> /tmp/telescope.log
    echo "[util.sh]       - target_dir=$PWD/$repo/target/release/" >> /tmp/telescope.log
    target_dir="$PWD/$repo/target/release/"
 
    [ -d "$target_dir" ] || {
        pushd ../ >/dev/null
        build "$repo"
        popd >/dev/null
    }
    
    pushd "$target_dir" >/dev/null
    for file in *; do
        [ -f "$file" ] && [ -x "$file" ] && {
            echo "[util.sh]       - target_exe=$file" >> /tmp/telescope.log
            target_exe="$file"
        } && break
    done
    popd >/dev/null

    echo "[util.sh] - ${repo}_exe=$target_dir/$target_exe" >> /tmp/telescope.log
    eval "${repo}_exe=$target_dir/$target_exe"
    
    echo >> /tmp/telescope.log
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
#? print exit message and ensure all child processes are terminated when exiting
trap "echo -e '\rExiting Stardust XR'; trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
