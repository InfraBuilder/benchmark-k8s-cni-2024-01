# Source : https://docs.cilium.io/en/stable/installation/k8s-install-helm/

# helm show values --repo https://helm.cilium.io/ cilium 

helm install cilium \
    --namespace kube-system \
    --repo https://helm.cilium.io/ \
    --version 1.14.6 \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost=10.1.1.11 \
    --set k8sServicePort=6443 \
    --set bandwidthManager.enabled=true \
    cilium 
