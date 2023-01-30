#!/bin/bash
#? safer bash options
set -euo pipefail

>/dev/null command -v doas && su_cmd=doas \
|| >/dev/null command -v sudo && su_cmd=sudo

[ -d repos/ ] || ./setup.sh

echo "Which of these describes your XR setup?"
echo '1: Meta Quest 1/2'
echo '2: PCVR headset'
echo '0: No headset'

read -p '-> ' response
echo

setup_types=(flatscreen wivrn monado)
selected="${setup_types[$response]}"

case $selected in
    flatscreen)
        echo 'Stardust XR can be used without a headset, in flatscreen mode.'
        echo 'This is only really useful for development or testing purposes, but it works well enough to try things out!'
        read -p '(press enter to continue) '
        ;;

    wivrn)
        echo 'Quest support relies on the WiVRn project.'
        echo 'Would you like a guided installation? (Only Arch Linux is currently fully supported)'
        read -p '(Y/n) -> ' response
        echo

        [ "$response" == n ] || [ "$response" == N ] && {
            echo 'Make sure to set it up manually before using Stardust!'
        } || {
            dependencies=(cmake ninja gcc pkgconf vulkan-icd-loader ffmpeg
                          eigen avahi nlohmann-json sed glslang python
                          vulkan-headers libxrandr adb)

            command -v pacman >/dev/null && {
                echo 'pacman found, automatically installing dependencies...'
                $su_cmd pacman -S --needed ${dependencies[@]}
                echo --------------------------------
                echo
            } || {
                echo 'pacman not found, please install the following dependencies manually:'
                echo ${dependencies[@]}
                echo
                read -p '(press enter to continue) '
                echo
            }

            echo 'If your Quest does not have developer mode enabled, follow this guide:'
            echo 'https://vr-expert.com/kb/how-to-activate-developer-mode-on-your-meta-quest-headset/'
            echo

            echo 'Please plug in your developer-enabled Quest!'
            adb wait-for-device
            echo

            wivrn_url='https://github.com/Meumeu/WiVRn'
            # tag="$(git describe --tags `git rev-list --tags --max-count=1`)"
            tag=v0.3
            client_file='WiVRn-oculus-release.apk'
            client_path="releases/download/$tag/$client_file"
   
            [ -d WiVRn/ ] || {
                echo "Cloning $wivrn_url..."
                git clone -q "$wivrn_url" WiVRn/

                pushd WiVRn >/dev/null

                echo "Checking out tag $tag"
                git checkout -q "$tag"
                popd >/dev/null
                echo --------------------------------
                echo
            }

            echo 'Enabling avahi daemon...'   
            $su_cmd systemctl enable --now avahi-daemon.service
            echo --------------------------------
            echo

            pushd WiVRn/ >/dev/null
            echo 'Starting build...'
            cmake -B build-server . -GNinja -DWIVRN_BUILD_CLIENT=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
            cmake --build build-server
            echo --------------------------------
            echo

            read -p 'Set WiVRn as the default OpenXR runtime? This is required for Stardust XR. (Y/n): ' response
            echo

            [ "$response" != n ] && [ "$response" != N ] && {
                echo 'setting as default'
                mkdir -p ~/.config/openxr/1/
                ln --symbolic --force $PWD/build-server/openxr_wivrn-dev.json ~/.config/openxr/1/active_runtime.json
                echo --------------------------------
                echo
            }

            echo 'Downloading WiVRn client...'
            rm -f "$client_file"
            wget -q "$wivrn_url/$client_path" -O "$client_file"
            echo --------------------------------
            echo
            
            [ "$(adb devices)" == *no\ permissions* ] && {
                            
                echo "Configuring adb"
                [ -f "/etc/udev/rules.d/99-android.rules" ] || {
                    $su_cmd touch "/etc/udev/rules.d/99-android.rules"
                }
                $su_cmd echo "SUBSYSTEM=='usb', ATTR{idVendor}=='2833', ATTR{idProduct}=='0183', MODE='0666', GROUP='plugdev'" >> /etc/udev/rules.d/99-android.rules
                $su_cmd udevadm control --reload-rules
                $su_cmd service udev restart
                echo "Unplug and replug Quest 2"
                read -p '(press enter once device has been replugged)'
                echo
            }
            [ "$(adb devices)" == *unauthorized* ] && {
                echo "Put on your quest and accept the popup to give authorization to install the WiVRn Client"
                read -p '(press enter once popup is accepted)'
                
            }
                        
            [ "$(adb devices)" == *no\ permissions* ] || [ "$(adb devices)" == *unauthorized* ] && {
                echo "Configuration failed. Rerun the script or check out https://linux-tips.com/t/adb-device-unauthorized-problem/254 to configure manually."
                echo
            }

            echo 'Installing client...'
            adb install -r "$client_file"
            echo --------------------------------
            echo

            echo 'Starting test'
            echo
            popd >/dev/null
   
            pushd repos/server/ >/dev/null
            echo 'Building Stardust XR server...'
            cargo build
            echo --------------------------------
            echo
            popd >/dev/null
            
            echo 'The server will run for 10 seconds to check that nothing crashes.'
            echo
            
            echo 'Please put on your headset!'
            echo
            read -p '(press enter to continue) '
            echo

            echo 'Killing old processes...'
            killall -wq wivrn-server ||:
            killall -wq stardust-xr-server ||:

            echo 'Starting WiVRn client...'
            until adb shell pidof org.meumeu.wivrn >/dev/null; do
                adb shell monkey -p org.meumeu.wivrn 1 &>/tmp/telescope-adb.log
                sleep 0.5
            done

            echo 'Starting WiVRn server...'
            #? possibly the weirdest workaround to a bug i've ever needed to do: this `sleep inf`
            sleep inf | ./WiVRn/build-server/server/wivrn-server &>/tmp/telescope-wivrn.log &

            until grep -q 'Server started' /tmp/telescope-wivrn.log; do sleep 0.1; done
            sleep 1

            echo 'Starting Stardust XR server...'
            ./repos/server/target/debug/stardust-xr-server &>/tmp/telescope-stardust.log &
            sleep 10
            echo

            grep -q WiVRn /tmp/telescope-stardust.log \
            && echo 'No crashes detected, ending test...' \
            || {
                echo 'Stardust failed to connect to WiVRn!'
                echo 'Logs are available in /tmp/telescope-*.log'
                fail=true
            }
            killall -wq wivrn-server ||:
            killall -wq stardust-xr-server ||:
            
            [ "${fail:-}" == true ] && exit 1
            
            echo --------------------------------
        }
        ;;
        
    monado)
        echo 'Guided setup for PCVR headsets via Monado is not implemented yet.'
        echo 'Please install Monado manually for now!'
        echo
        echo 'https://gitlab.freedesktop.org/monado/monado'
esac
echo

echo "$selected" > .hmd-setup
echo 'Setup complete!'
