set -e

##################################
####          CONFIG          ####
##################################

hostname='FlowBox'
username='adderall'
keymap='colemak'
zone='Europe/London'
locale='en_GB.UTF-8 UTF-8'

##################################
####     UTILITY FUNCTIONS    ####
##################################

un_cmt () { sed -i 's/^[^\S\n]*#\s*'"$2"/"$2"/ $1; }
cfg () { echo $HOME/.config/$1; }
mkd () { mkdir -p $(cfg $1); }
ins () { install -Dm755 $1 $(cfg $2); }

##################################
####    Post-installation     ####
##################################

pacman -Syy

# Setup the Timezone, Localisation, Language, Keymap, Hostname, Hosts
ln -sf /usr/share/zoneinfo/$zone /etc/localtime && hwclock --systohc
un_cmt /etc/locale.gen "$locale" && locale-gen
echo LANG="${locale/ */}" > /etc/locale.conf
echo KEYMAP=$keymap > /etc/vconsole.conf
echo $hostname > /etc/hostname
echo '\n127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t'$hostname'.localdomain\t'$hostname > /etc/hosts

# Install Boot, CPU, Drivers, Sound related stuff ...
pacman -S --noconfirm networkmanager grub efibootmgr os-prober intel-ucode git

# Setup GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
grub-mkconfig -o /boot/grub/grub.cfg

# Add user
useradd -m -g wheel -G audio,video,storage $username
chpasswd <<< "$username:$username"
chpasswd <<< "root:root"

# Install yay
sudo -u $username mkdir /home/$username/dev && cd /home/$username/dev 
sudo -u $username git clone https://aur.archlinux.org/yay.git && cd yay
echo $username | sudo -Su $username yes | makepkg -si && rm -rf ../yay

##################################
####   Refining the Desktop   ####
##################################

# Install Xserver, Drivers, Sound, Deamons, (DE), Programs, Dumb stuff, Bloated programs, Fonts

sudo -u $username yay -S --noconfirm --nopgpfetch xorg-server xorg-xinit xdo xdg-user-dirs \
	mesa xf86-video-intel libva-intel-driver libva-utils libva-vdpau-driver vdpauinfo \
	alsa-utils pulseaudio pulseaudio-alsa pulseaudio-ctl \
	cpupower gamemode ananicy \
	bspwm sxhkd polybar picom python-pywal rofi \
	git fish dash devour \
	emacs neovim kitty ranger zathura cava mpv sxiv qutebrowser \
	figlet toilet cmatrix lolcat fortune-mod \
	stretchly-bin firefox-developer-edition visual-studio-code-bin \
	ttf-linux-libertine ttf-inconsolata noto-fonts ttf-font-awesome ttf-anonymous-pro ttf-dejavu ttf-liberation ttf-ms-fonts
					# mpd + nmcpppmcpppcc

# Enable systemd services
systemctl enable NetworkManager
systemctl enable cpupower
systemctl enable ananicy

# sh => dash for performance
cd /bin && rm sh && ln -s dash sh

# Give sudo perms to wheel group
un_cmt /etc/sudoers '%wheel ALL=(ALL) NOPASSWD: ALL'
