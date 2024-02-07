NOKUBEPROXYCONFIG=""

if [ "$NOKUBEPROXY" = "true" ]
then
  NOKUBEPROXYCONFIG="disable-kube-proxy: true"
fi

curl -sfL https://get.rke2.io | \
  INSTALL_RKE2_VERSION="v1.26.12+rke2r1" \
  INSTALL_RKE2_TYPE="agent" \
  sh -

mkdir -p /etc/rancher/rke2/
cat > /etc/rancher/rke2/config.yaml <<EOF
server: https://{{CONTROLPLANE_IP}}:9345
token: ibd-benchmark-cni
cni: none
disable: 
- rke2-ingress-nginx
- rke2-metrics-server
- rke2-snapshot-controller
- rke2-snapshot-controller-crd
- rke2-snapshot-validation-webhook
$NOKUBEPROXYCONFIG
EOF

systemctl enable rke2-agent.service
systemctl start rke2-agent.service