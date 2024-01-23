# See https://fasterdata.es.net/host-tuning/linux/100g-tuning/

#========================================================================
#    ____ ____  _   _   _____            _             
#   / ___|  _ \| | | | |_   _|   _ _ __ (_)_ __   __ _ 
#  | |   | |_) | | | |   | || | | | '_ \| | '_ \ / _` |
#  | |___|  __/| |_| |   | || |_| | | | | | | | | (_| |
#   \____|_|    \___/    |_| \__,_|_| |_|_|_| |_|\__, |
#                                                |___/ 
#========================================================================

apt install linux-tools-common linux-tools-generic -y

# Disable CPU frequency scaling
cpupower frequency-set -g performance
# Check : watch -n 1 grep MHz /proc/cpuinfo

# Disable Hyperthreading
echo off > /sys/devices/system/cpu/smt/control
# Check: cat /sys/devices/system/cpu/smt/control

#========================================================================
#   ____                 _   _   _               _             
#  / ___| _   _ ___  ___| |_| | | |_ _   _ _ __ (_)_ __   __ _ 
#  \___ \| | | / __|/ __| __| | | __| | | | '_ \| | '_ \ / _` |
#   ___) | |_| \__ \ (__| |_| | | |_| |_| | | | | | | | | (_| |
#  |____/ \__, |___/\___|\__|_|  \__|\__,_|_| |_|_|_| |_|\__, |
#         |___/                                          |___/ 
#========================================================================

cat > /etc/sysctl.d/99-benchmark-sysctl.conf <<EOF

#==============================================================================
# Tuning for benchmarking with 40Gbps network
#==============================================================================
# See https://fasterdata.es.net/host-tuning/linux/test-measurement-host-tuning/

# increase TCP max buffer size setable using setsockopt() to 512MB
net.core.rmem_max = 536870912 
net.core.wmem_max = 536870912 

# increase Linux autotuning TCP buffer limit to 256MB
# min, default, and max number of bytes to use
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456
#==============================================================================

#==============================================================================
# Tuning for benchmarking with 100Gbps network
# # Allow buffers up to 2GB
# net.core.rmem_max=2147483647 
# net.core.wmem_max=2147483647
# # increase Linux autotuning TCP buffer limit to 1GB
# net.ipv4.tcp_rmem=4096 65536 1073741824
# net.ipv4.tcp_wmem=4096 65536 1073741824
#==============================================================================

# don't cache ssthresh from previous connection
net.ipv4.tcp_no_metrics_save = 1

# If you are using Jumbo Frames, also set this
net.ipv4.tcp_mtu_probing = 1

# recommended to enable 'fair queueing' (fq or fq_codel)
net.core.default_qdisc = fq

EOF


#========================================================================
#   ___ ____   ___    _____            _             
#  |_ _|  _ \ / _ \  |_   _|   _ _ __ (_)_ __   __ _ 
#   | || |_) | | | |   | || | | | '_ \| | '_ \ / _` |
#   | ||  _ <| |_| |   | || |_| | | | | | | | | (_| |
#  |___|_| \_\\__\_\   |_| \__,_|_| |_|_|_| |_|\__, |
#                                              |___/ 
#========================================================================

apt autoremove irqbalance -y

# CPU Affinity for NIC IRQs
cd
# https://www.intel.com/content/www/us/en/download/18026/intel-network-adapter-driver-for-pcie-40-gigabit-ethernet-network-connections-under-linux.html
wget https://downloadmirror.intel.com/812528/i40e-2.24.6.tar.gz
tar -xvf i40e-2.24.6.tar.gz
cd i40e-2.24.6/scripts
# Bind benchmark interface enp129s0f0 with i40e driver to 
# CPU 8-15 on same NUMA node as the NIC interface
./set_irq_affinity 8-15 enp129s0f0