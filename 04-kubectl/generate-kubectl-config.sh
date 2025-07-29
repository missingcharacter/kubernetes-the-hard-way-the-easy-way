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
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=../00-certificates/00-Certificate-Authority/ca.pem \
  --embed-certs=true \
  --proxy-url=socks5://127.0.0.1:9999 \
  --server=https://lima-controller-k8s.internal:6443

echo 'Starting socks5 proxy to access https://lima-controller-k8s.internal:6443'
ssh -F "${HOME}/.lima/controller-k8s/ssh.config" -D 9999 -N -f lima-controller-k8s
echo 'socks5 proxy started'
echo 'To kill the socks5 proxy run:'
# shellcheck disable=SC2016
echo 'pkil --full "ssh -F ${HOME}/.lima/controller-k8s/ssh.config -D 9999 -N -f lima-controller-k8s"'

kubectl config set-credentials admin \
  --client-certificate=../00-certificates/01-admin-client/admin.pem \
  --client-key=../00-certificates/01-admin-client/admin-key.pem

kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin

kubectl config use-context kubernetes-the-hard-way
