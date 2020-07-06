#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

function transfer_file() {
  local FILE="${1}"
  local INSTANCE=${2}
  multipass transfer -v "${FILE}" ${INSTANCE}:/home/ubuntu/${FILE##*/}
}

for instance in $(multipass list | grep 'worker' | awk '{ print $1 }'); do
  for file in './CA/ca.pem' "./kubelet-client/${instance}-key.pem" "./kubelet-client/${instance}.pem"; do
    transfer_file "${file}" "${instance}"
  done
done

for instance in $(multipass list | grep 'master' | awk '{ print $1 }'); do
  for file in './CA/ca.pem' './CA/ca-key.pem' './kubernetes-api/kubernetes-key.pem' './kubernetes-api/kubernetes.pem' './service-account/service-account-key.pem' './service-account/service-account.pem'; do
    transfer_file "${file}" "${instance}"
  done
done
