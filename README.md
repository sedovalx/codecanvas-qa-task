# CodeCanvas w/ Kind
This guide explains how to run a [CodeCanvas](https://www.jetbrains.com/codecanvas/) instance on the local machine. In the final result, application serices and dev environments will be run on the same local machine (not in a cloud).

DON'T TRY TO USE FOR DEMO OR PRODUCTION USE CASES! The intended usage of such installation type is purely for testing and debugging purposes. 

CodeCanvas is meant to be installed in k8s, and [Kind](https://kind.sigs.k8s.io/) is a simplified version of k8s. There might be other options for a "local" k8s, this guide focuses on the option with Kind.

## Requirements for the local machine
- MacOS or Linux. Or, WSL for Windows.
- Latest Docker. E.g. [Docker Desktop](https://www.docker.com/products/docker-desktop/) 4.37.2.
- (optional) Locally installed [Kind](https://kind.sigs.k8s.io/). It is not needed for the installation, but is necessary for the cleanup purposes later.
- (optional) [kubectl](https://kubernetes.io/docs/tasks/tools/) CLI. It is not needed for the installation, but might be useful to check the state of the k8s pods in case of problems.
- At least 40 GB of the disk space allocated for Docker
- At least 16 GB RAM allocated for Docker
- At least 8 CPU allocated for Docker
- [JetBrains Gateway](https://www.jetbrains.com/remote-development/gateway/). It is not needed for the installation but is necessary later to connect to started dev environments.
- At least 40-60 MB/S Internet connection. Likely everything will work with a lesser speed but there might be errors because of timeouts for downloading processes.

## Installation
- Add the following domains into `/etc/hosts`
    ```
    127.0.0.1 jetbrains.local
    127.0.0.1 jump.jetbrains.local
    127.0.0.1 gateway-relay.jetbrains.local
    ```
- Execute
  ```
  time docker run --rm -v "$(pwd)/kubedir:/app/kind-bootstrapper/kube" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --network host  \
    ghcr.io/sedovalx/codecanvas-qa-task/codecanvas-up:latest \
    --chart-url oci://registry.jetbrains.team/p/rdo/nightly-charts/codecanvas --chart-version 2025.1-RC.875
  ```
  With 40-60 MB/S the installation may take up to 10 minutes. As a sign of a success, you will see `* Chart installed within [Xs]` in the output.
- In the terminal, in the same folder where the previous command was run, execute `export KUBECONFIG=./kubedir/codecanvas.config` to configure `kubectl` to use the newly created Kind cluster.
- Inspect the installation result. Execute `docker container ls --format 'table {{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}\t{{.Networks}}'` in the terminal. The expected result should be something like the following
  ```
  CONTAINER ID   NAMES                          PORTS                                                                                           STATUS          NETWORKS
  fbb0fee2517b   kind-registry                  127.0.0.1:5001->5000/tcp                                                                        Up 31 minutes   bridge,kind
  66940d9b22f7   spaceport-kind-control-plane   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp, 0.0.0.0:63101->63101/tcp, 127.0.0.1:57023->6443/tcp   Up 32 minutes   kind
  6bfe95d00921   spaceport-kind-worker2                                                                                                         Up 32 minutes   kind
  57d2b87f41f3   spaceport-kind-worker5                                                                                                         Up 32 minutes   kind
  d74035ab4e41   spaceport-kind-worker                                                                                                          Up 32 minutes   kind
  aebc52726ec8   spaceport-kind-worker3                                                                                                         Up 32 minutes   kind
  c304a3ee2446   spaceport-kind-worker4                                                                                                         Up 32 minutes   kind
  ```
  This is the components of the Kind cluster. Application pods are running inside those kind worker nodes.
- Inspect the state of the application services. Execute `kubectl get pods -n kube-space` in the same folder where you did `export KUBECONFIG=./kubedir/codecanvas.config`. The expected result should be similar to the following
  ```
  NAME                                      READY   STATUS      RESTARTS      AGE
  canvas-deps-minio-5b8ccb59dd-nx26k        1/1     Running     0             35m
  canvas-deps-minio-provisioning-5mzwm      0/1     Completed   1             35m
  canvas-deps-postgresql-0                  1/1     Running     0             35m
  jump-68565848b6-fdwrf                     1/1     Running     0             34m
  operator-spaceport-rde-68569d7bff-n4jcs   1/1     Running     3 (32m ago)   34m
  redis-master-0                            1/1     Running     0             34m
  relay-6594c7c4bc-fp7x9                    1/1     Running     0             34m
  spaceport-app-6557684d5-4nnhh             1/1     Running     0             34m
  ```
- Open http://jetbrains.local. Username/password is `admin`.
- Apply the license key that you got along with the task description.
- The installation is ready

## Troubleshooting
- Check the logs of the application backend
  ```
  kubectl logs spaceport-app-6cbc7554c9-88f6s -n kube-space -f
  ```
- Check k8s pods of dev environments
  ```
  k get pods -n spaceport-rde
  ```

## Known issues
- You will see "Problem found" near the instance type of your dev environments. That's a limitation of the local CodeCanvas run related to health checks in Kind. Please ignore that.
  <img width="300" alt="image" src="https://github.com/user-attachments/assets/6a0e7fb1-3b06-400c-9047-35e3a49925c8" />
- Depending on the Internet speed, warmup run for the spring-petclinic repo may take up to 20 minutes, dev environment start w/o warmup may take up to 10 minutes, and dev environment start w/ warmup may take up to 3 minutes. 

## Cleanup
When you don't need the installation and the Kind cluster anymore we recommend deleting it because it consumes resources of the local machine in the active state:
- Delete the kind cluster. The application will be deleted with it.
  ```
  kind delete cluster --name spaceport-kind
  ```
- Delete the `kind-registry` container
  ```
  docker container rm --force kind-registry
  ```
- Inspect and delete related docker images
- Remove the lines in `/etc/hosts`
