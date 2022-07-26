#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SERVICE_CLUSTER_IP_RANGE="${1}"
SERVICE_NODE_PORT_RANGE="${2}"
CLUSTER_CIDR="${3}"
KUBE_API_CLUSTER_IP="${4}"

if [[ ! -x $(command -v kube-apiserver) || ! -x $(command -v kube-controller-manager) || ! -x $(command -v kube-scheduler) || ! -x $(command -v kubectl) ]]; then
  echo 'kubernetes binaries are not available in PATH, I will download them and place them in /usr/local/bin'
  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
  sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
fi

if [[ ! -d /var/lib/kubernetes || ! -f /var/lib/kubernetes/ca.pem || ! -f /var/lib/kubernetes/ca-key.pem || ! -f /var/lib/kubernetes/kubernetes-key.pem || ! -f /var/lib/kubernetes/kubernetes.pem || ! -f /var/lib/kubernetes/service-account-key.pem || ! -f /var/lib/kubernetes/service-account.pem || ! -f /var/lib/kubernetes/encryption-config.yaml ]]; then
  echo 'kubernetes certificates and/or encryption config are not where they should, I will now move them where they should be'
  sudo mkdir -p /var/lib/kubernetes/

  sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem \
    encryption-config.yaml /var/lib/kubernetes/
fi

declare -a INTERNAL_IPS=() COMPUTER_IPV4_ADDRESSES=()
while IFS= read -r ip; do
  if [[ -n ${ip} ]]; then
    INTERNAL_IPS+=("${ip}")
  fi
done < <(hostname -I | tr '[:space:]' '\n')
VERSION_REGEX='([0-9]*)\.'

for ip in "${INTERNAL_IPS[@]}"; do
  if grep -E "${VERSION_REGEX}" <<< "${ip}" > /dev/null; then
    COMPUTER_IPV4_ADDRESSES+=("${ip}")
  fi
done

echo 'Creating kube-apiserver systemd service'

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${COMPUTER_IPV4_ADDRESSES[0]} \\
  --allow-privileged=true \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://${COMPUTER_IPV4_ADDRESSES[0]}:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --runtime-config=api/all=true \\
  --service-account-issuer=${KUBE_API_CLUSTER_IP} \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=${SERVICE_CLUSTER_IP_RANGE} \\
  --service-node-port-range=${SERVICE_NODE_PORT_RANGE} \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

if [[ ! -f /var/lib/kubernetes/kube-controller-manager.kubeconfig ]]; then
  echo 'Moving kubernetes Controller Manager config to /var/lib/kubernetes/'
  sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
fi

echo 'Creating Kubernetes Controller Manager systemd service'

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --allocate-node-cidrs=true \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=${CLUSTER_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=${SERVICE_CLUSTER_IP_RANGE} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

if [[ ! -f /var/lib/kubernetes/kube-scheduler.kubeconfig ]]; then
  echo 'Moving Kubernetes Scheduler config to /var/lib/kubernetes/'
  sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/
fi

echo 'Creating Kubernetes Scheduler systemd service'

sudo mkdir -p /etc/kubernetes/config

cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1beta3
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
declare -a K8S_SERVICES=('kube-apiserver' 'kube-controller-manager' 'kube-scheduler')
sudo systemctl enable --now "${K8S_SERVICES[@]}"

echo 'If running on Google Cloud remember to check https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-bootstrapping-kubernetes-controllers.md#enable-http-health-checks'

echo 'Will test components now:'
# shellcheck disable=SC2016
echo '- `kubectl get componentstatuses --kubeconfig admin.kubeconfig`'
# shellcheck disable=SC2016
echo '- if on GCP `curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz`'

counter=0

until [ $counter -eq 5 ] || kubectl get componentstatuses --kubeconfig admin.kubeconfig &> /dev/null ; do
  echo "Kube API Server is not ready yet, will sleep for ${counter} seconds and check again"
  sleep $(( counter++ ))
done

function check_systemctl_status() {
  local UNIT="${1}"
  if ! grep -q 'active' <(systemctl is-active "${UNIT}"); then
    warn "${UNIT} status is NOT: active"
    return 1
  fi
}

for i in "${K8S_SERVICES[@]}"; do
  check_systemctl_status "${i}"
done
