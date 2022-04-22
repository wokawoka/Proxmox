#!/usr/bin/env bash -ex
set -euo pipefail
shopt -s inherit_errexit nullglob
YW=`echo "\033[33m"`
RD=`echo "\033[01;31m"`
BL=`echo "\033[36m"`
GN=`echo "\033[1;92m"`
CL=`echo "\033[m"`
RETRY_NUM=10
RETRY_EVERY=3
NUM=$RETRY_NUM
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
BFR="\\r\\033[K"
HOLD="-"

function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_info "Setting up Container OS "
sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
locale-gen >/dev/null
while [ "$(hostname -I)" = "" ]; do
  1>&2 echo -en "${CROSS}${RD}  No Network! "
  sleep $RETRY_EVERY
  ((NUM--))
  if [ $NUM -eq 0 ]
  then
    1>&2 echo -e "${CROSS}${RD}  No Network After $RETRY_NUM Tries${CL}"    
    exit 1
  fi
done
msg_ok "Set up Container OS"
msg_ok "Network Connected: ${BL}$(hostname -I)"

msg_info "Updating Container OS"
apt update &>/dev/null
apt-get -qqy upgrade &>/dev/null
msg_ok "Updated Container OS"

msg_info "Installing Dependencies"
apt-get -y install curl &>/dev/null
apt-get -y install sudo &>/dev/null
apt-get -y install gnupg &>/dev/null
apt-get -y install openjdk-8-jre-headless &>/dev/null
apt-get -y install jsvc &>/dev/null

wget -qO - https://www.mongodb.org/static/pgp/server-3.4.asc | sudo apt-key add &>/dev/null
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list &>/dev/null
apt-get update &>/dev/null
apt-get -y install mongodb-org &>/dev/null
msg_ok "Installed Dependencies"

msg_info "Installing Omada Controller"
wget -qL https://static.tp-link.com/upload/software/2022/202203/20220322/Omada_SDN_Controller_v5.1.7_Linux_x64.deb
sudo dpkg -i Omada_SDN_Controller_v5.1.7_Linux_x64.deb &>/dev/null
#wget -qL https://static.tp-link.com/upload/software/2022/202201/20220120/Omada_SDN_Controller_v5.0.30_linux_x64.deb
#sudo dpkg -i Omada_SDN_Controller_v5.0.30_linux_x64.deb &>/dev/null
msg_ok "Installed Omada Controller"

PASS=$(grep -w "root" /etc/shadow | cut -b6);
  if [[ $PASS != $ ]]; then
msg_info "Customizing Container"
chmod -x /etc/update-motd.d/*
touch ~/.hushlogin
GETTY_OVERRIDE="/etc/systemd/system/container-getty@1.service.d/override.conf"
mkdir -p $(dirname $GETTY_OVERRIDE)
cat << EOF > $GETTY_OVERRIDE
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%I 115200,38400,9600 \$TERM
EOF
systemctl daemon-reload
systemctl restart $(basename $(dirname $GETTY_OVERRIDE) | sed 's/\.d//')
msg_ok "Customized Container"
  fi
  
msg_info "Cleaning up"
apt-get autoremove >/dev/null
apt-get autoclean >/dev/null
rm -rf /var/{cache,log}/* /var/lib/apt/lists/*
msg_ok "Cleaned"
