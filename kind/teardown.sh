#!/bin/bash
set -o errexit

cd "$(cd "$(dirname "$0")" > /dev/null && pwd)"

# desired cluster name; default is "kind"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kind}"

kind_version=$(kind version)
kind_network='kind'
reg_name='kind-registry'
reg_port='5050'


running="$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)"
if [ "${running}" == 'true' ]; then
  cid="$(docker inspect -f '{{.ID}}' "${reg_name}")"
  echo "> Stopping and deleting Kind Registry container..."
  docker stop $cid >/dev/null
  docker rm $cid >/dev/null
fi

# Remove istioctl
rm -rf ./istioctl

echo "> Deleting Kind cluster..."
kind delete cluster --name=$KIND_CLUSTER_NAME
