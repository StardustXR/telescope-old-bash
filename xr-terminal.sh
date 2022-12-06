#!/bin/bash
#? safer bash options
set -euo pipefail

#? source utilities script
source util.sh

#? known working terminals
names=(alacritty kitty)

#? find which of those terminals are installed
terminals=()
for name in ${names[@]}; do
    >/dev/null command -v "$name" && terminals+=("$name")
done

[ -z "${terminals:-}" ] && {
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

#? build server and clients to make sure they're up to date
build server atmosphere flatland gravity manifold

#? run server and clients
$server_exe >/dev/null &
sleep 0.1

$atmosphere_exe >/dev/null &
$flatland_exe >/dev/null &
$gravity_exe -- 0 -0.5 -0.25 $manifold_exe >/dev/null &
sleep 0.1

$chosen_term -e bash -c 'echo Click inside the black window back on your desktop to send keyboard and mouse input to this terminal!; echo; $SHELL' >/dev/null
