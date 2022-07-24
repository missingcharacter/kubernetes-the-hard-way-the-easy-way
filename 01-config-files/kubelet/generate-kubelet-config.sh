#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# This works because we only have 1 controller
# logic will have to change if we have more than 1
KUBERNETES_VIRTUAL_IP_ADDRESS="$(multipass list | grep 'controller' | awk '{ print $1 }' | xargs multipass info | grep 'IPv4' | awk '{ print $2 }')"

for instance in $(multipass list | grep 'worker' | awk '{ print $1 }'); do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=../../00-certificates/00-Certificate-Authority/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_VIRTUAL_IP_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=../../00-certificates/02-kubelet-client/${instance}.pem \
    --client-key=../../00-certificates/02-kubelet-client/${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done
