kubectl exec -it cni-benchmark-a3 --  statexec -f dus-client.prom -d 10 -l id=cilium-hubble-full -l run=3 -i dus -mst 1704067200000 -dbc 11  -c 10.0.0.120 --  iperf3 -c 10.0.0.120 -O 1 -u -b 0 -Z -t 60 --json
