kubectl exec -it cni-benchmark-a3 --  statexec -f sts-client.prom -d 10 -l id=cilium -l run=3 -i sts -mst 1704067200000 -dbc 11  -c 10.0.1.154 --  iperf3 -c cni-benchmark-a2 -O 1 -Z -t 60 --dont-fragment --json
