# Source : https://antrea.io/docs/v1.14.1/docs/helm/
# Flavor : ipsec network encryption

# helm show values --repo https://charts.antrea.io antrea

helm install antrea --repo https://charts.antrea.io \
    --namespace kube-system \
    --version 1.14.1 \
    antrea -f - <<EOF

## -- Determines how tunnel traffic is encrypted. Currently encryption only works with encap mode. 
## It must be one of "none", "ipsec", "wireGuard".
trafficEncryptionMode: "ipsec"

EOF
