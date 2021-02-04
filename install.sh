#! /bin/bash

set -e

# Exit if boot mode isn't UEFI
[ -d /sys/firmware/efi ] || (printf 'Non-UEFI boot modes aren'\''t supported! Aborting' && \
    sleep 1 && printf . && sleep 1 && printf . && sleep 1 && echo .  && exit)

pacman -S --noconfirm fzf neovim

# Helper functions
cal () { awk "BEGIN{print $*}"; }
dec () { cal $* - $sctr_l; }
MiB_B () { cal $1 \* 1048576; }
mnt () { mkdir -p $2 && mount $1 $2; }

#=================================================================
#                           User Info
#=================================================================

lsblk

read -r -p 'Username: ' username
read -r -p 'Hostname: ' hostname
read -r -p 'Keymap: ' keymap

printf 'Select a timezone: '
zone=$(find /usr/share/zoneinfo -type f | sed 's/\/usr\/share\/zoneinfo\///g' | fzf)

printf 'Select a locale: '
locale=$(cat /etc/locale.gen | grep -E '^#[[:alnum:]]' | sed 's/#//g' | fzf)

read -r -p 'Cpu manufacturer (intel/amd): ' cpu_manufacturer

read -r -p 'Block device identifier (sda): ' sdx
read -r -p 'Boot partition size (512): ' boot
read -r -p 'Swap partition size (8192): ' swap
read -r -p 'Root partition size (30720): ' root

# Set blank variables to default values
[ -z $sdx ] && sdx=sda
[ -z $boot ] && boot=512
[ -z $swap ] && swap=8192
[ -z $root ] && root=30720

blk_dev=/dev/"$sdx"
sctr_l=$(cat /sys/block/$sdx/queue/hw_sector_size)

#=================================================================
#                       Preparing the disk
#=================================================================

# Calculate disk space for each partition
boot_end=$(cal 2048 \* sctr_l + $(MiB_B $boot))
swap_end=$(cal $boot_end + $(MiB_B $swap))
root_end=$(cal $swap_end + $(MiB_B $root))

# Create the partitions
parted $blk_dev mklabel gpt
parted -a optimal -s $blk_dev -- \
	 mkpart boot	fat32		2048s $(dec $boot_end)B \
	 set 1 boot on \
	 mkpart swap	linux-swap	"$boot_end"B $(dec $swap_end)B  \
	 mkpart rootfs	ext4 		"$swap_end"B $(dec $root_end)B \
	 mkpart home	ext4 		"$root_end"B -34s

# Format the partitions
mkfs.fat -F32 "$blk_dev"1
mkswap "$blk_dev"2
swapon "$blk_dev"2
mkfs.ext4 "$blk_dev"3
mkfs.ext4 "$blk_dev"4

# Mount the partitions
mnt "$blk_dev"3 /mnt
mnt "$blk_dev"1 /mnt/boot
mnt "$blk_dev"4 /mnt/home

#=================================================================
#                      Installing base system
#=================================================================

basestrap /mnt base base-devel runit elogind-runit linux linux-zen linux-firmware man-db man-pages
fstabgen -U /mnt >> /mnt/etc/fstab

cat << EOF | artix-chroot /mnt

pacman -Syy

#======== Timezone ========#
ln -sf /usr/share/zoneinfo/$zone /etc/localtime && hwclock --systohc

#======== Locale ========#
echo $locale >> /etc/locale.gen && locale-gen
cat << eof >> /etc/locale.conf
LANG="${locale/ */}"
LC_COLLATE="C"
eof

#======== Keymap ========#
echo KEYMAP=$keymap > /etc/vconsole.conf

#======== Hostname ========#
echo $hostname > /etc/hostname

#======== Hosts ========#
cat << eof >> /etc/hosts
127.0.0.1	localhost
::1		localhost
127.0.1.1	$hostname.localdomain	$hostname
eof

#======== Boot, Connectivity & else ========#
pacman -S --noconfirm grub efibootmgr os-prober "$cpu_manufacturer"-ucode dhcpcd connman-runit connman-gtk git go

#======== Setup grub ========#
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Linux
grub-mkconfig -o /boot/grub/grub.cfg

#======== Initializing the initializer ========#
ln -s /etc/runit/sv/connmand /etc/runit/runsvdir/default

#======== User & Root accounts ========#
useradd -m -g wheel -G audio,video,storage,optical $username
chpasswd <<< "$username:$username"
chpasswd <<< "root:root"

tmp='%wheel ALL=(ALL) NOPASSWD: ALL'
#======== Gimme perms plz ========#
sed -i 's/.*'$tmp'.*/'$tmp'/' /etc/sudoers

#======== YAY! ========#
cd /tmp && git clone https://aur.archlinux.org/yay.git && cd yay
yes | sudo -Su $username makepkg -si && rm -rf ../yay

bl='[[:blank:]]'
nbl='[^[:blank:] && ^#]'
#======== Additional packages ========#
read -r -p 'Do you want to enable additional pacman repositories (Y/n)? ' ans
[[ -z $ans || $ans = Y || $ans = y ]] && nvim /etc/pacman.conf

sudo -u $username yay -S --noconfirm \
    $(sed -E -e 's/^('$nbl'+('$bl'+'$nbl'+)*)*'$bl'*#.*$/\1/g' -e '/^$/d' pkgs)

EOF

#===============================================================================
#                             Enjoy the `Artix`!
#===============================================================================

umount -R /mnt
reboot
