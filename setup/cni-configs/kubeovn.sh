# Source : https://kubeovn.github.io/docs/stable/en/start/one-step-install/

# helm show values --repo https://kubeovn.github.io/kube-ovn/ kube-ovn

[ "${A1IP}" = "" ] && echo "A1IP env var is not set" && exit 1

kubectl label node a1 kube-ovn/role=master --overwrite
kubectl label node -lbeta.kubernetes.io/os=linux kubernetes.io/os=linux --overwrite

# # The following labels are used for the installation of dpdk images and can be ignored in non-dpdk cases
# kubectl label node -lovn.kubernetes.io/ovs_dp_type!=userspace ovn.kubernetes.io/ovs_dp_type=kernel --overwrite

helm install kube-ovn \
    --namespace kube-ovn-system --create-namespace \
    --repo https://kubeovn.github.io/kube-ovn/ \
    --version v1.12.8 \
    kube-ovn \
    --set MASTER_NODES=${A1IP}
