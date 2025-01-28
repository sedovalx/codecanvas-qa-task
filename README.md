# Quickstart w/ Docker

## Requirements

### Hardware
* at least 60+GB free space
* at least 16+GB RAM
* stable and fast enough (200+MB/s) internet connection

### Software
* docker (non rootless)

## Steps
1. Add the following domains into `/etc/hosts`
    ```
    127.0.0.1 jetbrains.local
    127.0.0.1 jump.jetbrains.local
    127.0.0.1 gateway-relay.jetbrains.local
    ```
2. Run
    ```
    docker run --rm -v "$(pwd)/kubedir:/app/kind-bootstrapper/kube" \
      -v /var/run/docker.sock:/var/run/docker.sock \
      --network host  \
      ghcr.io/sedovalx/codecanvas-qa-task/codecanvas-up:latest \
      --chart-url oci://registry.jetbrains.team/p/rdo/nightly-charts/codecanvas --chart-version 2025.1-RC.875
    ```
3. Run `export KUBECONFIG=./kubedir/codecanvas.config` in the same directory if you want to access cluster via kubectl
4. Open http://jetbrains.local. Username/password is `admin`

# Quickstart w/o Docker

## Requirements

### Hardware
* at least 60+GB free space
* at least 16+GB RAM
* stable and fast enough (200+MB/s) internet connection

### Software
* docker (non rootless)
* kind
* helm 3.14+
* openssl
* curl

## Steps
1. Add the following domains into `/etc/hosts`
    ```
    127.0.0.1 jetbrains.local
    127.0.0.1 jump.jetbrains.local
    127.0.0.1 gateway-relay.jetbrains.local
    ```
2. Run `cc-up.sh --chart-url oci://registry.jetbrains.team/p/rdo/nightly-charts/codecanvas --chart-version 2025.1-RC.875` in the src directory.
3. Open http://jetbrains.local. Username/password is `admin`


# TODO
1. Publish the current nightly chart to a public registry
2. Publish corresponding docker images to a public registry
