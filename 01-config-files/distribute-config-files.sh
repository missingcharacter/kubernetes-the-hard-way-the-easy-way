#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

function transfer_file() {
  local FILE="${1}"
  local INSTANCE=${2}
  multipass transfer -v "${FILE}" ${INSTANCE}:/home/ubuntu/${FILE##*/}
}

multipass list | egrep -v "Name|\-\-" | awk '{var=sprintf("%s\t%s",$3,$1); print var}' > multipass-hosts

for file in $(ls */*.sh); do
  cd "$(dirname ./${file})"
  bash ${file##*/}
  cd -
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
