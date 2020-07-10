# Temporary fix

```shell
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

COUNTRY="${1:-US}"
CITY="${2:-Austin}"
STATE="${3:-Texas}"
VERSION_REGEX='([0-9]*)\.'

declare -a COMPUTER_IPV4_ADDRESSES
# This works because we only have 1 master
# logic will have to change if we have more than 1
#COMPUTER_IP_ADDRESSES=( $(hostname -I | tr '[:space:]' '\n') $(multipass list | grep -E "${VERSION_REGEX}" | awk '{ print $3 }') )

#for ip in "${COMPUTER_IP_ADDRESSES[@]}"; do
#  if grep -E "${VERSION_REGEX}" <<< "${ip}" > /dev/null; then
#    COMPUTER_IPV4_ADDRESSES+=("${ip}")
#  fi
#done

function join_by {
  local IFS="${1}"
  shift
  echo "$*"
}

#IPV4_ADDRESSES=$(join_by ',' "${COMPUTER_IPV4_ADDRESSES[@]}")
IPV4_ADDRESSES='192.168.1.17,192.168.1.31,10.100.245.1,172.17.0.1,10.100.245.168,10.100.245.10,10.100.245.36,192.168.64.5,192.168.64.6,192.168.64.7'
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${COUNTRY}",
      "L": "${CITY}",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "${STATE}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=../00-Certificate-Authority/ca.pem \
  -ca-key=../00-Certificate-Authority/ca-key.pem \
  -config=../00-Certificate-Authority/ca-config.json \
  -hostname=${IPV4_ADDRESSES},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
```
