kubectl exec -it cni-benchmark-a3 --  statexec -f dts-client.prom -d 10 -l id=cilium-ipsec -l run=3 -i dts -mst 1704067200000 -dbc 11  -c 10.0.1.95 --  iperf3 -c 10.0.1.95 -O 1 -Z -t 60 --dont-fragment --json
