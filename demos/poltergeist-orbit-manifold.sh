#!/bin/bash
#? safer bash options
set -euo pipefail
export IFS=$'\n'

#? source utilities script
source util.sh

#? build server and clients to make sure they're up to date
build server atmosphere poltergeist orbit gravity manifold

#? run server and clients
$server_exe |& strip-ansi >$server_log &
sleep 0.2

$atmosphere_exe                                 &>$atmosphere_log &
$gravity_exe -- 0 0 -0.25      $poltergeist_exe &>$gravity_log.1 &
$gravity_exe -- 0.5 0.25 -0.25 $orbit_exe       &>$gravity_log.2 &
$gravity_exe -- 0 -0.5 -0.25   $manifold_exe    &>$gravity_log.3 &
sleep 0.1

$chosen_term -e bash -c 'echo Click inside the black window back on your desktop to send keyboard and mouse input to this terminal!; echo; $SHELL' &>logs/terminal.log
