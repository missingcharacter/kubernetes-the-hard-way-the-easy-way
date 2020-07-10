#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo 'Installing cilium'

kubectl apply -f ./cilium-quick-install.yaml

echo 'Installing coredns'

kubectl apply -f ./coredns.yaml
