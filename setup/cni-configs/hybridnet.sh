# Source : https://github.com/alibaba/hybridnet/wiki/Getting-Started

# helm show values --repo https://alibaba.github.io/hybridnet/ hybridnet

# Default behavior of hybridnet is to use nodeselector node-role.kubernetes.io/master: ""
# on RKE2, master nodes have label node-role.kubernetes.io/master: "true"
# so we need to change the nodeselector to hybridnet-manager: "enabled"

kubectl label node a1 hybridnet-manager=enabled
kubectl label node a2 hybridnet-manager=enabled
kubectl label node a3 hybridnet-manager=enabled

helm install hybridnet --repo https://alibaba.github.io/hybridnet/ \
    --namespace kube-system \
    --version 0.6.8 \
    hybridnet -f - <<EOF
manager:
  nodeSelector:
    hybridnet-manager: "enabled"
webhook:
  nodeSelector:
    hybridnet-manager: "enabled"
EOF