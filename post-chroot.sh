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
sed -i 's/#[^\S\n]*'"$locale"/"$locale"/ /etc/locale.gen && locale-gen
echo "
export LANG=\"${locale/ */}\"
export LC_COLLATE=\"C\"" > /etc/locale.conf
echo KEYMAP=$keymap > /etc/vconsole.conf
echo $hostname > /etc/hostname
echo "
127.0.0.1\tlocalhost
::1\t\tlocalhost
127.0.1.1\t$hostname.localdomain\t$hostname" >> /etc/hosts

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
sed -i -E 's/\s*#\s*(%wheel ALL=\(ALL\) NOPASSWD: ALL)/\1/' /etc/sudoers

# Enable multilib repo
sed -i -E 's/\s*#\s*(\[multilib\])/\1\nInclude = \/etc\/pacman\.d\/mirrorlist/' /etc/pacman.conf

# Install yay
sudo -u $username mkdir /home/$username/dev && cd /home/$username/dev 
sudo -u $username git clone https://aur.archlinux.org/yay.git && cd yay
yes | sudo -Su $username makepkg -si && rm -rf ../yay

# Install packages at ./packages
sudo -u $username yay -S --noconfirm --nopgpfetch $(sed -e 's/#.*$//' "$(cd "$(dirname $0)" && pwd)/pkgs")
