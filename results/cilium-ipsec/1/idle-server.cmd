kubectl exec -it cni-benchmark-a2 --  statexec -f idle-server.prom -d 10 -l id=cilium-ipsec -l run=1 -i idle -mst 1704067200000 -s --  sleep 60
