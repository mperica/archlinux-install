# Archlinux install
### for peronal use only

### Archlinux live
Increse size of cowspace to be able to install git on live system
```
mount -o remount,size=2G /run/archiso/cowspace
```

## Git Setup
```
git clone https://github.com/mperica/archlinux-install.git
```

## Partitions
### Create gpt partrition table
`parted /dev/sda mklabel gpt`
### Create EFI bootable partrition
```
parted /dev/sda mkpart ESP fat32 1MiB 513MiB
parted /dev/sda set 1 boot on
```

### Create LVM partrition of the rest of disk space
`parted /dev/sda mkpart ext4 513Mib 100%`


## Setup encryption, dont forget uppercase `YES` to confirm
```
cryptsetup -c aes-xts-plain64 -y --use-random luksFormat /dev/sda2
cryptsetup luksOpen /dev/sda2 crypt
```
### LVM Setup
```
pvcreate /dev/mapper/crypt
vgcreate vg0 /dev/mapper/crypt
lvcreate --size 8G vg0 --name swap
lvcreate --size 30G vg0 --name root
lvcreate -l +100%FREE vg0 --name home
```
### Create filesystems
```
mkfs.vfat -F32 /dev/sda1
mkswap /dev/mapper/vg0-swap
mkfs.ext4 /dev/mapper/vg0-root
mkfs.ext4 /dev/mapper/vg0-home
```

## Mount partritions
```
mount /dev/mapper/vg0-root /mnt
mount /dev/mapper/vg0-home /mnt/home
swapon /dev/mapper/vg0-swap
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
```

### Install base system and some needed packages
```
pacstrap /mnt base base-devel
genfstab -pU /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash
pacman -Sy vim git grub-efi-x86_64 efibootmgr wpa_supplicant dialog
```

## Configure system
```
ln -sf /usr/share/zoneinfo/Europe/Zagreb  /etc/localtime
hwclock --systohc --utc
echo archlinux > /etc/hostname
cp /etc/locale.gen /etc/locale.gen.bak
echo en_US.UTF-8 UTF-8 > etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 >> /etc/locale.conf
echo LANGUAGE=en_US >> /etc/locale.conf
```

## Users and passwords
```
echo root:$ROOTPASSWORD | chpasswd
useradd -m -g users -G wheel -s /bin/bash 
echo $MYUSERNAME:MYPASSWORD | chpasswd
gpasswd -a $MYUSERNAME wheel
```

## Initramfs
```
sed '/^\s*#/d' /etc/mkinitcpio.conf > mkinitcpio.conf.tmp
sed -i '/MODULES=/c\MODULES=(ext4)' mkinitcpio.conf.tmp 
sed -i '/HOOKS=/c\HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)' mkinitcpio.conf.tmp 
mv mkinitcpio.conf.tmp /etc/mkinitcpio.conf
mkinitcpio -p linux
```

## Boot Loader
### GRUB
```
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub
sed -i '/GRUB_CMDLINE_LINUX=/c\GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda2:crypt:allow-discards"' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
```
