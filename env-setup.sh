##################################
####    Environment Setup     ####
##################################

un_cmt () { sed -i 's/^[^\S\n]*#\s*'"$2"/"$2"/ $1; }
cfg () { echo $HOME/.config/$1; }
mkd () { mkdir -p $(cfg $1); }
ins () { install -Dm755 $1 $(cfg $2); }

# Autorun Bspwm on X server startup
echo 'exec bspwm' >> $HOME/.xinitrc

# Create config dir for theses programs
mkd bspwm && mkd sxhkd && mkd polybar && mkd picom && mkd fish && mkd kitty && mkd rofi

# Use default config for bspwm & sxhkd & polybar & picom
cd /usr/share/doc/bspwm/examples
ins bspwmrc bspwm && ins sxhkdrc sxhkd
ins ../../polybar/config polybar
ins /etc/xdg/picom.conf.example picom/picom.conf

# Set kitty as terminal and rofi as app launcher for sxhkd
sed -i -e 's/urxvt/kitty/' -e 's/dmenu_run/rofi -show run/' $(cfg sxhkd)/sxhkdrc

# Autorun Picom & Polybar on Bspwm startup
sed -i 2i'\npicom &' $(cfg bspwm)/bspwmrc
echo '#!/bin/sh\nkillall -q polybar\nwhile pgrep -u $UID -x polybar >/dev/null; do sleep 1; done\n\npolybar mybar &\n\necho "Polybar launched..."' > $HOME/.config/polybar/launch
chmod 755 $(cfg polybar)/launch && echo $(cfg polybar)/launch >> $(cfg bspwm)/bspwmrc

# py-wal customization
echo 'wal -R' >> $HOME/.xinitrc
echo 'fish -c '\''cat ~/.cache/wal/sequences\'\'' &' >> $(cfg fish)/config.fish
echo '\n. "${HOME}/.cache/wal/colors.sh"\nbspc config normal_border_color "$color1"\nbspc config active_border_color "$color2"\nbspc config focused_border_color "$color15"\nbspc config presel_feedback_color "$color1"' >> $(cfg bspwm)/bspwmrc
echo 'include ~/.cache/wal/colors-kitty.conf' >> $(cfg kitty)/kitty.conf
echo '@import "~/.cache/wal/colors-rofi-dark";' >> $(cfg rofi)/config.rasi

# Polybar + py-wal <=== gotta do somework :/

# ZSH
# yay -S --noconfirm zsh zsh-theme-powerlevel10k-git zsh-autosuggestions zsh-completions zsh-history-substring-search zsh-syntax-highlighting
# sed -i -e 's/^ZSH_THEME.*$/ZSH_THEME="random"/' -e 's/^\s*#?\s*ZSH_CUSTOM.*$/ZSH_CUSTOM=/usr/share/zsh' $HOME/.zshrc

# No mouse accel
echo 'for id in $(seq 50); do if [ ! -z "$(xinput list-props $id 2>/dev/null | grep '\''libinput Accel Profile Enabled ('\'')" ]; then xinput --set-prop $id '\''libinput Accel Profile Enabled'\'' 0, 1 && echo '\''Changing Accel Profile for <device id '\''"$id"'\''> to (0, 1)'\''; fi; done' >> $HOME/.xinitrc

# END

exit

# Tune volume: amixer alsamixer pulseaudio-ctl

# Hardware Acceleration
# libva-intel-driver libva-utils libva-vdpau-driver vdpauinfo
# Verify VA-API (libva), using vainfo (libva-utils)
# VAEntrypointVLD => able to decode format
# VAEntrypointEncSlice => able to encode format
# https://wiki.archlinux.org/index.php/Hardware_video_acceleration
# Verify VDPAU, using vdpauinfo
# No error message => Okay config
