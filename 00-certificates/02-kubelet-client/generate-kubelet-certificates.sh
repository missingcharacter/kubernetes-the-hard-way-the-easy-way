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

for instance in $("${MULTIPASS_CMDS[@]}" list | grep 'worker' | awk '{ print $1 }'); do
  cat > "${instance}"-csr.json <<EOF
{
  "CN": "system:node:${instance}",
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

  INTERNAL_IP="$("${MULTIPASS_CMDS[@]}" info "${instance}" | grep 'IPv4' | awk '{ print $2 }')"

  cfssl gencert \
    -ca=../00-Certificate-Authority/ca.pem \
    -ca-key=../00-Certificate-Authority/ca-key.pem \
    -config=../00-Certificate-Authority/ca-config.json \
    -hostname="${instance}","${INTERNAL_IP}" \
    -profile=kubernetes \
    "${instance}"-csr.json | cfssljson -bare "${instance}"
done
