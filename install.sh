#! /bin/bash

set -e

# Exit if boot mode isn't UEFI
[ -d /sys/firmware/efi ] || (printf 'Non-UEFI boot modes aren'\''t supported! Aborting' && \
    sleep 1 && printf . && sleep 1 && printf . && sleep 1 && echo .  && exit)

pacman -S --noconfirm fzf nano

#=================================================================
#                           User Info
#=================================================================

read -r -p 'Username: ' username
read -r -p 'Hostname: ' hostname
read -r -p 'Keymap: ' keymap

printf 'Select a timezone: '
zone=$(find /usr/share/zoneinfo -type f | sed 's/\/usr\/share\/zoneinfo\///g' | fzf --height=99)

printf 'Select a locale: '
locale=$(cat /etc/locale.gen | grep -E '^#[[:alnum:]]' | sed 's/#//g' | fzf --height=99)

read -r -p 'Cpu manufacturer (intel/amd): ' cpu_manufacturer
lsblk
read -r -p 'Block device identifier (sda): ' sdx
read -r -p 'Root partition size (30720): ' root

# Set blank variables to default values
[ -z $sdx ] && sdx=sda
[ -z $boot ] && boot=512
[ -z $swap ] && swap=$(cat /proc/meminfo | grep MemTotal | awk '/MemTotal/ { printf $2*1.5toupper($3) }' | tr 'B' ' ' | numfmt --from=iec)
[ -z $root ] && root=30720

blk_dev=/dev/"$sdx"
sctr_l=$(cat /sys/block/$sdx/queue/hw_sector_size)

# Helper functions
cal () { awk "BEGIN{print $*}"; }
dec () { - $(cal $sctr_l - $*); }
toB () { numfmt --from=iec --suffix=B $1 }
mnt () { mkdir -p $2 && mount $1 $2; }

#=================================================================
#                       Preparing the disk
#=================================================================

# Calculate disk space for each partition
boot_end=$(cal 2048 \* sctr_l + $(toB $boot))
swap_end=$(cal $boot_end + $(toB $swap))
root_end=$(cal $swap_end + $(toB $root))

# Create the partitions
parted $blk_dev mklabel gpt
parted -a optimal -s $blk_dev -- \
	 mkpart boot	fat32		2048s		$(dec $boot_end) \
	 set 1 boot on \
	 mkpart swap	linux-swap	$boot_end	$(dec $swap_end) \
	 mkpart rootfs	ext4 		$swap_end	$(dec $root_end) \
	 mkpart home	ext4 		$root_end	-34s

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

read -r -p 'Do you want to enable additional pacman repositories (Y/n)? ' ans
[[ -z $ans || $ans = Y || $ans = y ]] && nano /etc/pacman.conf

#======== Gimme perms plz ========#
sed -Ei 's/#[[:blank:]]+(''\%wheel ALL\=\(ALL\) NOPASSWD\: ALL'')/\1/' /etc/sudoers

pkgs=$(sed -e 's/#.*$//' -e 's/ /\n/' pkgs)

cat << eof | sudo -u $username /bin/bash

#======== YAY! ========#
mkdir tmp && cd tmp
git clone https://aur.archlinux.org/yay.git && cd yay
yes | makepkg -si
rm -rf ../yay

#======== Additional packages ========#
yay -S --noconfirm $pkgs

eof

EOF

#===============================================================================
#                             Enjoy the `Artix`!
#===============================================================================

umount -R /mnt
reboot
