#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

function transfer_file() {
  local FILE="${1}"
  local INSTANCE=${2}
  multipass transfer -v "${FILE}" ${INSTANCE}:/home/ubuntu/${FILE##*/}
}

for instance in $(multipass list | grep 'worker' | awk '{ print $1 }'); do
  for file in $(ls */*.sh); do
    transfer_file "${file}" "${instance}"
  done
done
