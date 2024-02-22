kubectl exec -it cni-benchmark-a2 --  statexec -f idle-server.prom -d 10 -l id=calico-wg -l run=3 -i idle -mst 1704067200000 -s --  sleep 60
