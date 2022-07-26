#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

declare -a COMMON_FILES=(
  './downloads/kubectl'
  'multipass-hosts'
)
declare -a CONTROLLER_FILES=(
  './admin/admin.kubeconfig'
  './kube-controller-manager/kube-controller-manager.kubeconfig'
  './kube-scheduler/kube-scheduler.kubeconfig'
  'encryption/encryption-config.yaml'
  './downloads/kube-apiserver'
  './downloads/kube-controller-manager'
  './downloads/kube-scheduler'
  "./downloads/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"
)
declare -a WORKER_FILES=(
  './kube-proxy/kube-proxy.kubeconfig'
  './downloads/kube-proxy'
  './downloads/kubelet'
  "./downloads/cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz"
  "./downloads/cri-containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
)

multipass list | grep -E -v "Name|\-\-" | awk '{var=sprintf("%s\t%s",$3,$1); print var}' > multipass-hosts

for file in ./*/*.sh; do
  cd "$(dirname ./"${file}")" || exit
  bash "${file##*/}"
  cd - || exit
done

for instance in $(multipass list | grep 'controller' | awk '{ print $1 }'); do
  for file in "${COMMON_FILES[@]}" "${CONTROLLER_FILES[@]}"; do
    transfer_file "${file}" "${instance}"
  done
done

for instance in $(multipass list | grep 'worker' | awk '{ print $1 }'); do
  for file in "./kubelet/${instance}.kubeconfig" "${COMMON_FILES[@]}" "${WORKER_FILES[@]}"; do
    transfer_file "${file}" "${instance}"
  done
done

rm -f multipass-hosts
