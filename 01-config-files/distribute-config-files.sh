#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

multipass list | grep -E -v "Name|\-\-" | awk '{var=sprintf("%s\t%s",$3,$1); print var}' > multipass-hosts

for file in ./*/*.sh; do
  cd "$(dirname ./"${file}")" || exit
  bash "${file##*/}"
  cd - || exit
done

for instance in $(multipass list | grep 'worker' | awk '{ print $1 }'); do
  for file in "./kubelet/${instance}.kubeconfig" "./kube-proxy/kube-proxy.kubeconfig" 'multipass-hosts'; do
    transfer_file "${file}" "${instance}"
  done
done

for instance in $(multipass list | grep 'controller' | awk '{ print $1 }'); do
  for file in './admin/admin.kubeconfig' './kube-controller-manager/kube-controller-manager.kubeconfig' './kube-scheduler/kube-scheduler.kubeconfig' 'encryption/encryption-config.yaml' 'multipass-hosts'; do
    transfer_file "${file}" "${instance}"
  done
done

rm -f multipass-hosts
