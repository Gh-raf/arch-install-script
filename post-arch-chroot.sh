set -e

hostname+='FlowBox'
username+='adderall'
keymap+='colemak'
zone+='Europe/London'
locale+='en_GB.UTF-8 UTF-8'

##################################
####    Post-installation     ####
##################################

pacman -Syy

# Setup the Timezone, Localisation, Language, Keymap, Hostname, Hosts
ln -sf /usr/share/zoneinfo/$zone /etc/localtime && hwclock --systohc
sed -i -E 's/#[^\S\n]*'"$locale"/"$locale"/ /etc/locale.gen && locale-gen
echo LANG="${locale/ */}" > /etc/locale.conf
echo KEYMAP=$keymap > /etc/vconsole.conf
echo $hostname > /etc/hostname
echo "
127.0.0.1	localhost
::1			localhost
127.0.1.1	$hostname.localdomain	$hostname" >> /etc/hosts

# Install networkmanager, bootloader, microcode and git
pacman -S --noconfirm networkmanager grub efibootmgr os-prober intel-ucode


# Enable Internet for next session
systemctl enable NetworkManager

# Setup grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
grub-mkconfig -o /boot/grub/grub.cfg

# Add user
useradd -m -g wheel -G audio,video,storage $username
chpasswd <<< "$username:$username"
chpasswd <<< "root:root"

# Give wheel group sudo perms
sed -i -E 's/\s*#\s*(%wheel ALL=\(ALL\) NOPASSWD: ALL)/\1/' /etc/sudoers

# Install yay
sudo -u $username mkdir /home/$username/dev && cd /home/$username/dev 
sudo -u $username git clone https://aur.archlinux.org/yay.git && cd yay
yes | sudo -Su $username makepkg -si && rm -rf ../yay

# Install packages at ./packages
sudo -u $username yay -S --noconfirm --nopgpfetch $(sed -e 's/#.*$//' "$(cd "$(dirname $0)" && pwd)/pkgs")
