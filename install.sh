#!/usr/bin/env sh


APP="dialog"
BACKTITLE="TEST Install"


SELECT_DISK="Select Disk"
SELECT_DISKPART="Partitions"
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
        ${APP} --yesno "Are you sure you whant to exit?" 0 0 && clear && exit 0
      ;;
    esac
    mainmenu "${nextitem}"
  else
    clear
  fi
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
  return 0
}

partdisk(){
	disk=$(selectdisk)

	if [ "$?" = "0" ];then
  	${APP} --backtitle "${BACKTITLE}" --title "${SELECT_DISKPART} (gpt)" \
			--defaultno --yesno "Selected device : ${disk}\n\nAll data will be erased ! \n\nContinue ?" 0 0

		${APP} --infobox "Creating new gpt table $(parted ${disk} mklabel gpt)" 0 0
		${APP} --infobox "Creating boot partition EFI $(sgdisk ${device} -n=1:0:+512M -t=1:ef02)" 0 0
    swapsize=$(cat /proc/meminfo | grep MemTotal | awk '{ print $2 }')
    swapsize=$((${swapsize}/1000))"M"
		${APP} --infobox "Creating root partition $(sgdisk ${device} -n=2:0:+${swapsize} -t=3:8200)" 0 0
		${APP} --infobox "Creating root partition $(sgdisk ${device} -n=3:0:0)" 0 0
	fi
}

mountdisk(){
	pass
}


# MENUS
diskmenu(){
  if [ "${1}" == "" ];then
    nextitem="."
  else
    nextitem="${1}"
  fi

  options=()
#  options+=("${SELECT_DISK}" "")
  options+=("${SELECT_DISKPART}" "")
  options+=("${SELECT_DISKMOUNT}" "")
  options+=("${SELECT_DONE}" "")

  select=`"${APP}" \
	  --backtitle "${BACKTITLE}" \
	  --title "${SELECT_DISK_MENU}" \
	  --default-item "${nextitem}" \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`

  if [ "$?" == "0" ];then
    case ${select} in
#      "${SELECT_DISK}")
#        selectdisk
#				nextitem="${SELECT_DISKPARTT}"
#      ;;
      "${SELECT_DISKPART}")
        partdisk
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

