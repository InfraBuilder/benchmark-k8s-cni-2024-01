kubectl exec -it cni-benchmark-a2 --  statexec -f idle-server.prom -d 10 -l id=cilium-hubble-full -l run=2 -i idle -mst 1704067200000 -s --  sleep 60
