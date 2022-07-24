#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

for file in ./*/*.sh; do
  cd "$(dirname ./"${file}")" || exit
  bash "${file##*/}"
  cd - || exit
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
