#!/bin/sh

# Set custom screen resolution
# xrandr -s <size>/<width>x<height>

# Disable mouse acceleration (Why the FUCK is it enabled by default!)
for id in $(seq 50); do 
	if [ ! -z "$(xinput list-props $id 2>/dev/null | grep 'libinput Accel Profile Enabled (')" ]; then
		xinput --set-prop $id 'libinput Accel Profile Enabled' 0, 1 && echo 'Changing Accel Profile for <device id '"$id"'> to (0, 1)'
	fi
done

# Set custom keyboard layout
setkbmap $(grep 'KEYMAP' /etc/vconsole.conf | sed -E 's/^KEYMAP=//')

# Start some nice programs
if [ -d /etc/X11/xinit/xinitrc.d ]; then
	for f in /etc/X11/xinit/xinitrc.d/?*.sh; do
		[ -x "$f" ] && . "$f"
	done
	unset f
fi

# Run Bspwm, Py-wal, Picom, Polybar
wal -R
exec bspwm &
picom -f &

killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done
polybar example &

sleep 30d
