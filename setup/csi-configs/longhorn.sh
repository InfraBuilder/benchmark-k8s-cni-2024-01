#!/bin/bash 

# https://longhorn.io/docs/1.6.0/deploy/install/install-with-kubectl/
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/deploy/longhorn.yaml


# https://longhorn.io/docs/1.6.0/advanced-resources/security/volume-encryption/
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: longhorn-crypto
  namespace: longhorn-system
stringData:
  CRYPTO_KEY_VALUE: "ThisIsABenchmarkSoThisIsNotSecureEnough" # "Your encryption passphrase"
  CRYPTO_KEY_PROVIDER: "secret"
  CRYPTO_KEY_CIPHER: "aes-xts-plain64"
  CRYPTO_KEY_HASH: "sha256"
  CRYPTO_KEY_SIZE: "256"
  CRYPTO_PBKDF: "argon2i"
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-crypto-global
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880" # 48 hours in minutes
  fromBackup: ""
  encrypted: "true"
  # global secret that contains the encryption key that will be used for all volumes
  csi.storage.k8s.io/provisioner-secret-name: "longhorn-crypto"
  csi.storage.k8s.io/provisioner-secret-namespace: "longhorn-system"
  csi.storage.k8s.io/node-publish-secret-name: "longhorn-crypto"
  csi.storage.k8s.io/node-publish-secret-namespace: "longhorn-system"
  csi.storage.k8s.io/node-stage-secret-name: "longhorn-crypto"
  csi.storage.k8s.io/node-stage-secret-namespace: "longhorn-system"

---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-crypto-per-volume
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880" # 48 hours in minutes
  fromBackup: ""
  encrypted: "true"
  # per volume secret which utilizes the `pvc.name` and `pvc.namespace` template parameters
  csi.storage.k8s.io/provisioner-secret-name: ${pvc.name}
  csi.storage.k8s.io/provisioner-secret-namespace: ${pvc.namespace}
  csi.storage.k8s.io/node-publish-secret-name: ${pvc.name}
  csi.storage.k8s.io/node-publish-secret-namespace: ${pvc.namespace}
  csi.storage.k8s.io/node-stage-secret-name: ${pvc.name}
  csi.storage.k8s.io/node-stage-secret-namespace: ${pvc.namespace}
EOF
