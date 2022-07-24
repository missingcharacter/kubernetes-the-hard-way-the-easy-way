#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

VALID_IN_YEARS="${1:-1}"
#DAYS_IN_YEAR='365'
#HOURS_IN_DAY='24'
HOURS_IN_YEAR='8760'

# shellcheck disable=SC2219
let "VALID_IN_HOURS = ${VALID_IN_YEARS} * ${HOURS_IN_YEAR}"

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "${VALID_IN_HOURS}h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "${VALID_IN_HOURS}h"
      }
    }
  }
}
EOF

COUNTRY="${2:-US}"
CITY="${3:-Austin}"
STATE="${4:-Texas}"

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${COUNTRY}",
      "L": "${CITY}",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "${STATE}"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
