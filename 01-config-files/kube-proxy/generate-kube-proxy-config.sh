#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# This works because we only have 1 controller
# logic will have to change if we have more than 1
KUBERNETES_VIRTUAL_IP_ADDRESS="$(multipass list | grep 'controller' | awk '{ print $1 }' | xargs multipass info | grep 'IPv4' | awk '{ print $2 }')"

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=../../00-certificates/00-Certificate-Authority/ca.pem \
  --embed-certs=true \
  --server=https://"${KUBERNETES_VIRTUAL_IP_ADDRESS}":6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=../../00-certificates/04-kube-proxy/kube-proxy.pem \
  --client-key=../../00-certificates/04-kube-proxy/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
