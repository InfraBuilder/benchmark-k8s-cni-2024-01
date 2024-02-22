kubectl exec -it cni-benchmark-a2 --  statexec -f dts-server.prom -d 10 -l id=calico-wg -l run=1 -i dts -mst 1704067200000 -s --  iperf3 -s
