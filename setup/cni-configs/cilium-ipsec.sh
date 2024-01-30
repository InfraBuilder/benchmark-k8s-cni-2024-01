# Source : https://docs.cilium.io/en/stable/installation/k8s-install-helm/

# helm show values --repo https://helm.cilium.io/ cilium 
# IPSec: https://docs.cilium.io/en/latest/security/network/encryption-ipsec/

kubectl create -n kube-system secret generic cilium-ipsec-keys \
    --from-literal=keys="3 rfc4106(gcm(aes)) $(echo $(dd if=/dev/urandom count=20 bs=1 2> /dev/null | xxd -p -c 64)) 128"

helm install cilium \
    --namespace kube-system \
    --repo https://helm.cilium.io/ \
    --version 1.14.6 \
    --set encryption.enabled=true \
    --set encryption.type=ipsec \
    cilium 


# --set encryption.ipsec.interface=ethX

# Key rotations: https://docs.cilium.io/en/latest/security/network/encryption-ipsec/#key-rotation