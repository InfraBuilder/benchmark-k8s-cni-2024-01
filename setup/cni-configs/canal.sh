# Source : https://docs.tigera.io/calico/latest/getting-started/kubernetes/flannel/install-for-flannel#installing-with-the-kubernetes-api-datastore-recommended

curl -sL https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/canal.yaml \
    | sed 's:10.244.0.0/16:10.42.0.0/16:' \
    | kubectl apply -f -
