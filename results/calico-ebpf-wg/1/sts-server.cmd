kubectl exec -it cni-benchmark-a2 --  statexec -f sts-server.prom -d 10 -l id=calico-ebpf-wg -l run=1 -i sts -mst 1704067200000 -s --  iperf3 -s
