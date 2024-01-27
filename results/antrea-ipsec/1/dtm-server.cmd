kubectl exec -it cni-benchmark-a2 --  statexec -f dtm-server.prom -d 10 -l id=antrea-ipsec -l run=1 -i dtm -mst 1704067200000 -s --  iperf3 -s
