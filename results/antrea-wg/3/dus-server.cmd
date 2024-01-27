kubectl exec -it cni-benchmark-a2 --  statexec -f dus-server.prom -d 10 -l id=antrea-wg -l run=3 -i dus -mst 1704067200000 -s --  iperf3 -s
