kubectl exec -it cni-benchmark-a2 --  statexec -f dtm-server.prom -d 10 -l id=calico-vpp-ipsec -l run=3 -i dtm -mst 1704067200000 -s --  iperf3 -s
