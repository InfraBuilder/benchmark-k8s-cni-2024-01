FROM ubuntu:22.04 as downloader
RUN apt-get update && apt-get install -y wget \
    && cd /root \
    && wget https://github.com/blackswifthosting/statexec/releases/download/0.8.0/statexec-linux-amd64 \
    && wget https://github.com/InfraBuilder/iperf-bin/releases/download/iperf3-v3.16/iperf3-3.16-linux-amd64


FROM ubuntu:22.04
COPY --from=downloader /root/* /usr/local/bin/
RUN mv /usr/local/bin/statexec-linux-amd64 /usr/local/bin/statexec \
    && mv /usr/local/bin/iperf3-3.16-linux-amd64 /usr/local/bin/iperf3 \
    && chmod +x /usr/local/bin/statexec \
    && chmod +x /usr/local/bin/iperf3 \
    && iperf3 -v \
    && statexec -v
