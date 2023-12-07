#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

msg_info "Creating kubernetes secret"
kubectl create secret \
  generic kubernetes-the-hard-way --from-literal="mykey=mydata"

msg_info "Checking secret is encrypted"
ETCD_OUTPUT="$(multipass exec controller-k8s -- sudo ETCDCTL_API=3 etcdctl get \
     --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem \
     --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem \
     /registry/secrets/default/kubernetes-the-hard-way | hexdump -C)"
if ! grep -q 'aescbc' <<<"${ETCD_OUTPUT=}"; then
  msg_fatal "Kubernetes secret is not encrypted"
fi

msg_info "Deploying nginx"
kubectl create deployment nginx --image=nginx
until grep -q 'true' <(grep 'nginx' <(kubectl get pods -o json -A | jq -r '.items[] | .status.containerStatuses[]? | [.name, .ready|tostring] |join(":")')); do
  echo "Pod nginx is not ready yet, will wait 2 seconds"
  sleep 2
done

msg_info "Exposing nginx"
kubectl expose deployment nginx --port 80 --type NodePort
NODE_PORT=$(kubectl get svc nginx \
  --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
WORKER_IP=$(multipass info 'worker-1-k8s' | grep 'IPv4' | \
  awk '{ print $2 }')

msg_info "Can I talk to nginx?"
curl -I "http://${WORKER_IP}:${NODE_PORT}"
