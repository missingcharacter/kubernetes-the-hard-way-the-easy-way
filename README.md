# kubernetes-distro

# Requirements

- [tmux](https://github.com/tmux/tmux)
  - [How to run commands in parallel with tmux](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/01-prerequisites.md#running-commands-in-parallel-with-tmux)
  - Install
    - linux: `apt install tmux` # or yum/dnf/pacman
    - mac: `brew install tmux`
- [multipass](https://github.com/canonical/multipass)
  - linux: `sudo snap install multipass --classic`
  - mac: `brew cask install multipass`
- `cfssl` and `cfssljson`
  - linux:
```shell
wget -q --show-progress --https-only --timestamping \
  https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssl \
  https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssljson
chmod +x cfssl cfssljson
sudo mv cfssl cfssljson /usr/local/bin/
```
  - mac: `brew install cfssl`
- `kubectl`
  - linux:
```shell
wget https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```
  - mac:
```shell
curl -o kubectl https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/darwin/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

# Procedure

1. Create your machines:

```shell
$ for i in 'master-k8s' 'worker-1-k8s' 'worker-2-k8s' ; do multipass launch "${i}" 20.04; done
```

2. Create and distribute the certificates:

```shell
$ cd 00-certificates/
$ bash distribute-certificates.sh
$ cd -
```

3. Create and distribute config files:

```shell
$ cd 01-config-files/
$ bash distribute-config-files.sh
$ cd -
```

4. Transfer master/controller and worker setup scripts

```shell
$ cd 02-masters
$ bash transfer-shell-scripts.sh
$ cd -
$ cd 03-workers
$ bash transfer-shell-scripts.sh
$ cd -
```

5. Setup the kubernetes control plane

```shell
$ multipass shell master-k8s

master-k8s $ bash generate-etcd-systemd.sh
...
41005079efc62734, started, master-k8s, https://192.168.64.5:2380, https://192.168.64.5:2379, false

master-k8s $ bash generate-kubernetes-control-plane-systemd.sh
...
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true"}

master-k8s $ bash generate-kubelet-rbac-authorization.sh
The commands in this section will effect the entire cluster and only need to be run once from one of the controller nodes.
clusterrole.rbac.authorization.k8s.io/system:kube-apiserver-to-kubelet created
clusterrolebinding.rbac.authorization.k8s.io/system:kube-apiserver created
the following is not related to rbac
{
  "major": "1",
  "minor": "15",
  "gitVersion": "v1.15.3",
  "gitCommit": "2d3c76f9091b6bec110a5e63777c332469e0cba2",
  "gitTreeState": "clean",
  "buildDate": "2019-08-19T11:05:50Z",
  "goVersion": "go1.12.9",
  "compiler": "gc",
  "platform": "linux/amd64"
}
master-k8s $ exit
```

6. Setup worker nodes (use tmux to run the commands below in parallel)

```shell
$ multipass shell worker-1-k8s
worker-1-k8s $ bash bootstrap-workers.sh
worker-1-k8s $ sudo systemctl status containerd kubelet kube-proxy # confirm all services are green and running
worker-1-k8s $ exit
```

7. Setup kubectl in your computer

```shell
$ cd 04-kubectl/
$ bash generate-kubectl-config.sh
$ kubectl get componentstatuses
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true"}
$ kubectl get nodes
NAME           STATUS   ROLES    AGE     VERSION
worker-1-k8s   Ready    <none>   7h38m   v1.15.3
worker-2-k8s   Ready    <none>   7h38m   v1.15.3
$ cd -
```

8. Setup networking

```shell
$ cd 05-networking/
$ bash configure-cilium-coredns.sh
$ kubectl run --generator=run-pod/v1 busybox --image=busybox:1.28 --command -- sleep 3600
$ # The command below may take a while
$ kubectl get pods -l run=busybox
NAME      READY   STATUS    RESTARTS   AGE
busybox   1/1     Running   0          3s
$ POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
$ kubectl exec -ti $POD_NAME -- nslookup kubernetes
Server:    172.17.0.10
Address 1: 172.17.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 172.17.0.1 kubernetes.default.svc.cluster.local
```

9. Your cluster is ready, lets verify data encryption works

```shell
$ kubectl create secret generic kubernetes-the-hard-way --from-literal="mykey=mydata"
$ multipass exec master-k8s -- sudo ETCDCTL_API=3 etcdctl get --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem /registry/secrets/default/kubernetes-the-hard-way | hexdump -C
00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
00000010  73 2f 64 65 66 61 75 6c  74 2f 6b 75 62 65 72 6e  |s/default/kubern|
00000020  65 74 65 73 2d 74 68 65  2d 68 61 72 64 2d 77 61  |etes-the-hard-wa|
00000030  79 0a 6b 38 73 3a 65 6e  63 3a 61 65 73 63 62 63  |y.k8s:enc:aescbc|
00000040  3a 76 31 3a 6b 65 79 31  3a 61 bb c0 45 f2 df 88  |:v1:key1:a..E...|
00000050  36 46 05 df c1 df 26 e1  e0 59 18 9f 7d 51 7a d9  |6F....&..Y..}Qz.|
00000060  28 0d 03 4e c3 14 55 01  51 d6 aa cc 50 21 a5 09  |(..N..U.Q...P!..|
00000070  86 92 89 9b 33 82 43 09  7d 5b fe bb 68 45 43 48  |....3.C.}[..hECH|
00000080  96 9a 1e a8 88 30 82 a8  2c d8 26 ea 12 19 58 da  |.....0..,.&...X.|
00000090  3a 25 ed 6b 47 1f e2 e9  31 91 e6 cf 64 bb 19 41  |:%.kG...1...d..A|
000000a0  fe 2b 7a 86 a8 be e4 c0  b6 98 2e dc 96 92 58 92  |.+z...........X.|
000000b0  c4 6b c1 85 a9 d0 ec d6  03 2d c7 2c 14 f5 da 03  |.k.......-.,....|
000000c0  ef c6 c9 2b bc 26 9c 36  ab 0c da 08 f2 8b 79 c7  |...+.&.6......y.|
000000d0  12 98 55 5f 4c 56 f7 fd  e1 71 45 16 a3 59 01 76  |..U_LV...qE..Y.v|
000000e0  97 5b d1 cc 91 92 c5 d9  05 0a                    |.[........|
000000ea
```

The etcd key should be prefixed with `k8s:enc:aescbc:v1:key1`, which indicates the `aescbc` provider was used to encrypt the data with the `key1` encryption key.

10. [Deployments](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/13-smoke-test.md#deployments) as they are described on Kubernetes the hard way will work

11. NodePort service will work in the following way (Depends on step 10)

```shell
$ kubectl expose deployment nginx --port 80 --type NodePort
$ NODE_PORT=$(kubectl get svc nginx --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
$ WORKER_IP=$(multipass info 'worker-1-k8s' | grep 'IPv4' | awk '{ print $2 }')
$ curl -I http://${WORKER_IP}:${NODE_PORT}
HTTP/1.1 200 OK
Server: nginx/1.19.0
Date: Fri, 10 Jul 2020 04:18:52 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 26 May 2020 15:00:20 GMT
Connection: keep-alive
ETag: "5ecd2f04-264"
Accept-Ranges: bytes
```

12. You've done a kubernetes!

# Troubleshooting

## All nodes should be able to reach each other via hostname

01-config-files/distribute-config-files.sh generates multipass-hosts and later the bootstrap scripts append it to /etc/hosts on the masters and workers

# Related links
- [multipass /etc/hosts](https://github.com/canonical/multipass/issues/853#issuecomment-630097263)
- https://www.youtube.com/playlist?list=PLC6M23w-Wn5mA_bomV6YVB5elNw7IsHt5
