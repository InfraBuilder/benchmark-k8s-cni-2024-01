kubectl exec -it cni-benchmark-a2 --  statexec -f dts-server.prom -d 10 -l id=calico-vpp -l run=3 -i dts -mst 1704067200000 -s --  iperf3 -s
