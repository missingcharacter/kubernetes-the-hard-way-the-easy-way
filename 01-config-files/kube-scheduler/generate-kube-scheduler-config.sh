#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=../../00-certificates/00-Certificate-Authority/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=../../00-certificates/05-kube-scheduler/kube-scheduler.pem \
  --client-key=../../00-certificates/05-kube-scheduler/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
