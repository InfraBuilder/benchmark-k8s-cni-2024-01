kubectl exec -it cni-benchmark-a3 --  statexec -f idle-client.prom -d 10 -l id=kuberouter-all -l run=3 -i idle -mst 1704067200000 -dbc 11  -c 10.42.1.3 --  sleep 60
