kubectl exec -it cni-benchmark-a2 --  statexec -f sus-server.prom -d 10 -l id=flannel -l run=2 -i sus -mst 1704067200000 -s --  iperf3 -s
