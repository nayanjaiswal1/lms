#!/bin/bash
set -euo pipefail

export KUBECONFIG=/etc/kubernetes/admin.kubeconfig
PKI_DIR=/etc/kubernetes/pki
LOG_DIR=/var/log/mindforge-lab

log() { echo "[entrypoint] $*"; }

# Retries `kubectl apply` against a path until it succeeds or attempts run
# out. Needed because a freshly-created CRD (e.g. kwok's Stage type) takes a
# moment before the apiserver routes requests for it, so a Stage instance
# applied in the same breath as its CRD can transiently 404.
apply_retry() {
  local path="$1" logfile="$2" attempts="$3"
  for _ in $(seq 1 "$attempts"); do
    if kubectl apply -f "$path" >"$logfile" 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

log "generating PKI: CA, admin client cert, service-account signing key"
mkdir -p "$PKI_DIR"
openssl genrsa -out "$PKI_DIR/ca.key" 2048 >/dev/null 2>&1
openssl req -x509 -new -nodes -key "$PKI_DIR/ca.key" -subj "/CN=mindforge-lab-ca" \
  -days 1 -out "$PKI_DIR/ca.crt" >/dev/null 2>&1
openssl genrsa -out "$PKI_DIR/admin.key" 2048 >/dev/null 2>&1
openssl req -new -key "$PKI_DIR/admin.key" -subj "/CN=admin/O=system:masters" \
  -out "$PKI_DIR/admin.csr" >/dev/null 2>&1
openssl x509 -req -in "$PKI_DIR/admin.csr" -CA "$PKI_DIR/ca.crt" -CAkey "$PKI_DIR/ca.key" \
  -CAcreateserial -out "$PKI_DIR/admin.crt" -days 1 >/dev/null 2>&1
openssl genrsa -out "$PKI_DIR/sa.key" 2048 >/dev/null 2>&1
openssl rsa -in "$PKI_DIR/sa.key" -pubout -out "$PKI_DIR/sa.pub" >/dev/null 2>&1

log "writing admin kubeconfig"
kubectl config set-cluster kwok-lab --server=https://127.0.0.1:6443 \
  --insecure-skip-tls-verify=true >/dev/null
kubectl config set-credentials admin \
  --client-certificate="$PKI_DIR/admin.crt" --client-key="$PKI_DIR/admin.key" \
  --embed-certs=true >/dev/null
kubectl config set-context kwok-lab --cluster=kwok-lab --user=admin --namespace=default >/dev/null
kubectl config use-context kwok-lab >/dev/null
chmod 644 "$KUBECONFIG"

log "starting etcd"
etcd \
  --data-dir=/var/lib/etcd \
  --listen-client-urls=http://127.0.0.1:2379 \
  --advertise-client-urls=http://127.0.0.1:2379 \
  --listen-peer-urls=http://127.0.0.1:2380 \
  >$LOG_DIR/etcd.log 2>&1 &

log "starting kube-apiserver"
kube-apiserver \
  --etcd-servers=http://127.0.0.1:2379 \
  --bind-address=127.0.0.1 \
  --secure-port=6443 \
  --cert-dir=/var/run/kubernetes \
  --client-ca-file="$PKI_DIR/ca.crt" \
  --authorization-mode=AlwaysAllow \
  --disable-admission-plugins=ServiceAccount,TaintNodesByCondition \
  --allow-privileged=true \
  --service-cluster-ip-range=10.96.0.0/16 \
  --service-account-issuer=https://kubernetes.default.svc \
  --service-account-key-file="$PKI_DIR/sa.pub" \
  --service-account-signing-key-file="$PKI_DIR/sa.key" \
  >$LOG_DIR/kube-apiserver.log 2>&1 &

log "waiting for kube-apiserver readiness"
ready=""
for _ in $(seq 1 60); do
  if kubectl get --raw=/readyz >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [ -z "$ready" ]; then
  log "kube-apiserver never became ready; last log lines:"
  tail -n 40 $LOG_DIR/kube-apiserver.log || true
  exit 1
fi
log "kube-apiserver ready"

log "starting kube-controller-manager"
kube-controller-manager \
  --kubeconfig=/etc/kubernetes/admin.kubeconfig \
  --leader-elect=false \
  --use-service-account-credentials=false \
  --controllers=deployment,replicaset,namespace,endpoint,endpointslice,endpointslicemirroring,resourcequota,garbagecollector \
  >$LOG_DIR/kube-controller-manager.log 2>&1 &

log "starting kube-scheduler"
kube-scheduler \
  --kubeconfig=/etc/kubernetes/admin.kubeconfig \
  --leader-elect=false \
  >$LOG_DIR/kube-scheduler.log 2>&1 &

log "registering fake kwok node"
if ! apply_retry /etc/kubernetes/fake-node.yaml "$LOG_DIR/kwok-node-apply.log" 30; then
  log "failed to register fake node; last log lines:"
  tail -n 40 "$LOG_DIR/kwok-node-apply.log" || true
  exit 1
fi

log "starting kwok"
kwok \
  --kubeconfig=/etc/kubernetes/admin.kubeconfig \
  --config=/etc/kubernetes/kwok-stages/node-initialize.yaml \
  --config=/etc/kubernetes/kwok-stages/pod-ready.yaml \
  --config=/etc/kubernetes/kwok-stages/pod-complete.yaml \
  --config=/etc/kubernetes/kwok-stages/pod-delete.yaml \
  --manage-nodes-with-annotation-selector=kwok.x-k8s.io/node=fake \
  --node-lease-duration-seconds=40 \
  --cidr=10.0.0.1/24 \
  >$LOG_DIR/kwok.log 2>&1 &

log "starting ttyd"
exec ttyd -W -p 7681 bash
