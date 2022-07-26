#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo 'Adding cilium and coredns helm repos'

helm repo add coredns https://coredns.github.io/helm
helm repo add cilium https://helm.cilium.io/

echo 'Updating helm repos'

helm repo update

echo 'Installing coredns'

helm install coredns coredns/coredns --version "${COREDNS_CHART_VERSION}" \
    --namespace kube-system \
    --set "service.clusterIP=${DNS_CLUSTER_IP}"

echo 'Installing cilium'

helm install cilium cilium/cilium --version "${CILIUM_CHART_VERSION}" \
    --namespace kube-system \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true
