#!/bin/bash

[ "$1" = "" ] && echo "Usage: $0 user@host" && exit 1

CURDIR=$(dirname $0)
[ "$CURDIR" = "." ] && CURDIR=$(pwd)

SSH_HOST=$1
QSSH="ssh -A -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

function wait_for_ssh {
    echo -n "Waiting for SSH and cloud-init to finish"
    while ! $QSSH -o ConnectTimeout=1 ${SSH_HOST} sudo ls /var/lib/cloud/instance/boot-finished > /dev/null 2>&1; do
        echo -n "."
        sleep 1
    done
    echo ""
}

wait_for_ssh

echo "Prepare NICs"
cat <<'EOF' | $QSSH ${SSH_HOST} sudo bash

IFIP=$(ip a show enp129s0f0 |grep "inet " |awk '{print $2}')

cat <<EOT > /etc/netplan/50-cloud-init.yaml
network:
  version: 2
  ethernets:
    enp129s0f0:
      dhcp4: false
      mtu: 9000
      addresses:
      - $IFIP
      gateway4: 10.1.1.1
      routes:
      - to: 0.0.0.0/0
        via: 10.1.1.1
      nameservers:
        addresses:
        - 10.1.1.1
EOT

# Zapping second disk for CSI testing
sgdisk -Z /dev/nvme1n1

mkfs.ext4 /dev/sda
mkdir /satadom
mount /dev/sda /satadom/

reboot
EOF

sleep 10

wait_for_ssh
