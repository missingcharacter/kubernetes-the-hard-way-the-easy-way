#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=../../certificates/CA/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=../../certificates/controller-manager-client/kube-controller-manager.pem \
  --client-key=../../certificates/controller-manager-client/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
