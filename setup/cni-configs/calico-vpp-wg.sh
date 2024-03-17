
# Source : https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart#install-calico

echo "Setup calico operator"
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml


# If not, or if you're unsure
curl https://raw.githubusercontent.com/projectcalico/vpp-dataplane/v3.27.0/yaml/generated/calico-vpp-nohuge.yaml \
  | sed -e 's@SERVICE_PREFIX: 10.43.0.0/16@@' \
        -e 's/"interfaceName": "eth1",/"interfaceName": "enp129s0f0",/' \
  | kubectl apply -f -

# IPPool CIDR changed for RKE2 default 10.42.0.0/16
echo "Setup calico custom resource"
kubectl apply -f - <<EOF
# This section includes base Calico installation configuration.
# For more information, see: https://docs.tigera.io/calico/latest/reference/installation/api#operator.tigera.io/v1.Installation
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  registry: quay.io
  # Configures Calico networking.
  calicoNetwork:
    linuxDataplane: VPP

    # Note: The ipPools section cannot be modified post-install.
    ipPools:
    - blockSize: 26
      cidr: 10.42.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
---
# This section configures the Calico API server.
# For more information, see: https://docs.tigera.io/calico/latest/reference/installation/api#operator.tigera.io/v1.APIServer
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF


# Wait for the calico apiserver to be available
while [[ $(kubectl get apiserver default -o 'jsonpath={.status.state}') != "Ready" ]]
do 
  echo "Waiting for calico apiserver to be available" && sleep 5; 
done

# Waiting for API server to be available
kubectl wait --for=condition=Available tigerastatus/apiserver --timeout=300s

# Enable Wireguard
kubectl patch felixconfiguration default --type='merge' -p '{"spec":{"wireguardEnabled":true}}'

# Wait for the three nodes to get wh public key
while [[ $(kubectl get node -o yaml |grep projectcalico.org/WireguardPublicKey|wc -l |awk '{print $1}') != "3" ]]
do 
  echo "Waiting for calico wireguard public key to be available" && sleep 5; 
done