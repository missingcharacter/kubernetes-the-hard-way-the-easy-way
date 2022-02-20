#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
. ${GITROOT}/lib/strict-mode
strictMode
. ${GITROOT}/lib/utils

THIS_SCRIPT=$(basename $0)
PADDING=$(printf %-${#THIS_SCRIPT}s " ")

function check_dependencies() {
  # Ensure dependencies are present
  if [[ ! -x $(command -v git) || ! -x $(command -v multipass) || ! -x $(command -v cfssl) || ! -x $(command -v cfssljson) || ! -x $(command -v kubectl) || ! -x $(command -v ipcalc) ]]; then
      msg_fatal "[-] Dependencies unmet. Please verify that the following are installed and in the PATH: git, multipass, cfssl, cfssljson, kubectl, ipcalc" >&2
      exit 1
  fi
}

check_dependencies

export \
  KUBERNETES_VERSION='1.23.4' \
  ETCD_VERSION='3.5.2' \
  CONTAINERD_VERSION='1.6.0' \
  CNI_PLUGINS_VERSION='1.0.1' \
  COREDNS_CHART_VERSION='1.16.7' \
  CILIUM_CHART_VERSION='1.11.1' \
  SERVICE_CLUSTER_IP_RANGE='172.17.0.0/24' \
  SERVICE_NODE_PORT_RANGE='30000-32767' \
  CLUSTER_CIDR='172.16.0.0/16' \
  DNS_CLUSTER_IP='172.17.0.10'

export KUBE_API_CLUSTER_IP="$(ipcalc ${SERVICE_CLUSTER_IP_RANGE} | grep 'HostMin' | awk '{ print $2 }')"

# To Be Determined
# - Service IP range: 10.32.0.0/24
# - Node Port range: 30000-32767

msg_info 'Creating multipass instances'

for i in 'master-k8s' 'worker-1-k8s' 'worker-2-k8s' ; do
  multipass launch --name "${i}" --cpus 2 --mem 2048M --disk 5G 20.04
done

msg_info 'Creating and distributing certificates'

cd 00-certificates/
bash distribute-certificates.sh
cd -

msg_info 'Creating and distributing config files'

cd 01-config-files/
bash distribute-config-files.sh
cd -

msg_info 'Push master and worker setup scripts'

cd 02-masters
bash transfer-shell-scripts.sh
cd -
cd 03-workers
bash transfer-shell-scripts.sh
cd -

msg_info 'Configuring the Kubernetes control plane'

multipass exec master-k8s -- bash generate-etcd-systemd.sh "${ETCD_VERSION}"
multipass exec master-k8s -- bash generate-kubernetes-control-plane-systemd.sh "${KUBERNETES_VERSION}" "${SERVICE_CLUSTER_IP_RANGE}" "${SERVICE_NODE_PORT_RANGE}" "${CLUSTER_CIDR}"
multipass exec master-k8s -- bash generate-kubelet-rbac-authorization.sh


msg_info 'Configuring the Kubernetes workers'

for i in 'worker-1-k8s' 'worker-2-k8s'; do
  msg_info "Provisioning ${i}"
  multipass exec "${i}" -- bash bootstrap-workers.sh "${KUBERNETES_VERSION}" "${CONTAINERD_VERSION}" "${CNI_PLUGINS_VERSION}" "${DNS_CLUSTER_IP}"
done

msg_info 'Setting up kubectl to use your newly created cluster'

cd 04-kubectl/
bash generate-kubectl-config.sh
kubectl get componentstatuses
cd -

msg_info 'Setting up coredns and cilium'

cd 05-networking/
bash configure-cilium-coredns.sh
cd -

msg_info 'Your cluster should be ready in a couple of minutes!'
msg_info 'You can check the status running: kubectl get all --all-namespaces'
