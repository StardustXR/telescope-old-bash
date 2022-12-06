[ -d repos/ ] || ./setup.sh

#? build the named repo
function build() {
    for repo in $@; do
        pushd "repos/$repo" >/dev/null
        2>&1 >/dev/null cargo build --release
        popd >/dev/null
    done
}

#? run the named repo
function run() {
    pushd "repos/$1" >/dev/null
    shift
    2>&1 >/dev/null cargo run --release $@ &
    popd >/dev/null
}

#? set WAYLAND_DISPLAY to ensure Wayland clients launch in Stardust
# function set_display() {
    for i in {0..32}; do
        lockfile="$XDG_RUNTIME_DIR/wayland-$i.lock"
        ! [ -f "$lockfile" ] || flock -w 0.01 "$lockfile" true && {
            export WAYLAND_DISPLAY="wayland-$i"
            break
        }
    done
# }

#? generate variables holding the absolute path to each repo's executable
pushd repos >/dev/null
for repo in *; do
    target_dir="$PWD/$repo/target/release/"
 
    [ -d "$target_dir" ] || {
        pushd ../ >/dev/null
        build "$repo"
        popd >/dev/null
    }
    
    pushd "$target_dir" >/dev/null
    for file in *; do
        [ -f "$file" ] && [ -x "$file" ] && target_exe="$file" && break
    done
    popd >/dev/null

    eval "${repo}_exe=$target_dir/$target_exe"
done
popd >/dev/null

#? print exit message and ensure all child processes are terminated when exiting
trap "echo -e '\rExiting Stardust XR'; trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

