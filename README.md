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
      ghcr.io/sedovalx/codecanvas-qa-task/codecanvas-up:latest codecanvas-up
    ```
3. Run `export KUBECONFIG=./kubedir/codecanvas.config` in the same directory if you want to access cluster via kubectl
4. Open http://jetbrains.local. Username/password is `admin`
5. To shut down the cluster run
    ```
    docker run --rm -v "$(pwd)/kubedir:/app/kind-bootstrapper/kube" \
      -v /var/run/docker.sock:/var/run/docker.sock \
      --network host  \
      ghcr.io/sedovalx/codecanvas-qa-task/codecanvas-up:latest codecanvas-down
    ```

If the installation process doesn't go well and you want to repeat, there is cleanup to be done. You need to install [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) locally and execute to delete the Kind cluster that was created locally during the installation.
```
kind delete cluster --name spaceport-kind
```

# Quickstart w/o Docker (disregard)

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
2. Run `codecanvas-up` in the src directory.
3. Open http://jetbrains.local. Username/password is `admin`
