curl -sfL https://get.rke2.io | \
  INSTALL_RKE2_VERSION="v1.26.12+rke2r1" \
  INSTALL_RKE2_TYPE="server" \
  sh -

mkdir -p /etc/rancher/rke2/
cat > /etc/rancher/rke2/config.yaml <<EOF
token: ibd-benchmark-cni
cni: none
disable: 
- rke2-ingress-nginx
- rke2-metrics-server
- rke2-snapshot-controller
- rke2-snapshot-controller-crd
- rke2-snapshot-validation-webhook
# disable-cloud-controller: true
# disable-kube-proxy: true
EOF

systemctl enable rke2-server.service
systemctl start rke2-server.service

cat >> /root/.bashrc <<'EOF'
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export CRI_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/crictl.yaml
export CONTAINERD_ADDRESS=unix:///run/k3s/containerd/containerd.sock
export PATH=$PATH:/var/lib/rancher/rke2/bin
alias k=kubectl
EOF
source /root/.bashrc