#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

COUNTRY="${1:-US}"
CITY="${2:-Austin}"
STATE="${3:-Texas}"

for instance in $(limactl list -q); do
  cat > "${instance}"-csr.json <<EOF
{
  "CN": "system:node:lima-${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${COUNTRY}",
      "L": "${CITY}",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "${STATE}"
    }
  ]
}
EOF

  INTERNAL_IP="$(limactl shell "${instance}" hostname -I | xargs)"

  cfssl gencert \
    -ca=../00-Certificate-Authority/ca.pem \
    -ca-key=../00-Certificate-Authority/ca-key.pem \
    -config=../00-Certificate-Authority/ca-config.json \
    -hostname=lima-"${instance}","${INTERNAL_IP}",lima-"${instance}".internal \
    -profile=kubernetes \
    "${instance}"-csr.json | cfssljson -bare "${instance}"
done
