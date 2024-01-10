# Source : https://antrea.io/docs/v1.14.1/docs/helm/

# helm show values --repo https://charts.antrea.io antrea

helm install antrea --repo https://charts.antrea.io \
    --namespace kube-system \
    --version 1.14.1 \
    antrea
