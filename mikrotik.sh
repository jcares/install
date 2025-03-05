#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info {
  cat <<"EOF"
    __  ____ __              __  _ __      ____              __            ____  _____    ________  ______
   /  |/  (_) /___________  / /_(_) /__   / __ \____  __  __/ /____  _____/ __ \/ ___/   / ____/ / / / __ \
  / /|_/ / / //_/ ___/ __ \/ __/ / //_/  / /_/ / __ \/ / / / __/ _ \/ ___/ / / /\__ \   / /   / /_/ / /_/ /
 / /  / / / ,< / /  / /_/ / /_/ / ,<    / _, _/ /_/ / /_/ / /_/  __/ /  / /_/ /___/ /  / /___/ __  / _, _/
/_/  /_/_/_/|_/_/   \____/\__/_/_/|_|  /_/ |_|\____/\__,_/\__/\___/_/   \____//____/   \____/_/ /_/_/ |_|

EOF
}
clear
header_info
echo -e "Loading..."
GEN_MAC=$(echo '00:60:2f:'$(od -An -N3 -t xC /dev/urandom | sed -e 's/ /:/g' | tr '[:lower:]' '[:upper:]'))
NEXTID=$(pvesh get /cluster/nextid)
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
HA=$(echo "\033[1;34m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
trap cleanup EXIT

function error_exit() {
  trap - ERR
  local reason="Unknown failure occurred."
  local msg="${1:-$reason}"
  local flag="${RD}‼ ERROR ${CL}$EXIT@$LINE"
  echo -e "$flag $msg" 1>&2
  [ ! -z ${VMID-} ] && cleanup_vmid
  exit $EXIT
}

function cleanup_vmid() {
  if $(qm status $VMID &>/dev/null); then
    if [ "$(qm status $VMID | awk '{print $2}')" == "running" ]; then
      qm stop $VMID
    fi
    qm destroy $VMID
  fi
}

function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

if ! pveversion | grep -Eq "pve-manager/8.[1-3]"; then
  echo -e "This version of Proxmox Virtual Environment is not supported"
  echo -e "Requires Proxmox Virtual Environment Version 8.1 or later."
  echo -e "Exiting..."
  sleep 2
  exit
fi

if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "Mikrotik RouterOS CHR VM" --yesno "This will create a New Mikrotik RouterOS CHR VM. Proceed?" 10 58); then
  echo "User selected Yes"
else
  clear
  echo -e "⚠ User exited script \n"
  exit
fi

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function default_settings() {
  echo -e "${DGN}Using Virtual Machine ID: ${BGN}$NEXTID${CL}"
  VMID=$NEXTID
  echo -e "${DGN}Using Hostname: ${BGN}mikrotik-routeros-chr${CL}"
  HN=mikrotik-routeros-chr
  echo -e "${DGN}Allocated Cores: ${BGN}1${CL}"
  CORE_COUNT="2"
  echo -e "${DGN}Allocated RAM: ${BGN}256${CL}"
  RAM_SIZE="512"
  echo -e "${DGN}Using Bridge: ${BGN}vmbr0${CL}"
  BRG="vmbr0"
  echo -e "${DGN}Using MAC Address: ${BGN}$GEN_MAC${CL}"
  MAC=$GEN_MAC
  echo -e "${DGN}Using VLAN: ${BGN}Default${CL}"
  VLAN=""
  echo -e "${DGN}Using Interface MTU Size: ${BGN}Default${CL}"
  MTU=""
  echo -e "${DGN}Start VM when completed: ${BGN}no${CL}"
  START_VM="no"
  echo -e "${BL}Creating a Mikrotik RouterOS CHR VM using the above default settings${CL}"
}

function advanced_settings() {
  # (similar to default_settings but allows user input)
}

function start_script() {
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced 10 58); then
    clear
    header_info
    echo -e "${BL}Using Default Settings${CL}"
    default_settings
  else
    clear
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

start_script
msg_info "Validating Storage"

while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  ITEM="  Type: $TYPE Free: $FREE "
  OFFSET=2
  if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
    MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
  fi
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')

VALID=$(pvesm status -content images | awk 'NR>1')
if [ -z "$VALID" ]; then
  echo -e "\n${RD}⚠ Unable to detect a valid storage location.${CL}"
  echo -e "Exiting..."
  exit
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
  STORAGE=${STORAGE_MENU[0]}
else
  while [ -z "${STORAGE:+x}" ]; do
    STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Storage Pools" --radiolist \
      "Which storage pool would you like to use for the Mikrotik RouterOS CHR VM?\n\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
  done
fi

msg_ok "Using ${CL}${BL}$STORAGE${CL} ${GN}for Storage Location."
msg_ok "Virtual Machine ID is ${CL}${BL}$VMID${CL}."
msg_info "Getting URL for Mikrotik RouterOS CHR Disk Image"

URL=https://download.mikrotik.com/routeros/7.15.3/chr-7.15.3.img.zip

sleep 2
msg_ok "${CL}${BL}${URL}${CL}"
wget -q --show-progress $URL
echo -en "\e[1A\e[0K"
FILE=$(basename $URL)
msg_ok "Downloaded ${CL}${BL}$FILE${CL}"
msg_info "Extracting Mikrotik RouterOS CHR Disk Image"
gunzip -f -S .zip $FILE

STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
case $STORAGE_TYPE in
nfs | dir)
  DISK_EXT=".qcow2"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format qcow2"
  ;;
btrfs | zfspool)
  DISK_EXT=""
  DISK_REF="$VMID/"
  DISK_IMPORT="-format raw"
  ;;
esac

DISK_VAR="vm-${VMID}-disk-0${DISK_EXT:-}"
DISK_REF="${STORAGE}:${DISK_REF:-}${DISK_VAR:-}"

msg_ok "Extracted Mikrotik RouterOS CHR Disk Image"
msg_info "Creating Mikrotik RouterOS CHR VM"

# Crear la máquina virtual con 8 interfaces adicionales
NET_CONFIG=""
for i in $(seq 0 7); do
  MAC_ADDR=$(echo '00:60:2f:'$(od -An -N3 -t xC /dev/urandom | sed -e 's/ /:/g' | tr '[:lower:]' '[:upper:]'))
  NET_CONFIG+="-net$i virtio,bridge=$BRG,macaddr=$MAC_ADDR "
done

# Crear la VM
qm create $VMID -tablet 0 -localtime 1 -cores $CORE_COUNT -memory $RAM_SIZE -name $HN \
  -tags proxmox-helper-scripts \
  -onboot 1 -ostype l26 -scsihw virtio-scsi-pci $NET_CONFIG

qm importdisk $VMID ${FILE%.*} $STORAGE ${DISK_IMPORT:-} 1>&/dev/null
qm set $VMID \
  -scsi0 "$DISK_REF" \
  -boot order=scsi0 \
  -description "<div align='center'><a href='https://Helper-Scripts.com'><img src='https://raw.githubusercontent.com/tteck/Proxmox/main/misc/images/logo-81x112.png'/></a>

  # Mikrotik RouterOS CHR

  <a href='https://ko-fi.com/D1D7EP4GF'><img src='https://img.shields.io/badge/&#x2615;-Buy me a coffee-blue' /></a>
  </div>" >/dev/null

msg_ok "Mikrotik RouterOS CHR VM ${CL}${BL}(${HN})"
if [ "$START_VM" == "yes" ]; then
  msg_info "Starting Mikrotik RouterOS CHR VM"
  qm start $VMID
  msg_ok "Started Mikrotik RouterOS CHR VM"
fi

msg_ok "Completed Successfully!\n"
