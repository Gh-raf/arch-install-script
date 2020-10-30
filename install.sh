set -e

# Exit if boot mode isn't UEFI
efivar -l || (echo 'Non-UEFI boot modes aren'\''t supported! Aborting...' && sleep 5 && exit)

	prompt () { read -p "$1" rep && grep -qE ^"$rep"$ <<< $2 && echo $rep || prompt "$1" "$2"; }
	cal() { awk "BEGIN{print $*}"; }
	MiB_B () { cal $1 \* 1048576; }
	x () { echo /dev/$SDX$1; }
	un_cmt () { sed -i 's/^[^\S\n]*#\s*'"$2"/"$2"/ $1; }
	cfg () { echo $HOME/.config/$1; }
	mkd () { mkdir -p $(cfg $1); }
	ins () { install -Dm755 $1 $(cfg $2); }

KEYMAPS=$(ls -R /usr/share/kbd/keymaps/ | grep -E '.*\.map\.gz$' | cut -f 1 -d '.')
REGIONS=$(ls -d /usr/share/zoneinfo/*/ | xargs basename -a | grep -E '^[A-Z]')
LOCALES=$(cat /etc/locale.gen | grep -E '^\s*#?\w' | tr '#' '')

##################################
#### Ask User a Bunch'a stuff ####
##################################

# Keymap
echo $KEYMAPS | tr ' ' '\n' | column -x && KEYMAP=$(prompt 'Type one keymap from the above list: ' "$KEYMAPS")
loadkeys $KEYMAP

# Timezone
echo $REGIONS && REGION=$(prompt 'Type one REGIONion from the above list: ' "$REGIONS")
CITYS=$(ls /usr/share/zoneinfo/$REGION)
echo $CITYS && CITY=$(prompt 'Type one city from the above list: ' "$CITYS")

# Locale
echo $LOCALES && LOCALE=$(prompt 'Type one locale from the above list: ' "$LOCALES")

# Additional info ...
read -p 'Root password: ' ROOTPSWD
read -p 'Hostname: ' HOSTNAME
read -p 'Username: ' USER
read -p 'Password: ' PASSWD
parted -l
read -p 'Block device: ' SDX
SCTR_SIZE=$(prompt "$SDX"\''s logical sector size (512 or 4096): ' "$(echo -e '512\n4096')")
echo 'All next values are to be given as integers (in MiB)!'
read -p 'Boot partition size (default 512): ' BOOT_SIZE
read -p 'Swap partition size (default 8192): ' SWAP_SIZE
read -p 'Root partition size (default 30720): ' ROOT_SIZE

##################################
####     Pre-installation     ####
##################################

# Calculate disk space for each partition
BOOT_END=$(cal $(2048 * SCTR_SIZE) + $(MiB_B $BOOT_SIZE))B
SWAP_END=$(cal $BOOT_END + $(MiB_B $SWAP_SIZE))B
ROOT_END=$(cal $SWAP_END + $(MiB_B $ROOT_SIZE))B

# Sync sys clock
timedatectl set-ntp true

# Create and Format the partitions
parted -s $(x) -- mklabel gpt \
	 mkpart boot fat32 2048s $BOOT_END \
	 set 1 boot on \
	 mkpart swap linux-swap $BOOT_END $SWAP_END  \
	 mkpart root ext4 $SWAP_END $ROOT_END \
	 mkpart home ext4 $ROOT_END -34s
mkfs.fat -F32 $(x 1)
mkswap $(x 2)
swapon $(x 2)
mkfs.ext4 $(x 3)
mkfs.ext4 $(x 4)

# Mount and Setup Dirs
mount $(x 3) /mnt
mkdir -p /mnt/boot && mount $(x 1) /mnt/boot
mkdir /mnt/home && mount $(x 4) /mnt/home

##################################
####   Install & Sys config   ####
##################################

# Install Base System (tty)
pacstrap /mnt base base-devel linux linux-firmware man-db man-pages texinfo
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt

# Setup the Timezone, Localisation, Language, Keymap, Hostname, Hosts
ln -sf /usr/share/zoneinfo/$REGION/$CITY /etc/localtime && hwclock --systohc
un_cmt /etc/locale.gen "$LOCALE" && locale-gen
echo LANG="${LOCALE/ */}" >> /etc/locale.conf
echo KEYMAP=$KEYMAP >> /etc/vconsole.conf
echo $HOSTNAME > /etc/hostname
echo '\n127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t'$HOSTNAME'.localdomain\t'$HOSTNAME >> /etc/hosts

##################################
####   Network Boot Drivers   ####
##################################

# Install Boot, CPU, Drivers, Sound related stuff ...
pacman -S --noconfirm networkmanager grub efibootmgr os-prober intel-ucode alsa-utils pulseaudio pulseaudio-alsa pulseaudio-ctl yay

# Enable NetworkManager
systemctl enable NetworkManager

# Setup GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
grub-mkconfig -o /boot/grub/grub.cfg

##################################
####   Refining the Desktop   ####
##################################

# Install Xserver, Drivers, Deamons, (DE), Programs, Dumb stuff, Bloated programs, Fonts                  
yay -S --noconfirm xorg-server xorg-xinit xdo \
	mesa xf86-video-intel libva-intel-driver libva-utils libva-vdpau-driver vdpauinfo \
	cpupower gamemode ananicy \
	bspwm sxhkd polybar picom python-pywal rofi \
	git fish dash devour \
	emacs neovim kitty ranger zathura cava mpv sxiv qutebrowser \
	figlet toilet cmatrix lolcat fortune-mod \
	hmcl stretchly-bin firefox-developer-edition visual-studio-code-bin \
	ttf-linux-libertine ttf-inconsolata noto-fonts ttf-font-awesome ttf-anonymous-pro ttf-dejavu ttf-liberation ttf-unifont ttf-ms-fonts
					# mpd + nmcpppmcpppcc

# Enable cpupower & ananicy
systemctl enable cpupower
systemctl enable ananicy

# Set dash as default Shell for sh scripts
cd /bin && rm sh && ln -s dash sh

# Give sudo perms to wheel group
un_cmt /etc/sudoers '%wheel ALL=(ALL) NOPASSWD: ALL'

# Add Wheel $USER
useradd -m -g wheel -G audio,video,storage $USER

# Change passwords
chpasswd <<< "root:$ROOTPSWD"
chpasswd <<< "$USER:$PASSWD"

##################################
####    Environment Setup     ####
##################################

# Login ad $USER
su - $USER

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
echo 'for id in {1..50}; do if [ ! -z "$(xinput list-props $id 2>/dev/null | grep '\''libinput Accel Profile Enabled ('\'')" ]; then xinput --set-prop $id '\''libinput Accel Profile Enabled'\'' 0, 1 && echo '\''Changing Accel Profile for <device id '\''"$id"'\''> to (0, 1)'\''; fi; done' >> $HOME/.xinitrc

# END

read -F "Type anything to reboot..." REBOOT
exit && exit && umount -l /mnt && reboot

# Tune volume: amixer alsamixer pulseaudio-ctl

# Hardware Acceleration
# libva-intel-driver libva-utils libva-vdpau-driver vdpauinfo
# Verify VA-API (libva), using vainfo (libva-utils)
# VAEntrypointVLD => able to decode format
# VAEntrypointEncSlice => able to encode format
# https://wiki.archlinux.org/index.php/Hardware_video_acceleration
# Verify VDPAU, using vdpauinfo
# No error message => Okay config
