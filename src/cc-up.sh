#!/usr/bin/env bash

set -e -o pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
tmp_dir="$script_dir/.tmp"
mkdir -p "$tmp_dir"

print_help_and_exit() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [IMAGE_VERSION]

$(basename "${BASH_SOURCE[0]}") starts a kind cluster using docker and installs CodeCanvas chart
IMAGE_VERSION stands for applicationVersion for helm chart. If no IMAGE_VERSION given, the script tries to retrieve the latest version from the registry.

Available options:

--atomic          Pass atomic argument to helm install
--wait-healthy    Wait for jetbrains.local to be up and running
--chart-url       Chart url, e.g. oci://ghcr.io/sedovalx/codecanvas-qa-task/charts/codecanvas
--chart-version   Chart version, if it is not provided but chart-url is specified, the latest one will be retrieved
--chart-archive   Path to the chart archive
-h, --help        Print this help and exit
EOF
  exit
}

RED='\033[0;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

IMAGE_VERSION="${1}"

status() {
    echo -e "${GREEN}$1${NC}"
}

failure() {
    echo -e "${RED}$1${NC}" >&2
}

fatal_failure() {
    failure "$1"
    exit 1
}

POSITIONAL_ARGS=()
HELM_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      print_help_and_exit
      ;;
   --wait-healthy)
      export WAIT_HEALTHY=YES
      shift
      ;;
   --chart-url)
      CHART_URL="$2"
      shift
      ;;
   --chart-version)
      CHART_VERSION="$2"
      shift
      ;;
   --chart-archive)
      CHART_ARCHIVE="$2"
      shift
      ;;
    --atomic)
      HELM_ARGS+=(--atomic)
      shift
      ;;
    -*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

. "$script_dir"/kind-with-registry.sh

install_chart_deps() {
    if (kubectl --namespace kube-space rollout status deployment canvas-deps-minio \
        && kubectl --namespace kube-space rollout status statefulset canvas-deps-postgresql); then
        status "CodeCanvas dependencies (PostgreSQL, Minio) are installed"
        return
    fi
    status "Installing CodeCanvas dependencies (PostgreSQL, Minio)"

    helm upgrade --install canvas-deps oci://public.registry.jetbrains.space/p/codecanvas/release-charts/codecanvas-dependencies \
      --version 2024.2 \
      --namespace kube-space \
      -f "$script_dir/canvas.deps.kind.values.yaml" \
      --wait \
      --timeout 15m

    kubectl create secret generic spaceport-db-secret \
        --from-literal="DB_PASSWORD=password" \
        --from-literal="DB_HOST=canvas-deps-postgresql.kube-space" \
        --from-literal="DB_PORT=5432" \
        --from-literal="DB_USERNAME=postgres" \
        --from-literal="DB_NAME=postgres" \
        -o yaml --save-config --dry-run=client --namespace=kube-space \
        | kubectl apply -f -

    kubectl create secret generic spaceport-minio-secret \
        --from-literal="CODECANVAS_OBJECT_STORAGE_TYPE=aws" \
        --from-literal="CODECANVAS_OBJECT_STORAGE_BUCKET=space" \
        --from-literal="CODECANVAS_OBJECT_STORAGE_REGION=eu-west-1" \
        --from-literal="CODECANVAS_OBJECT_STORAGE_ACCESS_KEY=admin" \
        --from-literal="CODECANVAS_OBJECT_STORAGE_SECRET_KEY=password" \
        --from-literal="CODECANVAS_OBJECT_STORAGE_ENDPOINT=canvas-deps-minio.kube-space:9000" \
        -o yaml --save-config --dry-run=client --namespace=kube-space \
        | kubectl apply -f -

    kubectl create secret generic spaceport-minio-secret-audit \
        --from-literal="CODECANVAS_AUDIT_OBJECT_STORAGE_TYPE=aws" \
        --from-literal="CODECANVAS_AUDIT_OBJECT_STORAGE_BUCKET=space" \
        --from-literal="CODECANVAS_AUDIT_OBJECT_STORAGE_REGION=eu-west-1" \
        --from-literal="CODECANVAS_AUDIT_OBJECT_STORAGE_ACCESS_KEY=admin" \
        --from-literal="CODECANVAS_AUDIT_OBJECT_STORAGE_SECRET_KEY=password" \
        --from-literal="CODECANVAS_AUDIT_OBJECT_STORAGE_ENDPOINT=canvas-deps-minio.kube-space:9000" \
        -o yaml --save-config --dry-run=client --namespace=kube-space \
        | kubectl apply -f -

    kubectl create secret generic spaceport-redis-secret \
        --from-literal="CODECANVAS_REDIS_HOST=redis-master.kube-space" \
        --from-literal="CODECANVAS_REDIS_PORT=6379" \
        --from-literal="CODECANVAS_REDIS_ARCHITECTURE=single" \
        -o yaml --save-config --dry-run=client --namespace=kube-space \
        | kubectl apply -f -
}

DEV_ENV_NAMESPACE="${DEV_ENV_NAMESPACE:=spaceport-rde}"
status "Creating namespace for operator $DEV_ENV_NAMESPACE ..."
kubectl create namespace "$DEV_ENV_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

SECONDS=0
if [ -n "$CIRCLET_LICENSE_KEY" ]; then
    HELM_ARGS+=(--set-string application.secret.codecanvas.license.key="$CIRCLET_LICENSE_KEY")
fi

install_chart_deps

status "Generating secrets..."

# this -traditional key is only relevant for OpenSSL, but not for LibreSSL which is installed on macOS by default
supports_traditional=
case "$(openssl version)" in
    *OpenSSL*)
    supports_traditional="yes"
    ;;
esac


HELM_CHART="$CHART_URL"
HELM_ARGS+=(--version="$CHART_VERSION")
HELM_ARGS+=(-f "$script_dir/codecanvas.packaged.kind.values.yaml")
HELM_INSTALL_MESSAGE="Installing CodeCanvas chart $CHART_URL $CHART_VERSION"

# It is not convenient to regenerate master secret each time and get error if database is not wiped
master_secret_file="$tmp_dir/spaceport-master-secret"
if [ ! -f "$master_secret_file" ]; then
    openssl rand -base64 32 > "$master_secret_file"
fi
master_secret="$(cat "$master_secret_file")"

jump_jwt_private_key_file="$tmp_dir/jump-jwt-private-key"
if [ ! -f "$jump_jwt_private_key_file" ]; then
  openssl ecparam -name prime256v1 -genkey -noout -out "$jump_jwt_private_key_file"
fi
jump_jwt_private_key="$(cat "$jump_jwt_private_key_file")"
jump_jwt_public_key="$(openssl ec -in <(echo "$jump_jwt_private_key") -pubout 2>/dev/null || fatal_failure "Failed to generate relay public key")"

jump_private_host_key_file="$tmp_dir/jump-private-host-key"
if [ ! -f "$jump_private_host_key_file" ]; then
  openssl genrsa ${supports_traditional:+"-traditional"} -out "$jump_private_host_key_file"
fi
jump_private_host_key="$(cat "$jump_private_host_key_file")"
jump_public_host_key="$(openssl rsa -in <(echo "$jump_private_host_key") -pubout 2>/dev/null || fatal_failure "Failed to generate jump host public key")"

relay_private_key_file="$tmp_dir/relay-private-key-file"
if [ ! -f "$relay_private_key_file" ]; then
  openssl ecparam -name prime256v1 -genkey -noout -out "$relay_private_key_file"
fi
relay_private_key="$(cat "$relay_private_key_file")"
relay_public_key="$(openssl ec -in <(echo "$relay_private_key") -pubout 2>/dev/null || fatal_failure "Failed to generate relay public key")"

HELM_ARGS+=(--set-string application.secret.codecanvas.masterSecret="$master_secret")
HELM_ARGS+=(--set-string application.secret.codecanvas.relay.jwtPrivateKey="$relay_private_key")
HELM_ARGS+=(--set-string application.config.codecanvas.jump.jwtPublicKey="$jump_jwt_public_key")
HELM_ARGS+=(--set-string application.config.codecanvas.jump.hostPublicKey="$jump_public_host_key")
HELM_ARGS+=(--set-string relay.application.secret.relayJwtPublicKey="$relay_public_key")
HELM_ARGS+=(--set-string jump.application.secret.jump.JUMP_SSH_HOST_KEY="$jump_private_host_key")
HELM_ARGS+=(--set-string jump.application.secret.jump.JUMP_JWT_PRIVATE_KEY="$jump_jwt_private_key")
HELM_ARGS+=(--set-string operator.operator.secret.jwtPrivateKey="$jump_jwt_private_key")
HELM_ARGS+=(--set-string "application.config.codecanvas.execution.k8s.operator.preloadConfiguration.jwtPublicKey=$jump_jwt_public_key")

status "$HELM_INSTALL_MESSAGE"
helm upgrade --install spaceport "$HELM_CHART" \
 -n "kube-space" \
 --set-string application.config.codecanvas.rd.devContainerImage.tag="${DEV_CONTAINER_TAG:-latest}" \
 --wait \
 --timeout 15m \
  "${HELM_ARGS[@]}" \
  $HELM_ADDITIONAL_ARGS

status "* Chart installed within [${SECONDS}s]"

if [[ -n "${WAIT_HEALTHY}" ]]; then
    status "Waiting for CodeCanvas server availability"
    "$script_dir/../wait-healthcheck.sh" http://jetbrains.local/health
fi
