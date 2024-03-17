# Source : https://docs.cilium.io/en/stable/installation/k8s-install-helm/

# helm show values --repo https://helm.cilium.io/ cilium 

helm install cilium \
    --namespace kube-system \
    --repo https://helm.cilium.io/ \
    --version 1.15.2 \
    cilium 
