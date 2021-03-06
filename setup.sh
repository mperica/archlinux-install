#!/bin/bash


# Archlinux install
### for peronal use only

### Archlinux live
#Increse size of cowspace to be able to install git on live system
# mount -o remount,size=2G /run/archiso/cowspace
# pacman -Sy git
# git clone https://github.com/mperica/archlinux-install.git

## Partitions
### Create gpt partrition table
parted /dev/sda mklabel gpt -s
## Create EFI bootable partrition
parted /dev/sda mkpart ESP fat32 1MiB 513MiB -s
parted /dev/sda set 1 boot on -s

## Create LVM partrition of the rest of disk space
parted /dev/sda mkpart ext4 513Mib 100% -s

## Setup encryption, dont forget uppercase `YES` to confirm
echo "Time for encrypting your harddrive"
cryptsetup -c aes-xts-plain64 -y --use-random luksFormat /dev/sda2 -q
echo "Unlock crypt volume"
cryptsetup luksOpen /dev/sda2 crypt

### LVM Setup
echo "Setup your partritions"
pvcreate /dev/mapper/crypt
vgcreate vg0 /dev/mapper/crypt
echo "Enter the size in of your swap partition in GB:"
while [[ ! $swap =~ ^[0-9]+$ ]]; do
  echo "Enter numbers only"
  read swap
done;
lvcreate --size ${swap}G vg0 --name swap
echo "The size of swap is ${swap}GB"

echo "Enter the size of your root partition in GB:"
while [[ ! $root =~ ^[0-9]+$ ]]; do
  echo "Enter numbers only"
  read root
done;
lvcreate --size ${root}G vg0 --name root
echo "The size of root is ${root}GB"
lvcreate -l +100%FREE vg0 --name home
echo "The size of home is "`lsblk | grep /boot | awk '{print $4}'`

### Create filesystems
mkfs.vfat -F32 /dev/sda1
mkswap /dev/mapper/vg0-swap
mkfs.ext4 /dev/mapper/vg0-root
mkfs.ext4 /dev/mapper/vg0-home

## Mount partritions
mount /dev/mapper/vg0-root /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount /dev/sda1 /mnt/boot
mount /dev/mapper/vg0-home /mnt/home
swapon /dev/mapper/vg0-swap

echo "Checking for mountpoints"
df -h
echo "Do you want to continue? Y/n"
read continue
if [ $continue == "n" ];then
  exit
fi


### Install base system and some needed packages
pacstrap /mnt base base-devel
genfstab -pU /mnt >> /mnt/etc/fstab
#arch-chroot /mnt /bin/bash
arch-chroot /mnt pacman -Sy vim git grub-efi-x86_64 efibootmgr wpa_supplicant dialog networkmanager --noconfirm

## Configure system
arch-chroot /mnt systemctl enable NetworkManager.service
ln -sf /usr/share/zoneinfo/Europe/Zagreb /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc --utc
echo archlinux > /mnt/etc/hostname
cp /etc/locale.gen /mnt/etc/locale.gen.bak
echo en_US.UTF-8 UTF-8 > /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo LANG=en_US.UTF-8 >> /mnt/etc/locale.conf
echo LANGUAGE=en_US >> /mnt/etc/locale.conf

## Users and passwords

while true; do
	read -p "Enter password for root account: " rootpass
	echo "Do you want to change root password to ${rootpass}? (y/N):"
	read INPUT
	case $INPUT in
		n|no)
			continue	;;
		y|yes)	echo "Adding root password"
			echo "root:${rootpass}" | chpasswd -R /mnt
			echo "Done."
			break		;;
	esac
done

echo "Creating user"
while true; do
	read -p "Enter username: " username
	read -p "Enter password: " userpass
	echo "Do you want to create user ${username} with password ${userpass}? (y/N):"
	read INPUT
	case $INPUT in
		n|no)
			continue	;;
		y|yes)	echo "Creating new user ${username}"
			arch-chroot /mnt useradd -m -g users -G wheel -s /bin/bash $username
			echo "${username}:${userpass}" | chpasswd -R /mnt
			arch-chroot /mnt gpasswd -a $username wheel
			echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /mnt/etc/sudoers
			echo "Done."
			break		;;
	esac
done


### Initramfs
sed '/^\s*#/d' /mnt/etc/mkinitcpio.conf > mkinitcpio.conf.tmp
sed -i '/MODULES=/c\MODULES=(ext4)' mkinitcpio.conf.tmp 
sed -i '/HOOKS=/c\HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)' mkinitcpio.conf.tmp 
mv mkinitcpio.conf.tmp /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -p linux

## Boot Loader
### GRUB
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub
sed -i '/GRUB_CMDLINE_LINUX=/c\GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda2:crypt:allow-discards"' /mnt/etc/default/grub
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

read -p "The script has finished to reboot to your new system press [ENTER]: "
reboot
