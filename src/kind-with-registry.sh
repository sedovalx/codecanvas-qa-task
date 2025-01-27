#!/usr/bin/env bash

# This script creates a Kind cluster prepared for CodeCanvas Chart v2 deployment
# and sets up the kind-registry to allow publishing locally built images.

set -e -o pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

RED='\033[0;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

status() {
    echo -e "${GREEN}$1${NC}"
}

failure() {
    echo -e "${RED}$1${NC}" >&2
}

CLUSTER_NAME="spaceport-kind"

EXISTING_CLUSTER=$(docker container ls | grep "${CLUSTER_NAME}-control-plane" || true)
if [[ -z "${EXISTING_CLUSTER}" ]]; then
    status "* Spinning up a new kind cluster..."
    echo "Cluster config is $CLUSTER_CONFIG"
    SECONDS=0
    mkdir -p "${HOME}/.kube"
    touch "${KUBECONFIG}"
    kind create cluster \
        --name "${CLUSTER_NAME}" \
        --config "$script_dir"/cluster.kind.yaml \
        --image kindest/node:v1.29.8 \
        --kubeconfig "${KUBECONFIG}"

    kubectl create namespace kube-space
    kubectl --kubeconfig "$KUBECONFIG" apply -f "${script_dir}/addons"

    status "* kind cluster is up! [${SECONDS}s]"
else
    status "* It seems ${CLUSTER_NAME} cluster is already up"
fi

"$script_dir"/kind.volumesnapshots.sh

status "* Waiting for the nginx controller to be up..."
CONTROLLER_NAMESPACE=$(kubectl get deployment -l "app.kubernetes.io/component=controller" -l "app.kubernetes.io/part-of=ingress-nginx" --all-namespaces --output=jsonpath='{.items[*].metadata.namespace}')
if [[ -z "${CONTROLLER_NAMESPACE}" ]]; then
    failure "Nginx controller deployment is not found. Exit"
    exit 1
fi
kubectl wait --for=condition=ready pod -l "app.kubernetes.io/component=controller" -n "${CONTROLLER_NAMESPACE}" --timeout 240s
status "* Nginx controller is up"

# Expose 63101 port for jump service
kubectl create configmap tcp-services --from-literal=63101=kube-space/jump-ssh:63101 -n kube-ingress || true

. "$script_dir/up-registry.sh"
