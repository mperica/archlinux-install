#!/usr/bin/env sh


app="dialog"
title="ArchLinux Install Script"
menu_main="Main Menu"
menu_disk="Disk Management"
menu_install="Install Menu"
select_exit="Exit"
select_done="Done"
select_disk="Select Disk"
select_disk_part="Create Partitions"
select_disk_format="Format Partitions"
select_disk_mount="Mount Disk"
select_editor="Select Editor"
select_install_base="Install Base System"


## Functions ##

pressanykey(){
  read -n1 -p "Press any key to continue..."
}

selecteditor(){
  options=()
  options+=("vim" "")
  options+=("nano" "")

  select=`"${app_name}" \
	  --backtitle "title" \
	  --title "${select_editor}" \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`
  if [ "$?" = "0" ];then
    echo "Selected editor is ${select}"
    export EDITOR=${select}
    EDITOR=${select}
    ${app_name} --msgbox "Selected Editor is ${select}" 5 30
  fi
}

selectdisk(){
  items=`lsblk -d -p -n -l -o NAME,SIZE -e 7,11`
  options=()
  IFS_ORIG=$IFS
  IFS=$'\n'
  for i in ${items};do
      options+=("${i}" "")
  done
  IFS=$IFS_ORIG

  result=`"${app_name}" --backtitle "title" --title "${select_disk}" \
      --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`
  if [ "$?" != "0" ];then
    return 1
  fi
	echo ${result}
	disk=$(echo ${result} | awk '{print $1}')
	export install_disk="${disk}"
  return 0
}

partdisk(){
	selectdisk
	${app_name} --backtitle "title" --title "${select_disk_part}" \
			--defaultno --yesno "Selected device : ${install_disk}\n\nAll data will be erased ! \n\nContinue ?" 0 0
	if [ "$?" = "0" ];then
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
	else
	  ${app_name} --msgbox "Disk modification canceled" 0 0
	fi
}

cryptdisk(){
	cryptsetup -q --type luks1 --cipher aes-xts-plain64 --hash sha512 \
	    --use-random --verify-passphrase luksFormat ${install_disk}2
	cryptsetup open ${install_disk}2 archlinux
}

formatdisk(){
	${app_name} --backtitle "title" --title "${select_disk_format} (btrfs)" \
	    --defaultno --yesno "Formating disk: ${install_disk}\n\n
	    ${install_disk}1 fat32\n
	    /dev/mapper/archlinux btrfs\n
	    \n\nContinue ?" 0 0

	if [ "$?" = "0" ];then
	    clear
	    mkfs.vfat -F32 ${install_disk}1
	    mkfs -t btrfs --force -L archlinux /dev/mapper/archlinux
	    mount /dev/mapper/archlinux /mnt
	    btrfs subvolume create /mnt/@
	    btrfs subvolume set-default /mnt/@
	    btrfs subvolume create /mnt/@home
	    btrfs subvolume create /mnt/@cache
	    btrfs subvolume create /mnt/@snapshots
	    umount -R /mnt
	    pressanykey
	else
	    ${app_name} --msgbox "Disk formating canceled" 0 0
	fi
}

mountdisk(){
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

# =============INSTALL===============#
installbase(){
# Install the system, wifi and some tools
  pacstrap /mnt base base-devel btrfs-progs snapper zsh htop \
    net-tools wireless_tools wpa_supplicant dialog vim \
    intel-ucode grub aria2 curl bash-completion

	# Generate fstab
	genfstab -L -p /mnt >> /mnt/etc/fstab
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
  options+=("${select_exit}" "")

  select=`"${app_name}" \
	  --backtitle "title" \
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
  options+=("${select_disk_format}" "")
  options+=("${select_disk_mount}" "")
  options+=("${select_done}" "")

  select=`"${app_name}" \
	  --backtitle "title" \
	  --title "${menu_disk}" \
	  --default-item "${nextitem}" \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`

  if [ "$?" == "0" ];then
    case ${select} in
      "${select_disk_part}")
        partdisk
	nextitem="${select_disk_format}"
      ;;
      "${select_disk_format}")
        formatdisk
	nextitem="${select_disk_mount}"
      ;;
      "${select_disk_mount}")
        mountdisk
	nextitem="${select_done}"
      ;;
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
  options+=("${menu_install}" "")
  options+=("${select_done}" "")

  select=`"${app_name}" \
	  --backtitle "title" \
	  --title "${menu_install}" \
	  --default-item "${nextitem}" \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`

  if [ "$?" == "0" ];then
    case ${select} in
      "${select_install_base}")
        installbase
        nextitem="${select_done}"
      ;;
      "${select_done}")
      mainmenu
      ;;
    esac
    diskmenu "${nextitem}"
  else
    clear
  fi
}


# Start default menu
mainmenu
