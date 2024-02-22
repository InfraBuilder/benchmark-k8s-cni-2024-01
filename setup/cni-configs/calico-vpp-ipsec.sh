
# Source : https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart#install-calico

echo "Setup calico operator"
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml


# If not, or if you're unsure
curl https://raw.githubusercontent.com/projectcalico/vpp-dataplane/v3.27.0/yaml/generated/calico-vpp-nohuge.yaml \
  | sed -e 's@SERVICE_PREFIX: 10.43.0.0/16@@' \
        -e 's/"interfaceName": "eth1",/"interfaceName": "enp129s0f0",/' \
  | kubectl apply -f -

# Enable IPsec on VPP
# cf https://docs.tigera.io/calico/latest/getting-started/kubernetes/vpp/ipsec

kubectl -n calico-vpp-dataplane create secret generic calicovpp-ipsec-secret \
   --from-literal=psk="$(dd if=/dev/urandom bs=1 count=36 2>/dev/null | base64)"

kubectl -n calico-vpp-dataplane patch configmap calico-vpp-config --patch "data:
  CALICOVPP_FEATURE_GATES: |-
    {
      \"ipsecEnabled\": true
    }
"

kubectl -n calico-vpp-dataplane patch daemonset calico-vpp-node --patch "spec:
  template:
    spec:
      containers:
        - name: agent
          env:
            - name: CALICOVPP_IPSEC_IKEV2_PSK
              valueFrom:
                secretKeyRef:
                  name: calicovpp-ipsec-secret
                  key: psk
"

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

