#!/bin/bash

helm install rook-ceph \
  --repo https://charts.rook.io/release \
  --create-namespace \
  --namespace rook-ceph \
  rook-ceph


helm install rook-ceph-cluster \
  --repo https://charts.rook.io/release \
  --create-namespace \
  --namespace rook-ceph \
  --set toolbox.enabled=true \
  rook-ceph-cluster
