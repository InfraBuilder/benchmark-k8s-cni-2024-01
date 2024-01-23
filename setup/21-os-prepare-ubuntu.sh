#!/bin/bash

apt update
apt install -y wireguard    

swapoff -a
sed -i '/\sswap\s/d' /etc/fstab

cd $HOME

# Install blackswifthosting/statexec
wget https://github.com/blackswifthosting/statexec/releases/download/0.8.0/statexec-linux-amd64
chmod +x statexec-linux-amd64
mv statexec-linux-amd64 /usr/local/bin/statexec

# Install nuttcp
wget https://nuttcp.net/nuttcp/nuttcp-8.1.4/bin/nuttcp-8.1.4.x86_64
chmod +x nuttcp-8.1.4.x86_64
mv nuttcp-8.1.4.x86_64 /usr/local/bin/nuttcp
cd 

# Install iperf3
wget https://github.com/InfraBuilder/iperf-bin/releases/download/iperf3-v3.16/iperf3-3.16-linux-amd64
chmod +x iperf3-3.16-linux-amd64
mv iperf3-3.16-linux-amd64 /usr/local/bin/iperf3
