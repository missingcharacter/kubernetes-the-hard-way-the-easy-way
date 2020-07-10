#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if ! grep 'worker-1-k8s' /etc/hosts &> /dev/null; then
  cat multipass-hosts | sudo tee -a /etc/hosts
fi

if [[ ! -x $(command -v etcd) || ! -x $(command -v etcdctl) ]]; then
  wget -q --show-progress --https-only --timestamping \
    "https://github.com/etcd-io/etcd/releases/download/v3.4.0/etcd-v3.4.0-linux-amd64.tar.gz"
  tar -xvf etcd-v3.4.0-linux-amd64.tar.gz
  sudo mv etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/
  rm -rf etcd-v3.4.0-linux-amd64.tar.gz etcd-v3.4.0-linux-amd64/
fi

if [[ ! -f /etc/etcd/kubernetes.pem || ! -f /etc/etcd/kubernetes-key.pem ]]; then
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
fi

INTERNAL_IPS=( $(hostname -I | tr '[:space:]' '\n') )
ETCD_NAME="$(hostname -s)"
VERSION_REGEX='([0-9]*)\.'

declare -a COMPUTER_IPV4_ADDRESSES
for ip in "${INTERNAL_IPS[@]}"; do
  if grep -E "${VERSION_REGEX}" <<< "${ip}" > /dev/null; then
    COMPUTER_IPV4_ADDRESSES+=("${ip}")
  fi
done

echo 'Creating etcd systemd unit'

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${COMPUTER_IPV4_ADDRESSES[0]}:2380 \\
  --listen-peer-urls https://${COMPUTER_IPV4_ADDRESSES[0]}:2380 \\
  --listen-client-urls https://${COMPUTER_IPV4_ADDRESSES[0]}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${COMPUTER_IPV4_ADDRESSES[0]}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${ETCD_NAME}=https://${COMPUTER_IPV4_ADDRESSES[0]}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo 'Reloading systemd, enabling and starting etcd systemd service'

sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

echo 'Listing etcd members'

sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
