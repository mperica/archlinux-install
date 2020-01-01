#!/usr/bin/env sh


APP="dialog"
BACKTITLE="TEST Install"


SELECT_DISK="Select Disk"
SELECT_DISKPART="Create Partitions"
SELECT_DISKFORMAT="Format Partitions"
SELECT_DISKMOUNT="Mount Disk"
SELECT_EDITOR="Select Editor"
SELECT_MAIN_MENU="Main Menu"
SELECT_DISK_MENU="Disk Management"
SELECT_EXIT="Exit"
SELECT_DONE="Done"

pressanykey(){
  read -n1 -p "Press any key to continue..."
}

mainmenu(){
  if [ "${1}" == "" ];then
    nextitem="."
  else
    nextitem="${1}"
  fi

  options=()
  options+=("${SELECT_EDITOR}" "")
  options+=("${SELECT_DISK_MENU}" "")
  options+=("${SELECT_EXIT}" "")

  select=`"${APP}" \
	  --backtitle "${BACKTITLE}" \
	  --title "${SELECT_MAIN_MENU}" \
	  --default-item "${nextitem}" \
		--no-cancel \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`

  if [ "$?" == "0" ];then
    case ${select} in
      "${SELECT_EDITOR}")
        selecteditor
				nextitem="${SELECT_DISK_MENU}"
      ;;
      "${SELECT_DISK_MENU}")
        diskmenu
				nextitem="${SELECT_EXIT}"
      ;;
      "${SELECT_EXIT}")
        ${APP} --defaultno --yesno "Are you sure you whant to exit?" 0 0 && clear && exit 0
      ;;
    esac
    mainmenu "${nextitem}"
  else
    clear
  fi
}

pressanykey(){
  read -n1 -p "Press any key to continue..."
}

selecteditor(){
  options=()
  options+=("vim" "")
  options+=("nano" "")

  select=`"${APP}" \
	  --backtitle "${BACKTITLE}" \
	  --title "${SELECT_EDITOR}" \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`
  if [ "$?" = "0" ];then
    echo "Selected editor is ${select}"
    export EDITOR=${select}
    EDITOR=${select}
    ${APP} --msgbox "Selected Editor is ${select}" 5 30
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

  result=`"${APP}" --backtitle "${BACKTITLE}" --title "${SELECT_DISK}" --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`
  if [ "$?" != "0" ];then
    return 1
  fi
  #clear
	#dialog --msgbox "Selected Disk is \n${result}" 10 20
	echo ${result}
	export INSTALL_DISK=""${result}
  return 0
}

partdisk(){
	#INSTALL_DISK=$(selectdisk)
	${APP} --backtitle "${BACKTITLE}" --title "${SELECT_DISKPART} (gpt)" \
			--defaultno --yesno "Selected device : ${INSTALL_DISK}\n\nAll data will be erased ! \n\nContinue ?" 0 0
	if [ "$?" = "0" ];then
		clear
		echo "Creating a new gpt table on ${INSTALL_DISK}"
	  parted -s ${INSTALL_DISK} mklabel gpt
		echo "Creating boot EFI partition on ${INSTALL_DISK}"
		sgdisk ${INSTALL_DISK} -n=1:0:+512M -t=1:ef02
	  SWAP=$(cat /proc/meminfo | grep MemTotal | awk '{ print $2 }')
	  SWAP=$((${swapsize}/1000))"M"
		echo "Creating swap partition on ${INSTALL_DISK} with size of ${SWAP}"
		sgdisk ${INSTALL_DISK} -n=2:0:+${SWAP} -t=3:8200
		echo "Creating root partition on ${INSTALL_DISK}"
		sgdisk ${INSTALL_DISK} -n=3:0:0
		pressanykey
		echo "CRYPT SETUP"
		cryptdisk
	else
		${APP} --msgbox "Disk modification canceled" 0 0
	fi
}

cryptdisk(){
	# Create luks container (luks1 for compatibility with grub)
	cryptsetup --type luks1 --cipher aes-xts-plain64 --hash sha512 \
	           --use-random --verify-passphrase luksFormat ${INSTALL_DISK}3
	# Create btrfs filesystem
	cryptsetup open ${INSTALL_DISK}3 archlinux
	mkfs -t btrfs --force -L archlinux /dev/mapper/archlinux
}

formatdisk(){
	${APP} --backtitle "${BACKTITLE}" --title "${SELECT_DISKFORMAT} (btrfs)" \
		--defaultno --yesno "Formating disk: ${INSTALL_DISK}\n\n
		${INSTALL_DISK}1 fat32\n
		${INSTALL_DISK}2 swap\n
		${INSTALL_DISK}3 btrfs\n
		\n\nContinue ?" 0 0
	if [ "$?" = "0" ];then
		clear
		mkfs.btrfs -f ${INSTALL_DISK}3
		mount ${INSTALL_DISK}3 /mnt
		btrfs subvolume create /mnt/@
		btrfs subvolume set-default /mnt/@
		btrfs subvolume create /mnt/@home
		btrfs subvolume create /mnt/@cache
		btrfs subvolume create /mnt/@snapshots
		umount -R /mnt
	else
		${APP} --msgbox "Disk formating canceled" 0 0
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
}


# MENUS
diskmenu(){
  if [ "${1}" == "" ];then
    nextitem="."
  else
    nextitem="${1}"
  fi

  options=()
  options+=("${SELECT_DISK}" "")
  options+=("${SELECT_DISKPART}" "")
  options+=("${SELECT_DISKFORMAT}" "")
  options+=("${SELECT_DISKMOUNT}" "")
  options+=("${SELECT_DONE}" "")

  select=`"${APP}" \
	  --backtitle "${BACKTITLE}" \
	  --title "${SELECT_DISK_MENU}" \
	  --default-item "${nextitem}" \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`

  if [ "$?" == "0" ];then
    case ${select} in
      "${SELECT_DISK}")
        selectdisk
				nextitem="${SELECT_DISKPARTT}"
      ;;
      "${SELECT_DISKPART}")
        partdisk
				nextitem="${SELECT_FORMAT}"
      ;;
      "${SELECT_DISKFORMAT}")
        formatdisk
				nextitem="${SELECT_DISKMOUNT}"
      ;;
      "${SELECT_DISKMOUNT}")
        mountdisk
				nextitem="${SELECT_MAIN_MENU}"
      ;;
      "${SELECT_DONE}")
				mainmenu
      ;;
    esac
    diskmenu "${nextitem}"
  else
    clear
  fi
}

mainmenu

