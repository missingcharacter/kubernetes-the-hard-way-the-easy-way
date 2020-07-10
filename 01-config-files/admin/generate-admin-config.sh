#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=../../00-certificates/CA/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=../../00-certificates/admin-client/admin.pem \
  --client-key=../../00-certificates/admin-client/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig
