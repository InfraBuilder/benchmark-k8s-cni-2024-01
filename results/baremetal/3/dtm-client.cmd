./maas.sh ssh a3 statexec -f dtm-client.prom -d 10 -l id=baremetal -l run=3 -i dtm -mst 1704067200000 -dbc 11  -c 10.1.1.12 --  iperf3 -c 10.1.1.12 -O 1 -P 8 -Z -t 60 --dont-fragment --json
