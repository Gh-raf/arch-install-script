set -e

##################################
####          CONFIG          ####
##################################

blk_dev='sda'
sctr_l='512'
boot='512'
swap='8192'
root='30720'

##################################
####     UTILITY FUNCTIONS    ####
##################################

cal() { awk "BEGIN{print $*}"; }
dec () { cal $* - $sctr_l; }
MiB_B () { cal $1 \* 1048576; }
x () { echo /dev/$blk_dev$1; }

##################################
####     Pre-installation     ####
##################################

# Exit if boot mode isn't UEFI
[ -d /sys/firmware/efi ] || (echo 'Non-UEFI boot modes aren'\''t supported! Aborting...' && sleep 5 && exit)

# Calculate disk space for each partition
boot_end=$(cal 2048 \* sctr_l + $(MiB_B $boot))B
swap_end=$(cal $boot_end + $(MiB_B $swap))B
root_end=$(cal $swap_end + $(MiB_B $root))B

# Sync sys clock
timedatectl set-ntp true

# Create and Format the partitions
parted $(x) -- mklabel gpt
parted -s $(x) -- \
	 mkpart boot fat32 		2048s $(dec $boot_end) \
	 set 1 boot on \
	 mkpart swap linux-swap $boot_end $(dec $swap_end)  \
	 mkpart root ext4 		$swap_end $(dec $root_end) \
	 mkpart home ext4 		$root_end -34s
mkfs.fat -F32 $(x 1)
mkswap $(x 2)
swapon $(x 2)
mkfs.ext4 $(x 3)
mkfs.ext4 $(x 4)

# Mount and Setup Dirs
mount $(x 3) /mnt
mkdir -p /mnt/boot && mount $(x 1) /mnt/boot
mkdir /mnt/home && mount $(x 4) /mnt/home

# Install Base System (tty)
pacstrap /mnt base base-devel linux linux-firmware man-db man-pages texinfo
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
