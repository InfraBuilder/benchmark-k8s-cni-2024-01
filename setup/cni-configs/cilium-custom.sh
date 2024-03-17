# Source : https://docs.cilium.io/en/stable/installation/k8s-install-helm/

# helm show values --repo https://helm.cilium.io/ cilium 

helm install cilium \
    --namespace kube-system \
    --repo https://helm.cilium.io/ \
    --version 1.15.2 \
    cilium \
    --set hubble.enabled=false \
    --set bpf.masquerade=true \
    --set ipv4.enabled=true \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost=10.1.1.11 \
    --set k8sServicePort=6443

# Original custom demand
# helm install cilium \
#     --namespace kube-system \
#     --repo https://helm.cilium.io/ \
#     --version 1.14.5 \
#     cilium \
#     --set hubble.enabled=false \
#     --set routingMode=native \
#     --set bpf.masquerade=true \
#     --set ipv4.enabled=true \
#     --set ipv4NativeRoutingCIDR=X.X.X.X/Y \
#     --set kubeProxyReplacement=true \
#     --set k8sServiceHost=REPLACE_WITH_API_SERVER_IP \
#     --set k8sServicePort=REPLACE_WITH_API_SERVER_PORT
