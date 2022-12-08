# telescope
### See the stars
`telescope` is a collection of scripts that serve as an installation and setup guide, and introduction to Stardust XR and related projects.

## XR setup
Before you can use Stardust XR, you'll likely need to install [Monado](https://gitlab.freedesktop.org/monado/monado) or [WiVRn](https://github.com/Meumeu/WiVRn) depending on your setup.
It is possible to use Stardust without an XR setup at all and simply render it as a window on your existing 2D display server for testing/demo purposes, however!

Currently, there's a somewhat rough mostly-automatic setup guide for Meta Quest users via WiVRn, but a guide for setting up standard Monado is on the way.
`hmd-setup.sh` will walk you through the installation process and automate as many things as possible.

## Stardust XR installation
'Stardust', generally speaking, refers to the Stardust server and multiple Stardust clients. Running clients isn't strictly necessary, but you won't get a lot done without them!

You can clone the server along with all of the current first-party clients by running the `setup.sh` server included in this repo.
The source code for each repository will be downloaded to the `repos/` folder, and the demos will automatically compile them when needed.

## xr-terminal.sh
This is a simple setup for running a terminal in XR. Not all terminals will work right out the gate, but `kitty` and `alacritty` are currently known to.

## Clients
-- WIP --
