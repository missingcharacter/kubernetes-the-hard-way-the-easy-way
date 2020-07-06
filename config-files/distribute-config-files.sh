#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

function transfer_file() {
  local FILE="${1}"
  local INSTANCE=${2}
  multipass transfer -v "${FILE}" ${INSTANCE}:/home/ubuntu/${FILE##*/}
}

for instance in $(multipass list | grep 'worker' | awk '{ print $1 }'); do
  for file in "./kubelet/${instance}.kubeconfig" "./kube-proxy/kube-proxy.kubeconfig"; do
    transfer_file "${file}" "${instance}"
  done
done

for instance in $(multipass list | grep 'master' | awk '{ print $1 }'); do
  for file in './admin/admin.kubeconfig' './kube-controller-manager/kube-controller-manager.kubeconfig' './kube-scheduler/kube-scheduler.kubeconfig' 'encryption/encryption-config.yaml'; do
    transfer_file "${file}" "${instance}"
  done
done
