# Source: https://github.com/flannel-io/flannel?tab=readme-ov-file#deploying-flannel-with-kubectl


CNITGZ="https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz"

# # For each node, create a pod that will install the CNI plugins in /opt/cni/bin
for s in a1 a2 a3
do 
  echo "Installing CNI plugins on $s"

  # Create pod
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cni-install-$s
  namespace: kube-system
spec:
  hostNetwork: true
  nodeName: $s
  initContainers:
  - name: cni-install
    image: alpine/curl
    imagePullPolicy: IfNotPresent
    command: ["/bin/sh"]
    args: ["-c", "apk add --no-cache curl && curl -L $CNITGZ | tar -C /opt/cni/bin -xzvf -"]
    tty: true
    volumeMounts:
    - name: cni-bin-dir
      mountPath: /opt/cni/bin
  containers:
  - name: sleeper
    image: alpine/curl
    imagePullPolicy: IfNotPresent
    command: ["/bin/sh"]
    args: ["-c", "sleep 3600"]
  tolerations:
  - operator: Exists
  volumes:
  - name: cni-bin-dir
    hostPath:
      path: /opt/cni/bin
EOF
done

sleep 10

kubectl create ns kube-flannel
kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged

helm install flannel \
  --repo https://flannel-io.github.io/flannel/ \
  --version v0.24.2 \
  --set podCidr="10.42.0.0/16" \
  --namespace kube-flannel \
  flannel
