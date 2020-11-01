#!/bin/sh

# Set custom screen resolution
xrandr -s 1600x900

# Disable mouse acceleration (Why the FUCK is it enabled by default!)
for id in $(seq 50); do 
	if [ ! -z "$(xinput list-props $id 2>/dev/null | grep 'libinput Accel Profile Enabled (')" ]; then
		xinput --set-prop $id 'libinput Accel Profile Enabled' 0, 1 && echo 'Changing Accel Profile for <device id '"$id"'> to (0, 1)'
	fi
done

# Set custom keyboard layout
setkbmap colemak

# Execute programs (WM, Compositor, App launcher, Bar, ...)
exec bspwm
wal -R
picom -f &
$HOME/.config/polybar/launch