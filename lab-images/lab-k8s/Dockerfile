# mindforge/lab-k8s — Kubernetes fundamentals lab sandbox.
#
# Runs a real control plane (etcd, kube-apiserver, kube-controller-manager,
# kube-scheduler) with kwok (sigs.k8s.io/kwok) standing in for the kubelet
# layer. kwok simulates node/pod Running status without a nested container
# runtime, so this image needs no extra Linux capabilities beyond what every
# other lab image already gets (cap-drop ALL, no privileged mode, no Docker
# socket) — see backend/internal/labs/container.go. Deployment -> ReplicaSet
# -> Pod reconciliation and scheduling are genuine; only the "a real container
# process is running inside the pod" part is simulated.
FROM ubuntu:24.04

ARG KUBE_VERSION=v1.31.14
ARG ETCD_VERSION=v3.5.31
ARG KWOK_VERSION=v0.8.0
ARG TARGETARCH=amd64

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash curl ca-certificates ttyd openssl \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
    && curl -fsSL -o /usr/local/bin/kube-apiserver \
      "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${TARGETARCH}/kube-apiserver" \
    && curl -fsSL -o /usr/local/bin/kube-controller-manager \
      "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${TARGETARCH}/kube-controller-manager" \
    && curl -fsSL -o /usr/local/bin/kube-scheduler \
      "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${TARGETARCH}/kube-scheduler" \
    && curl -fsSL -o /usr/local/bin/kwok \
      "https://github.com/kubernetes-sigs/kwok/releases/download/${KWOK_VERSION}/kwok-linux-${TARGETARCH}" \
    && curl -fsSL "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-${TARGETARCH}.tar.gz" \
      -o /tmp/etcd.tar.gz \
    && tar xzf /tmp/etcd.tar.gz -C /tmp \
    && mv "/tmp/etcd-${ETCD_VERSION}-linux-${TARGETARCH}/etcd" /usr/local/bin/ \
    && mv "/tmp/etcd-${ETCD_VERSION}-linux-${TARGETARCH}/etcdctl" /usr/local/bin/ \
    && rm -rf /tmp/etcd* \
    && chmod +x /usr/local/bin/kubectl /usr/local/bin/kube-apiserver \
      /usr/local/bin/kube-controller-manager /usr/local/bin/kube-scheduler \
      /usr/local/bin/kwok /usr/local/bin/etcd /usr/local/bin/etcdctl

# kwok has no built-in lifecycle logic: it needs explicit Stage definitions
# describing how to move Nodes/Pods through their lifecycle, loaded from local
# config files via --config. These are kwok's own upstream default "fast"
# stage manifests — the same ones kwokctl applies for a standard kwok cluster.
RUN mkdir -p /etc/kubernetes/kwok-stages \
    && curl -fsSL -o /etc/kubernetes/kwok-stages/node-initialize.yaml \
      "https://raw.githubusercontent.com/kubernetes-sigs/kwok/${KWOK_VERSION}/kustomize/stage/node/fast/node-initialize.yaml" \
    && curl -fsSL -o /etc/kubernetes/kwok-stages/pod-ready.yaml \
      "https://raw.githubusercontent.com/kubernetes-sigs/kwok/${KWOK_VERSION}/kustomize/stage/pod/fast/pod-ready.yaml" \
    && curl -fsSL -o /etc/kubernetes/kwok-stages/pod-complete.yaml \
      "https://raw.githubusercontent.com/kubernetes-sigs/kwok/${KWOK_VERSION}/kustomize/stage/pod/fast/pod-complete.yaml" \
    && curl -fsSL -o /etc/kubernetes/kwok-stages/pod-delete.yaml \
      "https://raw.githubusercontent.com/kubernetes-sigs/kwok/${KWOK_VERSION}/kustomize/stage/pod/fast/pod-delete.yaml"

RUN useradd --create-home --shell /bin/bash labuser \
    && mkdir -p /var/lib/etcd /var/run/kubernetes /etc/kubernetes/pki /var/log/mindforge-lab \
    && chown -R labuser:labuser /var/lib/etcd /var/run/kubernetes /etc/kubernetes /home/labuser /var/log/mindforge-lab

COPY fake-node.yaml /etc/kubernetes/fake-node.yaml
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 644 /etc/kubernetes/fake-node.yaml /etc/kubernetes/kwok-stages/*.yaml \
    && chmod +x /usr/local/bin/entrypoint.sh

# The readiness contract the backend polls (labs.ReadinessProbePath): exit 0
# once this sandbox is usable, non-zero while it is still booting. An image
# without this file is treated as ready immediately, so only images with
# background services need one. entrypoint.sh writes the marker as its last
# act before handing off to ttyd.
RUN printf '#!/bin/sh\n[ -f /tmp/lab-ready ]\n' > /usr/local/bin/lab-ready \
    && chmod +x /usr/local/bin/lab-ready

ENV KUBECONFIG=/etc/kubernetes/admin.kubeconfig
EXPOSE 7681

# The whole control plane runs as labuser — cap-drop ALL (applied uniformly to
# every lab container by ContainerService.Start) strips CAP_SETUID even from
# root, so nothing inside the container can setuid() at runtime. Docker sets
# the initial process UID from this directive before that restriction applies,
# which is the only way to get a non-root PID 1 here. None of etcd,
# kube-apiserver, kube-controller-manager, kube-scheduler, or kwok need root.
USER labuser

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
