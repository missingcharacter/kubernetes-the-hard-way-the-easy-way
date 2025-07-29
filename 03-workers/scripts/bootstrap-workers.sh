#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

CNI_PLUGINS_VERSION="${1}"
DNS_CLUSTER_IP="${2}"
CRICTL_VERSION="${3}"

# Changing directory to ${HOME}
cd || exit 1

if ! grep 'controller-k8s' /etc/hosts &> /dev/null; then
  # shellcheck disable=SC2002
  cat limactl-hosts | sudo tee -a /etc/hosts
fi

if ! command -v socat &> /dev/null || ! command -v conntrack &> /dev/null || ! command -v ipset &> /dev/null; then
  echo 'Installing socat conntrack and ipset'
  sudo apt update
  sudo apt -y install socat conntrack ipset
fi

echo 'Disabling swap'
sudo swapoff -a

if ! command -v kubectl &> /dev/null || ! command -v kube-proxy &> /dev/null || ! command -v kubelet &> /dev/null; then
  echo 'Installing kubernetes worker binaries'

  sudo mkdir -p \
    /etc/cni/net.d \
    /opt/cni/bin \
    /var/lib/kubelet \
    /var/lib/kube-proxy \
    /var/lib/kubernetes \
    /var/run/kubernetes

  mkdir crictl-dir
  tar -xvf "crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz" -C crictl-dir
  mv crictl-dir/crictl .
  sudo tar -xvf "cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz" -C /opt/cni/bin/
  chmod +x crictl kubectl kube-proxy kubelet
  sudo mv crictl kubectl kube-proxy kubelet /usr/local/bin/
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
fi

if [[ ! -f /etc/crictl.yaml ]]; then
  cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: false
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

  sudo mv "${HOSTNAME#lima-}"-key.pem "${HOSTNAME#lima-}".pem /var/lib/kubelet/
  sudo mv "${HOSTNAME#lima-}".kubeconfig /var/lib/kubelet/kubeconfig
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
tlsCertFile: "/var/lib/kubelet/${HOSTNAME#lima-}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME#lima-}-key.pem"
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

for i in "${K8S_SERVICES[@]}"; do
  counter=0
  until [ $counter -eq 5 ] || grep -q 'active' <(systemctl is-active "${i}"); do
    echo "Will sleep for ${counter} seconds and check ${i} again"
    sleep $(( counter++ ))
  done
done

function get_node_status() {
  kubectl get nodes \
    --kubeconfig /var/lib/kubelet/kubeconfig | \
    grep "${HOSTNAME#lima-}" | awk '{ print $2 }'
}

counter=0

until [ $counter -eq 5 ] || [[ "$(get_node_status)" != 'Ready' ]]; do
  echo "Node ${HOSTNAME#lima-} is NOT ready, will sleep for ${counter} seconds and check again"
  sleep $(( counter++ ))
done
