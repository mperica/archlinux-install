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
parted /dev/sda mklabel gpt
## Create EFI bootable partrition
parted /dev/sda mkpart ESP fat32 1MiB 513MiB
parted /dev/sda set 1 boot on

## Create LVM partrition of the rest of disk space
parted /dev/sda mkpart ext4 513Mib 100%

## Setup encryption, dont forget uppercase `YES` to confirm
echo "Time for encrypting your harddrive"
cryptsetup -c aes-xts-plain64 -y --use-random luksFormat /dev/sda2
echo "Enter password to unlock crypt volume"
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
mount /dev/mapper/vg0-home /mnt/home
swapon /dev/mapper/vg0-swap
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

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
arch-chroot /mnt /bin/bash
pacman -Sy vim git grub-efi-x86_64 efibootmgr wpa_supplicant dialog networkmanager --noconfirm

## Configure system
systemctl enable NetworkManager.service
ln -sf /usr/share/zoneinfo/Europe/Zagreb  /etc/localtime
hwclock --systohc --utc
echo archlinux > /etc/hostname
cp /etc/locale.gen /etc/locale.gen.bak
echo en_US.UTF-8 UTF-8 > etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 >> /etc/locale.conf
echo LANGUAGE=en_US >> /etc/locale.conf

## Users and passwords
while [[ -z $rootpass  ]]; do
  echo "Enter password for root account"
  read rootpass
done;
echo $rootpass
echo root:$rootpass | chpasswd
while [[ -z $user  ]]; do
  echo "Enter the name of new user"
  read user
done;
useradd -m -g users -G wheel -s /bin/bash $user
while [[ -z $userpass  ]]; do
  echo "Enter password for user ${user}"
  read userpass
done;
echo $userpass
echo $user:userpass | chpasswd
echo "Creating user ${user} with password ${userpass}"
gpasswd -a $user wheel
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo "Added user ${user} to group wheel"

### Initramfs
sed '/^\s*#/d' /etc/mkinitcpio.conf > mkinitcpio.conf.tmp
sed -i '/MODULES=/c\MODULES=(ext4)' mkinitcpio.conf.tmp 
sed -i '/HOOKS=/c\HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)' mkinitcpio.conf.tmp 
mv mkinitcpio.conf.tmp /etc/mkinitcpio.conf
mkinitcpio -p linux

## Boot Loader
### GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub
sed -i '/GRUB_CMDLINE_LINUX=/c\GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda2:crypt:allow-discards"' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "The script is finished"
echo "To reboot to yout new system enter exit and press [ENTER]: "
read  exit
if [[ $exit ]];then
  echo "rebooting..."
else
  echo "exiting installer"
fi
