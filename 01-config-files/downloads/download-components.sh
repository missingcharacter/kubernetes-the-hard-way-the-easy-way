#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

# Download kubernetes components once then distribute them to controller(s) and
# agents
msg_info 'Downloading kubernetes components'
curl -fSL --remote-name-all --ssl-reqd \
  "https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kube-apiserver" \
  "https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kube-controller-manager" \
  "https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kube-scheduler" \
  "https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl" \
  "https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz" \
  "https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz" \
  "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz" \
  "https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kube-proxy" \
  "https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubelet"
