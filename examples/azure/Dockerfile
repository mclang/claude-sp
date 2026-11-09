FROM python:3.14-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates git unzip \
    && rm -rf /var/lib/apt/lists/*

# Root-owned: Claude can't modify the tools it uses
RUN pip install --no-cache-dir azure-cli==2.92.0

# Release asset names use amd64/arm64, except kubectx/kubens: x86_64/arm64
ARG KUBECTL_VERSION=1.37.2
ARG HELM_VERSION=4.3.1
ARG K9S_VERSION=0.51.0
ARG KUBECTX_VERSION=0.11.0
ARG KUBELOGIN_VERSION=0.2.22

RUN ARCH=$(dpkg --print-architecture) \
    && KX_ARCH=${ARCH/amd64/x86_64} \
    && cd /usr/local/bin \
    && curl -fsSLo kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
    && chmod +x kubectl \
    && curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${ARCH}.tar.gz" | tar -xz --strip-components=1 "linux-${ARCH}/helm" \
    && curl -fsSL "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_${ARCH}.tar.gz" | tar -xz k9s \
    && for t in kubectx kubens; do \
        curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/${t}_v${KUBECTX_VERSION}_linux_${KX_ARCH}.tar.gz" | tar -xz "$t"; \
    done \
    && curl -fsSLo /tmp/kubelogin.zip "https://github.com/Azure/kubelogin/releases/download/v${KUBELOGIN_VERSION}/kubelogin-linux-${ARCH}.zip" \
    && unzip -j /tmp/kubelogin.zip "bin/linux_${ARCH}/kubelogin" -d . \
    && rm /tmp/kubelogin.zip

