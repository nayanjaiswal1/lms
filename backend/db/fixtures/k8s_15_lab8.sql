-- ════════════════════════════════════════════════════════════════════════════
-- k8s_15_lab8.sql — Lab 8: etcd Backup, Cluster Upgrade & Node Lifecycle
-- Module: 000000084002 (Master course, Section 4, Module 2)
-- 6 tasks, lab ID: 000000090008, version ID: 000000099008
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO lab_definitions (
  id, org_id, course_id, module_id, scope, title, description,
  lab_type, environment, setup_script,
  max_duration, max_resets, hint_penalty_pct, is_required, is_published,
  published_version_id, created_by
) VALUES (
  '00000000-0000-0000-0000-000000090008',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000080000',
  '00000000-0000-0000-0000-000000084002',
  'module',
  'etcd Backup, Cluster Upgrade & Node Lifecycle',
  'CKA exam essentials: take an etcd snapshot backup, verify its integrity, cordon and drain a worker node, perform a kubeadm upgrade on the control plane, and restore normal scheduling by uncordoning. All tasks use the exact commands from the CKA exam.',
  'terminal', 'mindforge/lab-k8s:1.31',
  '#!/bin/bash
mkdir -p /backup >/dev/null 2>&1 || true
kubectl delete namespace lifecycle-test --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create namespace lifecycle-test >/dev/null 2>&1 || true
kubectl create deployment test-app --image=nginx:1.27 --replicas=3 -n lifecycle-test >/dev/null 2>&1 || true',
  100, 3, 10, true, false, NULL,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
(
  '00000000-0000-0000-0000-000000098001',
  '00000000-0000-0000-0000-000000090008', 1,
  'Take an etcd snapshot backup',
  'Use `etcdctl` to take a snapshot of the etcd cluster and save it to `/backup/etcd-snapshot.db`. Use the certificate files from `/etc/kubernetes/pki/etcd/`.',
  '#!/bin/bash
test -f /backup/etcd-snapshot.db && test -s /backup/etcd-snapshot.db',
  'Command: `ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt --key=/etc/kubernetes/pki/etcd/healthcheck-client.key`',
  'etcdctl requires ETCDCTL_API=3 to use etcd v3 API. The --endpoints must point to the actual etcd server (default: https://127.0.0.1:2379 for kubeadm). The CA cert verifies the server; the client cert/key authenticate the client. kubeadm etcd certs are in /etc/kubernetes/pki/etcd/.',
  25, false, false
),
(
  '00000000-0000-0000-0000-000000098002',
  '00000000-0000-0000-0000-000000090008', 2,
  'Verify the etcd snapshot integrity',
  'Run `etcdctl snapshot status` on the backup file to verify it is not corrupted. The output must show a valid revision number greater than 0.',
  '#!/bin/bash
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-snapshot.db \
  --write-out=json 2>/dev/null | grep -q revision',
  'Command: `ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-snapshot.db --write-out=table`. Check the "Revision" column shows a non-zero value.',
  'snapshot status reads the snapshot header and reports: hash, revision (etcd revision number at snapshot time), total keys, total size. A revision of 0 or parse errors indicate a corrupt backup. Always verify backups before relying on them for disaster recovery.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000098003',
  '00000000-0000-0000-0000-000000090008', 3,
  'Cordon the worker node to prevent new scheduling',
  'Cordon the cluster''s worker node (any non-control-plane node) to mark it unschedulable. New pods must not be scheduled on it, but existing pods continue running.',
  '#!/bin/bash
WORKER=$(kubectl get nodes --no-headers \
  --selector=''!node-role.kubernetes.io/control-plane'' \
  -o jsonpath=''{.items[0].metadata.name}'' 2>/dev/null)
test -n "$WORKER" && \
kubectl get node "$WORKER" -o jsonpath=''{.spec.unschedulable}'' | grep -q true',
  'Get worker node name: `kubectl get nodes`. Then: `kubectl cordon <node-name>`. Verify: `kubectl get nodes` shows "SchedulingDisabled" status.',
  'cordon adds the node.kubernetes.io/unschedulable taint and sets node.spec.unschedulable=true. The scheduler skips cordoned nodes for new pods. Existing pods are NOT evicted — use drain for that. cordon is reversible with `kubectl uncordon`.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000098004',
  '00000000-0000-0000-0000-000000090008', 4,
  'Drain the worker node (evict all pods)',
  'Drain the cordoned worker node to evict all non-DaemonSet, non-static pods. Use `--ignore-daemonsets --delete-emptydir-data`. The test-app Deployment pods must reschedule to the control plane (or remaining nodes).',
  '#!/bin/bash
WORKER=$(kubectl get nodes --no-headers \
  --selector=''!node-role.kubernetes.io/control-plane'' \
  -o jsonpath=''{.items[0].metadata.name}'' 2>/dev/null)
test -n "$WORKER" && \
kubectl get node "$WORKER" -o jsonpath=''{.spec.unschedulable}'' | grep -q true',
  'Command: `kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --force`. The --force flag handles standalone pods (no controller). Monitor with `kubectl get pods -n lifecycle-test -o wide`.',
  'drain = cordon + evict all eligible pods. DaemonSet pods are skipped (--ignore-daemonsets). Pods using emptyDir are warned about data loss (--delete-emptydir-data confirms). Pods backed by controllers (Deployment, StatefulSet) are rescheduled; standalone pods are deleted permanently.',
  20, false, true
),
(
  '00000000-0000-0000-0000-000000098005',
  '00000000-0000-0000-0000-000000090008', 5,
  'Upgrade kubeadm on the control plane node',
  'Upgrade the `kubeadm` binary on the control plane node to the next patch version. Run `kubeadm upgrade plan` to see available versions, then apply the upgrade.',
  '#!/bin/bash
kubeadm version -o short 2>/dev/null | grep -qE "v1\.[0-9]+\.[0-9]+"',
  'Check available versions: `kubeadm upgrade plan`. Then: `apt-get update && apt-get install -y kubeadm=<version>`. Apply: `kubeadm upgrade apply <version>`. Finally upgrade kubelet: `apt-get install -y kubelet=<version> kubectl=<version> && systemctl restart kubelet`.',
  'kubeadm upgrade apply upgrades: kube-apiserver, kube-controller-manager, kube-scheduler, kube-proxy, CoreDNS, and etcd. It does NOT upgrade kubelet — that must be done manually. Kubelet upgrade requires `systemctl restart kubelet` after apt install.',
  20, false, false
),
(
  '00000000-0000-0000-0000-000000098006',
  '00000000-0000-0000-0000-000000090008', 6,
  'Uncordon the worker node and verify pods reschedule',
  'Uncordon the previously drained worker node to re-enable scheduling. Verify that the test-app Deployment scales back and distributes pods across nodes.',
  '#!/bin/bash
WORKER=$(kubectl get nodes --no-headers \
  --selector=''!node-role.kubernetes.io/control-plane'' \
  -o jsonpath=''{.items[0].metadata.name}'' 2>/dev/null)
test -n "$WORKER" && \
SCHED=$(kubectl get node "$WORKER" \
  -o jsonpath=''{.spec.unschedulable}'' 2>/dev/null) && \
test -z "$SCHED" || test "$SCHED" = "false"',
  'Command: `kubectl uncordon <node-name>`. Verify: `kubectl get nodes` shows Ready (not SchedulingDisabled). Watch pod redistribution: `kubectl get pods -n lifecycle-test -o wide`.',
  'uncordon removes the node.kubernetes.io/unschedulable taint and sets spec.unschedulable=false. The scheduler resumes using the node for new pods. Existing pods are NOT automatically moved back — only new/rescheduled pods will land on the uncordoned node.',
  15, false, false
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES (
  '00000000-0000-0000-0000-000000099008',
  '00000000-0000-0000-0000-000000090008',
  1,
  $json$[
    {"id":"00000000-0000-0000-0000-000000098001","lab_id":"00000000-0000-0000-0000-000000090008","position":1,"title":"Take an etcd snapshot backup","description":"Save etcd snapshot to /backup/etcd-snapshot.db using etcdctl with TLS certs.","verification_script":"#!/bin/bash\ntest -f /backup/etcd-snapshot.db && test -s /backup/etcd-snapshot.db","hint_context":"ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=... --key=...","explanation_context":"etcdctl snapshot save creates a point-in-time consistent snapshot of the etcd cluster state","points":25,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000098002","lab_id":"00000000-0000-0000-0000-000000090008","position":2,"title":"Verify the etcd snapshot integrity","description":"Run etcdctl snapshot status on /backup/etcd-snapshot.db to verify it shows a valid revision.","verification_script":"#!/bin/bash\nETCDCTL_API=3 etcdctl snapshot status /backup/etcd-snapshot.db --write-out=json 2>/dev/null | grep -q revision","hint_context":"ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-snapshot.db --write-out=table","explanation_context":"snapshot status verifies the backup header and reports revision, key count, and size","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000098003","lab_id":"00000000-0000-0000-0000-000000090008","position":3,"title":"Cordon the worker node to prevent new scheduling","description":"Cordon the worker node to mark it unschedulable without evicting existing pods.","verification_script":"#!/bin/bash\nWORKER=$(kubectl get nodes --no-headers --selector='!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)\ntest -n \"$WORKER\" && kubectl get node \"$WORKER\" -o jsonpath='{.spec.unschedulable}' | grep -q true","hint_context":"kubectl get nodes to find worker node name; kubectl cordon <node-name>","explanation_context":"cordon marks node unschedulable; existing pods continue running, no new pods scheduled","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000098004","lab_id":"00000000-0000-0000-0000-000000090008","position":4,"title":"Drain the worker node (evict all pods)","description":"Drain the worker node with --ignore-daemonsets --delete-emptydir-data to evict all pods.","verification_script":"#!/bin/bash\nWORKER=$(kubectl get nodes --no-headers --selector='!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)\ntest -n \"$WORKER\" && kubectl get node \"$WORKER\" -o jsonpath='{.spec.unschedulable}' | grep -q true","hint_context":"kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --force","explanation_context":"drain = cordon + evict; DaemonSet pods skipped; controller-backed pods rescheduled elsewhere","points":20,"is_optional":false,"is_stateful":true},
    {"id":"00000000-0000-0000-0000-000000098005","lab_id":"00000000-0000-0000-0000-000000090008","position":5,"title":"Upgrade kubeadm on the control plane node","description":"Upgrade kubeadm binary and run kubeadm upgrade apply to upgrade control plane components.","verification_script":"#!/bin/bash\nkubeadm version -o short 2>/dev/null | grep -qE 'v1\\.[0-9]+\\.[0-9]+'","hint_context":"apt-get install kubeadm=<version>; kubeadm upgrade apply <version>; then upgrade kubelet+kubectl","explanation_context":"kubeadm upgrade apply updates apiserver, scheduler, controller-manager, CoreDNS, etcd but NOT kubelet","points":20,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000098006","lab_id":"00000000-0000-0000-0000-000000090008","position":6,"title":"Uncordon the worker node and verify pods reschedule","description":"Uncordon the worker node to re-enable pod scheduling.","verification_script":"#!/bin/bash\nWORKER=$(kubectl get nodes --no-headers --selector='!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)\ntest -n \"$WORKER\" && SCHED=$(kubectl get node \"$WORKER\" -o jsonpath='{.spec.unschedulable}' 2>/dev/null) && test -z \"$SCHED\" || test \"$SCHED\" = \"false\"","hint_context":"kubectl uncordon <node-name>; verify with kubectl get nodes","explanation_context":"uncordon re-enables scheduling; existing pods are not moved back automatically","points":15,"is_optional":false,"is_stateful":false}
  ]$json$::jsonb,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

UPDATE lab_definitions
SET is_published = true, published_version_id = '00000000-0000-0000-0000-000000099008', updated_at = now()
WHERE id = '00000000-0000-0000-0000-000000090008'
  AND published_version_id IS NULL;
