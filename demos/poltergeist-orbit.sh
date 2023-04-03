#!/bin/bash
#? safer bash options
set -euo pipefail

#? source utilities script
source util.sh

#? build server and clients to make sure they're up to date
build server atmosphere poltergeist orbit gravity manifold

#? run server and clients
$server_exe >/dev/null &
sleep 0.1

$atmosphere_exe >/dev/null &
$gravity_exe -- 0 0 -0.25 $poltergeist_exe >/dev/null &
$gravity_exe -- 0.5 0.25 -0.25 $orbit_exe >/dev/null &
$gravity_exe -- 0 -0.5 -0.25 $manifold_exe >/dev/null &
sleep 0.1

$chosen_term -e bash -c 'echo Click inside the black window back on your desktop to send keyboard and mouse input to this terminal!; echo; $SHELL' >/dev/null
