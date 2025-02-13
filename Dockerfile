FROM docker:27.5.1-cli-alpine3.21

WORKDIR /app/kind-bootstrapper

COPY ./src .
COPY ./install-kubectl.sh .
COPY ./install-kind.sh .

ENV KUBE_DIR="/app/kind-bootstrapper/kube"
ENV KUBECONFIG="${KUBE_DIR}/codecanvas.config"

RUN mkdir -p $KUBE_DIR
VOLUME $KUBE_DIR

# hadolint ignore=DL3018,DL3003,SC2035
RUN apk add bash --no-cache &&\
    apk add openssl --no-cache && \
    apk add curl --no-cache && \
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh && \
    rm -f get_helm.sh

RUN /app/kind-bootstrapper/install-kind.sh
RUN /app/kind-bootstrapper/install-kubectl.sh

ENTRYPOINT ["./cc-up.sh"]


