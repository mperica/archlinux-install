#!/usr/bin/env sh


app_name="dialog"
title="ArchLinux Install Script"
menu_main="Main Menu"
menu_disk="Disk Management"
menu_install="Install"
menu_configure="Configure"
select_exit="Exit"
select_done="Done"
select_disk="Select Disk"
select_disk_part="Create Partitions"
select_disk_format="Format Partitions"
select_disk_mount="Mount Disk"
select_editor="Select Editor"
select_install_base="Install Base System"
select_install_bootloader="Install Boot Loader"
select_install_kernel="Choose which kernel"
select_configure_hostname="Set hostname"


## Functions ##

pressanykey(){
  read -n1 -p "Press any key to continue..."
}

selecteditor(){
  options=()
  options+=("vim" "")
  options+=("nano" "")

  select=`"${app_name}" \
	  --backtitle "${title}" \
	  --title "${select_editor}" \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`
  if [ "$?" = "0" ];then
    echo "Selected editor is ${select}"
    export EDITOR=${select}
    EDITOR=${select}
    ${app_name} --msgbox "Selected Editor is ${EDITOR}" 5 30
  fi
}

selectdisk(){
  items=`lsblk -d -p -n -l -o NAME,SIZE -e 7,11`
	#items="/dev/sff 55Gb"
  options=()
  IFS_ORIG=$IFS
  IFS=$'\n'
  for i in ${items};do
      options+=("${i}" "")
  done
  IFS=$IFS_ORIG

  result=`"${app_name}" --backtitle "${title}" --title "${select_disk}" \
      --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`
  if [ "$?" != "0" ];then
    return 1
  fi
	echo ${result}
	disk=$(echo ${result} | awk '{print $1}')
	install_disk="${disk}"
  #${app_name} --msgbox "Selected disk \n${INSTALL_DISK}" 0 0
  return 0
}

selectpartdisk(){
  options=()
  options+=("btrfs" "")
  options+=("lvm" "")

  select=`"${app_name}" \
	  --backtitle "${title}" \
	  --title "${select_editor}" \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`
  if [ "$?" = "0" ];then
    echo "Selected partition type ${select}"
    partition_type=${select}
    #${app_name} --msgbox "Selected partition type \n${PARTITION_TYPE}" 0 0
  fi
}

swap(){
	swapsize=$(cat /proc/meminfo | grep MemTotal | awk '{ print $2 }')
	swapsize=$((${swapsize}/1000))"M"
	echo "The size of swap is ${swap}M"
}

partdisk(){
	selectdisk
	selectpartdisk
	${app_name} --backtitle "${title}" --title "${select_disk_part}" \
				--defaultno --yesno "Disk ${install_disk} will be formated with ${partition_type}\nAll data will be erased !	Continue ?" 0 0
	if [ "$?" = "0" ];then
	  clear
		$(echo ${partition_type})
		pressanykey
	else
	  ${app_name} --msgbox "Disk modification canceled" 0 0
	fi
}

lvm(){
	clear
	echo "Creating a new gpt table on ${install_disk}"
	parted -s ${install_disk} mklabel gpt
	echo "Creating boot EFI partition on ${install_disk}"
	parted -s ${install_disk} mkpart ESP fat32 1M 512M
	parted -s ${install_disk} set 1 boot on
	parted -s ${install_disk} name 1 EFI
	echo "Creating root partition on ${install_disk}"
  parted -s ${install_disk} mkpart LVM 513M 100%
	pressanykey
	cryptdisk
	swap
	clear
	### LVM Setup
	pvcreate /dev/mapper/crypt
	vgcreate vg0 /dev/mapper/crypt
	lvcreate --size ${swap}M vg0 --name swap
	lvcreate --size 30G vg0 --name root
	lvcreate -l +100%FREE vg0 --name home
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
}

btrfs(){
  clear
  echo "Creating a new gpt table on ${install_disk}"
  parted -s ${install_disk} mklabel gpt
  echo "Creating boot EFI partition on ${install_disk}"
  parted -s ${install_disk} mkpart ESP fat32 1M 512M
  parted -s ${install_disk} set 1 boot on
  parted -s ${install_disk} name 1 BOOT
  echo "Creating root partition on ${install_disk}"
  parted -s ${install_disk} mkpart btrfs 513M 100%
  parted -s ${install_disk} name 2 ROOT
  pressanykey
  clear
  echo
  echo "CRYPT SETUP\n"
  echo
  cryptdisk
	mkfs.vfat -F32 ${install_disk}1
	mkfs -t btrfs --force -L archlinux /dev/mapper/crypt
	mount /dev/mapper/crypt /mnt
	btrfs subvolume create /mnt/@
	btrfs subvolume set-default /mnt/@
	btrfs subvolume create /mnt/@home
	btrfs subvolume create /mnt/@cache
	btrfs subvolume create /mnt/@snapshots
	umount -R /mnt
	pressanykey
	# Mount options
	o=defaults,x-mount.mkdir
	o_btrfs=$o,compress=lzo,ssd,noatime
	clear
	mount -o compress=lzo,subvol=@,$o_btrfs /dev/mapper/archlinux /mnt
	mount -o compress=lzo,subvol=@home,$o_btrfs /dev/mapper/archlinux /mnt/home
	mount -o compress=lzo,subvol=@cache,$o_btrfs /dev/mapper/archlinux /mnt/var/cache
	mount -o compress=lzo,subvol=@snapshots,$o_btrfs /dev/mapper/archlinux /mnt/.snapshots
	mkdir -p /mnt/boot
	mount ${install_disk}1 /mnt/boot
	pressanykey
}

cryptdisk(){
	cryptsetup -q --type luks1 --cipher aes-xts-plain64 --hash sha512 \
	    --use-random --verify-passphrase luksFormat ${install_disk}2
	cryptsetup open ${install_disk}2 crypt
}

#formatdisk(){
#	${app_name} --backtitle "${title}" --title "${select_disk_format} (btrfs)" \
#	    --defaultno --yesno "Formating disk: ${install_disk}\n\n
#	    ${install_disk}1 fat32\n
#	    /dev/mapper/archlinux btrfs\n
#	    \n\nContinue ?" 0 0
#
#	if [ "$?" = "0" ];then
#	    clear
#	    mkfs.vfat -F32 ${install_disk}1
#	    mkfs -t btrfs --force -L archlinux /dev/mapper/archlinux
#	    mount /dev/mapper/archlinux /mnt
#	    btrfs subvolume create /mnt/@
#	    btrfs subvolume set-default /mnt/@
#	    btrfs subvolume create /mnt/@home
#	    btrfs subvolume create /mnt/@cache
#	    btrfs subvolume create /mnt/@snapshots
#	    umount -R /mnt
#	    pressanykey
#	else
#	    ${app_name} --msgbox "Disk formating canceled" 0 0
#	fi
#}
#
#mountdisk(){
#	# Mount options
#	o=defaults,x-mount.mkdir
#	o_btrfs=$o,compress=lzo,ssd,noatime
#	clear
#	mount -o compress=lzo,subvol=@,$o_btrfs /dev/mapper/archlinux /mnt
#	mount -o compress=lzo,subvol=@home,$o_btrfs /dev/mapper/archlinux /mnt/home
#	mount -o compress=lzo,subvol=@cache,$o_btrfs /dev/mapper/archlinux /mnt/var/cache
#	mount -o compress=lzo,subvol=@snapshots,$o_btrfs /dev/mapper/archlinux /mnt/.snapshots
#	mkdir -p /mnt/boot
#	mount ${install_disk}1 /mnt/boot
#	pressanykey
#}

# =============INSTALL===============#
installbase(){
  clear
  pkgs="base vim net-tools wireless_tools wpa_supplicant dialog bash-completion terminus-font git "
	if [ ${partition_type} = "btrfs"];then
		pkgs+="btrfs-progs snapper"
	fi
  options=()
  options+=("linux" "")
  options+=("linux-lts" "")
  options+=("linux-zen" "")
  options+=("linux-hardened" "")
  sel=$(${app_name} --backtitle "${title}" --title "Kernel" --menu "" 0 0 0 \
    "${options[@]}" \
    3>&1 1>&2 2>&3)
  if [ "$?" = "0" ]; then
    pkgs+=" ${sel}"
  else
    return 1
  fi

  pacstrap /mnt ${pkgs}

  ### Initramfs
  sed '/^\s*#/d' /mnt/etc/mkinitcpio.conf > mkinitcpio.conf.tmp
  sed -i '/MODULES=/c\MODULES=(ext4)' mkinitcpio.conf.tmp
	sed -i '/HOOKS=/c\HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems btrfs keyboard fsck)' mkinitcpio.conf.tmp
  mv mkinitcpio.conf.tmp /mnt/etc/mkinitcpio.conf
  arch-chroot /mnt mkinitcpio -p linux

  pressanykey
}

installbootloader(){
  clear
  pkgs="grub-btrfs efibootmgr"
  echo "pacstrap /mnt ${pkgs}"
  pacstrap /mnt ${pkgs}
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub
  sed -i '/GRUB_CMDLINE_LINUX=/c\GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda2:crypt:allow-discards"' /mnt/etc/default/grub
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
  pressanykey
}


# ============CONFIGURE SYSTEM =============#
configure_system(){
  clear
	# Generate fstab
  echo "Generate Fstab"
	genfstab -U -p /mnt >> /mnt/etc/fstab

  pressanykey
}

configure_hostname(){
  hostname=$(${app_name} --backtitle "${title}" --title "${menu_configure}" --inputbox "" 0 0 "archlinux" 3>&1 1>&2 2>&3)
  if [ "$?" = "0" ]; then
    clear
    echo "echo \"${hostname}\" > /mnt/etc/hostname"
    echo "${hostname}" > /mnt/etc/hostname
    pressanykey
  fi
}

### MENUS ###

mainmenu(){
  if [ "${1}" == "" ];then
    nextitem="."
  else
    nextitem="${1}"
  fi

  options=()
  options+=("${select_editor}" "")
  options+=("${menu_disk}" "")
  options+=("${menu_install}" "")
  options+=("${menu_configure}" "")
  options+=("${select_exit}" "")

  select=`"${app_name}" \
	  --backtitle "${title}" \
	  --title "${menu_main}" \
	  --default-item "${nextitem}" \
		--no-cancel \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`

  if [ "$?" == "0" ];then
    case ${select} in
      "${select_editor}")
        selecteditor
				nextitem="${menu_disk}"
      ;;
      "${menu_disk}")
        diskmenu
				nextitem="${menu_install}"
      ;;
      "${menu_install}")
        installmenu
				nextitem="${menu_configure}"
      ;;
      "${menu_configure}")
        menu_configure
				nextitem="${select_exit}"
      ;;
      "${select_exit}")
        ${app_name} --defaultno --yesno "Are you sure you whant to exit?" 0 0 && clear && exit 0
      ;;
    esac
    mainmenu "${nextitem}"
  else
    clear
  fi
}


diskmenu(){
  if [ "${1}" == "" ];then
    nextitem="."
  else
    nextitem="${1}"
  fi

  options=()
  options+=("${select_disk_part}" "")
#  options+=("${select_disk_format}" "")
#  options+=("${select_disk_mount}" "")
  options+=("${select_done}" "")

  select=`"${app_name}" \
	  --backtitle "${title}" \
	  --title "${menu_disk}" \
	  --default-item "${nextitem}" \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`

  if [ "$?" == "0" ];then
    case ${select} in
      "${select_disk_part}")
        partdisk
#	      nextitem="${select_disk_format}"
	      nextitem="${select_done}"
      ;;
#      "${select_disk_format}")
#        formatdisk
#	      nextitem="${select_disk_mount}"
#      ;;
#      "${select_disk_mount}")
#        mountdisk
#	      nextitem="${select_done}"
#      ;;
      "${select_done}")
	      mainmenu
      ;;
    esac
    diskmenu "${nextitem}"
  else
    clear
  fi
}

installmenu(){
  if [ "${1}" == "" ];then
    nextitem="."
  else
    nextitem="${1}"
  fi

  options=()
  options+=("${select_install_base}" "")
  options+=("${select_install_bootloader}" "")
  options+=("${select_done}" "")

  select=`"${app_name}" \
	  --backtitle "${title}" \
	  --title "${menu_install}" \
	  --default-item "${nextitem}" \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`

  if [ "$?" == "0" ];then
    case ${select} in
      "${select_install_base}")
        installbase
        nextitem="${select_install_bootloader}"
      ;;
      "${select_install_bootloader}")
        installbootloader
        nextitem="${select_done}"
      ;;
      "${select_done}")
        mainmenu
      ;;
    esac
    installmenu "${nextitem}"
  else
    clear
  fi
}

menu_configure(){
  if [ "${1}" == "" ];then
    nextitem="."
  else
    nextitem="${1}"
  fi

  options=()
  options+=("${select_configure_hostname}" "")
  options+=("${select_done}" "")

  select=`"${app_name}" \
	  --backtitle "${title}" \
	  --title "${menu_install}" \
	  --default-item "${nextitem}" \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`

  if [ "$?" == "0" ];then
    case ${select} in
      "${select_configure_hostname}")
        configure_hostname
        nextitem="${select_done}"
      ;;
      "${select_done}")
        mainmenu
      ;;
    esac
    menu_configure "${nextitem}"
  else
    clear
  fi
}


# Start default menu
mainmenu
