# Source : https://github.com/cloudnativelabs/kube-router/blob/master/docs/kubeadm.md#kube-router-providing-pod-networking-and-network-policy

#Flag:NOKUBEPROXY

# Original file:
#   https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter-all-features.yaml
# Added to ds args :
# - --service-cluster-ip-range=10.43.0.0/16
# Removed from ds args:
# - --kubeconfig=/var/lib/kube-router/kubeconfig
# Added to env : 
#   KUBERNETES_SERVICE_HOST="10.1.1.11" 
#   KUBERNETES_SERVICE_PORT="6443"
# Removed kueconfig related volumes and mounts

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-router-cfg
  namespace: kube-system
  labels:
    tier: node
    k8s-app: kube-router
data:
  cni-conf.json: |
    {
       "cniVersion":"0.3.0",
       "name":"mynet",
       "plugins":[
          {
             "name":"kubernetes",
             "type":"bridge",
             "bridge":"kube-bridge",
             "isDefaultGateway":true,
             "ipam":{
                "type":"host-local"
             }
          }
       ]
    }
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    k8s-app: kube-router
    tier: node
  name: kube-router
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: kube-router
      tier: node
  template:
    metadata:
      labels:
        k8s-app: kube-router
        tier: node
    spec:
      priorityClassName: system-node-critical
      serviceAccountName: kube-router
      serviceAccount: kube-router
      containers:
      - name: kube-router
        image: docker.io/cloudnativelabs/kube-router
        imagePullPolicy: Always
        args:
        - --run-router=true
        - --run-firewall=true
        - --run-service-proxy=true
        - --bgp-graceful-restart=true
        - --service-cluster-ip-range=10.43.0.0/16 # Added to match RKE2 default service CIDR
        env:
        - name: KUBERNETES_SERVICE_HOST
          value: "10.1.1.11"
        - name: KUBERNETES_SERVICE_PORT
          value: "6443"
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: KUBE_ROUTER_CNI_CONF_FILE
          value: /etc/cni/net.d/10-kuberouter.conflist
        livenessProbe:
          httpGet:
            path: /healthz
            port: 20244
          initialDelaySeconds: 10
          periodSeconds: 3
        resources:
          requests:
            cpu: 250m
            memory: 250Mi
        securityContext:
          privileged: true
        volumeMounts:
        - name: lib-modules
          mountPath: /lib/modules
          readOnly: true
        - name: cni-conf-dir
          mountPath: /etc/cni/net.d
        - name: xtables-lock
          mountPath: /run/xtables.lock
          readOnly: false
      initContainers:
      - name: install-cni
        image: docker.io/cloudnativelabs/kube-router
        imagePullPolicy: Always
        command:
        - /bin/sh
        - -c
        - set -e -x;
          if [ ! -f /etc/cni/net.d/10-kuberouter.conflist ]; then
            if [ -f /etc/cni/net.d/*.conf ]; then
              rm -f /etc/cni/net.d/*.conf;
            fi;
            TMP=/etc/cni/net.d/.tmp-kuberouter-cfg;
            cp /etc/kube-router/cni-conf.json ${TMP};
            mv ${TMP} /etc/cni/net.d/10-kuberouter.conflist;
          fi;
          if [ -x /usr/local/bin/cni-install ]; then
            /usr/local/bin/cni-install;
          fi;
        volumeMounts:
        - name: cni-conf-dir
          mountPath: /etc/cni/net.d
        - name: kube-router-cfg
          mountPath: /etc/kube-router
        - name: host-opt
          mountPath: /opt
      hostNetwork: true
      hostPID: true
      tolerations:
      - effect: NoSchedule
        operator: Exists
      - key: CriticalAddonsOnly
        operator: Exists
      - effect: NoExecute
        operator: Exists
      volumes:
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: cni-conf-dir
        hostPath:
          path: /etc/cni/net.d
      - name: kube-router-cfg
        configMap:
          name: kube-router-cfg
      - name: xtables-lock
        hostPath:
          path: /run/xtables.lock
          type: FileOrCreate
      - name: host-opt
        hostPath:
          path: /opt
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-router
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kube-router
  namespace: kube-system
rules:
  - apiGroups:
    - ""
    resources:
      - namespaces
      - pods
      - services
      - nodes
      - endpoints
    verbs:
      - list
      - get
      - watch
  - apiGroups:
    - "networking.k8s.io"
    resources:
      - networkpolicies
    verbs:
      - list
      - get
      - watch
  - apiGroups:
    - extensions
    resources:
      - networkpolicies
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - "coordination.k8s.io"
    resources:
      - leases
    verbs:
      - get
      - create
      - update
  - apiGroups:
      - ""
    resources:
      - services/status
    verbs:
      - update
  - apiGroups:
      - "discovery.k8s.io"
    resources:
      - endpointslices
    verbs:
      - get
      - list
      - watch

---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kube-router
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-router
subjects:
- kind: ServiceAccount
  name: kube-router
  namespace: kube-system
EOF


# k get no -s https://10.1.1.11:6443 --certificate-authority /run/secrets/kubernetes.io/serviceaccount/ca.crt --token $(cat /run/secrets/kubernetes.io/serviceaccount/token)

