# Source : https://antrea.io/docs/v1.15.0/docs/helm/

# helm show values --repo https://charts.antrea.io antrea

helm install antrea --repo https://charts.antrea.io \
    --namespace kube-system \
    --version 1.15.0 \
    antrea
