set -e

hostname+='FlowBox'
username+='adderall'
keymap+='colemak'
zone+='Europe/London'
locale+='en_GB.UTF-8 UTF-8'
cpu_manufacturer+='intel' # intel/amd

##################################
####    Post-installation     ####
##################################

pacman -Syy

# Setup the Timezone, Localisation, Language, Keymap, Hostname, Hosts
ln -sf /usr/share/zoneinfo/$zone /etc/localtime && hwclock --systohc
echo $locale >> /etc/locale.gen && locale-gen

cat << EOF >> /etc/locale.conf
export LANG="${locale/ */}"
export LC_COLLATE="C"
EOF

echo KEYMAP=$keymap > /etc/vconsole.conf
echo $hostname > /etc/hostname

cat << EOF >> /etc/hosts
127.0.0.1	localhost
::1		localhost
127.0.1.1	$hostname.localdomain	$hostname
EOF

# Install bootloader, microcode and git
pacman -S --noconfirm grub efibootmgr os-prober "$cpu_manufacturer"-ucode dhcpcd connman-runit connman-gtk git

# Setup grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Linux
grub-mkconfig -o /boot/grub/grub.cfg

ln -s /etc/runit/sv/connmand /etc/runit/runsvdir/default

# Add user
useradd -m -g wheel -G audio,video,storage,optical $username
chpasswd <<< "$username:$username"
chpasswd <<< "root:root"

# Give wheel group sudo perms
# Enable multilib and lib32 repo

##################################
####    Pkgs-installation     ####
##################################

# Install yay
sudo -u $username mkdir /home/$username/dev && cd /home/$username/dev 
sudo -u $username git clone https://aur.archlinux.org/yay.git && cd yay
yes | sudo -Su $username makepkg -si && rm -rf ../yay

# Install packages at ./packages
sudo -u $username yay -S --noconfirm --nopgpfetch $(sed -E -e 's/^[[:blank:]]*([^[:blank:]]([[:blank:]][^[:blank:]])*)*[[:blank:]]*#.*$/\1/g' "$(cd "$(dirname $0)" && pwd)/pkgs")
