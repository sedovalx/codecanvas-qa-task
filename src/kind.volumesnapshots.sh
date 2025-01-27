#!/usr/bin/env bash

set -e -o pipefail

# Install volume snapshot CRDs and the snapshot controller
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

if kubectl get storageclasses.storage.k8s.io --field-selector metadata.name=kind-csi-hostpath-storage-class -o json | jq -e '.items[].metadata.name' &> /dev/null;
then
   echo "kind-csi-hostpath-storage-class exists, skipping installation"
   exit 0
fi

kind_csi_dir="$script_dir/kind-csi"
mkdir -p "$kind_csi_dir"

external_snapshotter_version=v8.0.0

external_snapshotter_dir="$kind_csi_dir/external-snapshotter-client-$external_snapshotter_version"
if [[ ! -d "$external_snapshotter_dir" ]]; then
    echo "Downloading kind csi snapshotter..."
    curl \
        --retry-all-errors \
        --max-time 10 \
        --retry 5 \
        --retry-delay 0 \
        -L "https://github.com/kubernetes-csi/external-snapshotter/archive/refs/tags/client/${external_snapshotter_version}.tar.gz" | tar -xz -C "$kind_csi_dir";
fi

kubectl apply -f "$external_snapshotter_dir/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml"
kubectl apply -f "$external_snapshotter_dir/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml"
kubectl apply -f "$external_snapshotter_dir/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml"
kubectl apply -f "$external_snapshotter_dir/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml"
kubectl apply -f "$external_snapshotter_dir/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml"

# Install the CSI hostpath driver
csi_driver_version="1.14.1"
csi_driver_dir="$kind_csi_dir/csi-driver-host-path-${csi_driver_version}"
if [[ ! -d "$csi_driver_dir" ]]; then
    echo "Downloading csi hostpath driver..."
    curl \
        --retry-all-errors \
        --max-time 10 \
        --retry 5 \
        --retry-delay 0 \
        -L "https://github.com/kubernetes-csi/csi-driver-host-path/archive/refs/tags/v${csi_driver_version}.tar.gz" | tar -xz -C "$kind_csi_dir";
fi

pushd "$csi_driver_dir"
./deploy/kubernetes-latest/deploy.sh
popd

kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: kind-csi-hostpath-storage-class
provisioner: hostpath.csi.k8s.io
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
EOF
