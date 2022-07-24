#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

for instance in $(multipass list | grep 'controller' | awk '{ print $1 }'); do
  for file in ./*/*.sh; do
    transfer_file "${file}" "${instance}"
  done
done
