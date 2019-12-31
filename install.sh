#!/usr/bin/env sh


APP="dialog"
BACKTITLE="TEST Install"


loadtitles(){
  TITLE_SELECT_DISK="Select Disk"
  TITLE_SELECT_EDITOR="Select EDITOR"
  TITLE_MAIN_MENU="Main Menu"
  TITLE_EXIT="Exit"
  TITLE_PRESSANYKEY="Press any key"
}

pressanykey(){
  read -n1 -p "${TITLE_PRESSANYKEY}"
}

mainmenu(){
  if [ "${1}" = "" ];then
    nextitem="."
  else
    nextitem="${1}"
  fi

  options=()
  options+=("${TITLE_SELECT_EDITOR}" "")
  options+=("${TITLE_SELECT_DISK}" "")
  options+=("${TITLE_EXIT}" "")

  select=`"${APP}" \
	  --backtitle "${BACKTITLE}" \
	  --title "${TITLE_MAIN_MENU}" \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`
	  #--cancel-button "${TITLE_EXIT}" \
	  #--default-item "${nextitem}" \
	  #0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`

  if [ "$?" = "0" ];then
    case ${select} in
      "${TITLE_SELECT_EDITOR}")
        selecteditor
	nextitem="${TITLE_SELECT_DISK}"
      ;;
      "${TITLE_SELECT_DISK}")
        selectdisk
	nextitem="${TITLE_EXIT}"
      ;;
      "${TITLE_EXIT}")
        dialog --yesno "Siguran??" 0 0 && clear && exit 0
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
	  --title "${TITLE_SELECT_EDITOR}" \
	  --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3`
  if [ "$?" = "0" ];then
    clear
    echo "Selected editor is ${select}"
    export EDITOR=${select}
    EDITOR=${select}
    pressanykey
  fi
}

selectdisk(){
  items=`lsblk -d -p -n -l -o NAME,SIZE -e 7,11`
  options=()
  IFS_ORIG=$IFS
  IFS=$'\n'
  for item in ${items};do
      options+=("${item}" "")
  done
  IFS=$OFS_ORIG
  
  result=$("${APP}" --backtitle "${BACKTITLE}" --title "${TITLE_SELECT_DISK}" --menu "" 0 0 0 "${options[@]}" 3>&1 1>&2 2>&3)
  if [ "$?" != "0" ];then
    return 1
  fi
  clear
  echo ${result%%\ *}
  pressanykey
  return 0
}



loadtitles
#selecteditor
#selectdisk
mainmenu

