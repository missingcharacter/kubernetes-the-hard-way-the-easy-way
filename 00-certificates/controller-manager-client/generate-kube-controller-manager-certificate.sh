#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

COUNTRY="${1:-US}"
CITY="${2:-Austin}"
STATE="${3:-Texas}"

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${COUNTRY}",
      "L": "${CITY}",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "${STATE}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=../CA/ca.pem \
  -ca-key=../CA/ca-key.pem \
  -config=../CA/ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
