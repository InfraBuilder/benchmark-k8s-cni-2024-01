FROM ubuntu:22.04
RUN apt-get update && apt-get install wget curl numactl iproute2 -y \
    && cd /root \
    && wget https://github.com/blackswifthosting/statexec/releases/download/0.8.0/statexec-linux-amd64 \
    && mv /root/statexec-linux-amd64 /usr/local/bin/statexec \
    && chmod +x /usr/local/bin/statexec \
    && wget https://github.com/InfraBuilder/iperf-bin/releases/download/iperf3-v3.16/iperf3-3.16-linux-amd64 \
    && mv /root/iperf3-3.16-linux-amd64 /usr/local/bin/iperf3 \
    && chmod +x /usr/local/bin/iperf3 \
    && iperf3 -v \
    && statexec -v \
    && apt-get remove -y wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
