#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

KUBERNETES_VERSION="${1}"
CONTAINERD_VERSION="${2}"
CNI_PLUGINS_VERSION="${3}"
DNS_CLUSTER_IP="${4}"

if ! grep 'master-k8s' /etc/hosts &> /dev/null; then
  cat multipass-hosts | sudo tee -a /etc/hosts
fi

if [[ ! -x $(command -v socat) || ! -x $(command -v conntrack) || ! -x $(command -v ipset) ]]; then
  echo 'Installing socat conntrack and ipset'
  sudo apt update
  sudo apt -y install socat conntrack ipset
fi

echo 'Disabling swap'
sudo swapoff -a

if [[ ! -x $(command -v kubectl) || ! -x $(command -v kube-proxy) || ! -x $(command -v kubelet) || ! -x $(command -v runc) ]]; then
  echo 'Installing kubernetes worker binaries'
  declare -a KUBE_WORKER_BINS
  KUBE_WORKER_BINS=(
    "https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz"
    "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/cri-containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
    "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl"
    "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kube-proxy"
    "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubelet")
  for bin in "${KUBE_WORKER_BINS[@]}"; do
    echo "Will try to download ${bin}"
    wget -q --show-progress --https-only --timestamping "${bin}"
  done

  sudo mkdir -p \
    /etc/cni/net.d \
    /opt/cni/bin \
    /var/lib/kubelet \
    /var/lib/kube-proxy \
    /var/lib/kubernetes \
    /var/run/kubernetes

  mkdir containerd
  tar -xvf "cri-containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz" -C containerd
  mv containerd/usr/local/bin/crictl .
  mv containerd/usr/local/sbin/runc .
  sudo tar -xvf "cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz" -C /opt/cni/bin/
  chmod +x crictl kubectl kube-proxy kubelet runc
  sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
  sudo mv containerd/usr/local/bin/* /bin/
fi

if [[ ! -f /etc/containerd/config.toml ]]; then
  echo 'Creating the containerd configuration file and systemd service'
  sudo mkdir -p /etc/containerd/
  cat << EOF | sudo tee /etc/containerd/config.toml
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "runc"
      snapshotter = "overlayfs"
  [plugins."io.containerd.runtime.v1.linux"]
    runtime = "runc"
    runtime_root = ""
EOF

  cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
fi

if [[ ! -f /var/lib/kubelet/kubelet-config.yaml || ! -f /var/lib/kubelet/kubeconfig || ! -f /etc/cni/net.d/99-loopback.conf ]]; then
  echo 'Creating kubelet configuration'

  cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF

  sudo mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
  sudo mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
  sudo mv ca.pem /var/lib/kubernetes/

  cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "${DNS_CLUSTER_IP}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
registerNode: true
EOF

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
fi

if [[ ! -f /var/lib/kube-proxy/kubeconfig || ! -f /var/lib/kube-proxy/kube-proxy-config.yaml || ! -f /etc/systemd/system/kube-proxy.service ]]; then
  echo 'Creating kube-proxy config'
  sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
  cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
fi

sudo systemctl daemon-reload
declare -a K8S_SERVICES=('containerd' 'kubelet' 'kube-proxy')
sudo systemctl enable --now "${K8S_SERVICES[@]}"

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

K8S_NODE_NAME="$(hostname)"

