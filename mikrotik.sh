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
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR

function error_exit() {
  local reason="Unknown failure occurred."
  local msg="${1:-$reason}"
  echo -e "${RD}‼ ERROR ${CL}$EXIT@$LINE: $msg" 1>&2
  exit $EXIT
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

if ! pveversion | grep -Eq "pve-manager/8.[1-3]"; then
  echo -e "This version of Proxmox Virtual Environment is not supported."
  echo -e "Requires Proxmox Virtual Environment Version 8.1 or later."
  exit
fi

if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "Mikrotik RouterOS CHR VM" --yesno "This will create a New Mikrotik RouterOS CHR VM. Proceed?" 10 58); then
  echo "User selected Yes"
else
  clear
  echo -e "⚠ User exited script \n"
  exit
fi

function default_settings() {
  VMID=$NEXTID
  HN="mikrotik-routeros-chr"
  CORE_COUNT="2"
  RAM_SIZE="512"
  BRG="vmbr0"
  START_VM="no"
}

default_settings

msg_info() {
  echo -ne " ${YW}$1..."
}

msg_ok() {
  echo -e "✓ ${GN}$1${CL}"
}

msg_info "Validating Storage"

STORAGE_MENU=()
while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  STORAGE_MENU+=("$TAG" "$TYPE" "$FREE" "OFF")
done < <(pvesm status -content images | awk 'NR>1')

if [ ${#STORAGE_MENU[@]} -eq 0 ]; then
  echo -e "\n${RD}⚠ Unable to detect a valid storage location.${CL}"
  exit
fi

STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Storage Pools" --radiolist \
  "Select storage pool for the VM:" 16 50 6 "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3)

msg_ok "Using $STORAGE for Storage Location."
msg_ok "Virtual Machine ID is $VMID."

URL="https://download.mikrotik.com/routeros/7.15.3/chr-7.15.3.img.zip"
msg_info "Downloading Mikrotik RouterOS CHR Disk Image from $URL"
wget -q --show-progress $URL || error_exit "Failed to download image."

FILE=$(basename $URL)
msg_ok "Downloaded $FILE."
msg_info "Extracting Mikrotik RouterOS CHR Disk Image"
unzip -o $FILE || error_exit "Failed to extract image."

msg_info "Creating Mikrotik RouterOS CHR VM"
NET_CONFIG=""
for i in $(seq 0 7); do
  MAC_ADDR=$(echo '00:60:2f:'$(od -An -N3 -t xC /dev/urandom | sed -e 's/ /:/g' | tr '[:lower:]' '[:upper:]'))
  NET_CONFIG+="-net$i virtio,bridge=$BRG,macaddr=$MAC_ADDR "
done

qm create $VMID -name $HN -cores $CORE_COUNT -memory $RAM_SIZE -onboot 1 -ostype l26 -scsihw virtio-scsi-pci $NET_CONFIG

qm importdisk $VMID ${FILE%.*} $STORAGE -format qcow2
qm set $VMID -scsi0 "$STORAGE:vm-$VMID-disk-0" -boot order=scsi0

msg_ok "Mikrotik RouterOS CHR VM ($HN) created successfully."

if [ "$START_VM" == "yes" ]; then
  msg_info "Starting Mikrotik RouterOS CHR VM"
  qm start $VMID
  msg_ok "Started Mikrotik RouterOS CHR VM."
fi

popd >/dev/null
rm -rf $TEMP_DIR
