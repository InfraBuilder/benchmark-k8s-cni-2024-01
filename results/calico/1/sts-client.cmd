kubectl exec -it cni-benchmark-a3 --  statexec -f sts-client.prom -d 10 -l id=calico -l run=1 -i sts -mst 1704067200000 -dbc 11  -c 10.42.78.198 --  iperf3 -c cni-benchmark-a2 -O 1 -Z -t 60 --dont-fragment --json
