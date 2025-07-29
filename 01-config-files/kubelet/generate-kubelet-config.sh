#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

# This works because we only have 1 controller
# logic will have to change if we have more than 1
for instance in $(limactl list -q | grep 'worker'); do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=../../00-certificates/00-Certificate-Authority/ca.pem \
    --embed-certs=true \
    --server=https://lima-controller-k8s.internal:6443 \
    --kubeconfig="${instance}".kubeconfig

  kubectl config set-credentials system:node:"${instance}" \
    --client-certificate=../../00-certificates/02-kubelet-client/"${instance}".pem \
    --client-key=../../00-certificates/02-kubelet-client/"${instance}"-key.pem \
    --embed-certs=true \
    --kubeconfig="${instance}".kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:"${instance}" \
    --kubeconfig="${instance}".kubeconfig

  kubectl config use-context default --kubeconfig="${instance}".kubeconfig
done
