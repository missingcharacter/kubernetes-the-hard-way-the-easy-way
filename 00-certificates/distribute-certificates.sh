#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

function transfer_file() {
  local FILE="${1}"
  local INSTANCE=${2}
  multipass transfer -v "${FILE}" ${INSTANCE}:/home/ubuntu/${FILE##*/}
}

for file in $(ls */*.sh); do
  cd "$(dirname ./${file})"
  bash ${file##*/}
  cd -
done

for instance in $(multipass list | grep 'worker' | awk '{ print $1 }'); do
  for file in './00-Certificate-Authority/ca.pem' "./02-kubelet-client/${instance}-key.pem" "./02-kubelet-client/${instance}.pem"; do
    transfer_file "${file}" "${instance}"
  done
done

for instance in $(multipass list | grep 'controller' | awk '{ print $1 }'); do
  for file in './00-Certificate-Authority/ca.pem' './00-Certificate-Authority/ca-key.pem' './06-kubernetes-api/kubernetes-key.pem' './06-kubernetes-api/kubernetes.pem' './07-service-account/service-account-key.pem' './07-service-account/service-account.pem'; do
    transfer_file "${file}" "${instance}"
  done
done
