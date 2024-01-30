kubectl exec -it cni-benchmark-a3 --  statexec -f dus-client.prom -d 10 -l id=kubeovn -l run=1 -i dus -mst 1704067200000 -dbc 11  -c 10.16.0.9 --  iperf3 -c 10.16.0.9 -O 1 -u -b 0 -Z -t 60 --json
