kubectl exec -it cni-benchmark-a2 --  statexec -f sum-server.prom -d 10 -l id=canal -l run=2 -i sum -mst 1704067200000 -s --  iperf3 -s
