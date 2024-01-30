# Source : https://docs.cilium.io/en/stable/installation/k8s-install-helm/

# helm show values --repo https://helm.cilium.io/ cilium 

helm install cilium \
    --namespace kube-system \
    --repo https://helm.cilium.io/ \
    --version 1.14.6 \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set hubble.tls.auto.enabled=true \
    --set hubble.tls.auto.method=helm \
    --set hubble.tls.auto.certValidityDuration=1095 \
    cilium 

