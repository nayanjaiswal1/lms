-- ════════════════════════════════════════════════════════════════════════════
-- k8s_07_courses.sql — 2 courses, 8 sections, 24 modules
-- Module layout per section: M1=notes, M2=lab (type='lab'), M3=assessment
-- Assessments must exist before modules (FK: course_modules.assessment_id).
-- ════════════════════════════════════════════════════════════════════════════

-- ─── Course 1: Kubernetes Advanced ───────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, difficulty, tags, status, is_free, estimated_hours)
VALUES (
  '00000000-0000-0000-0000-000000070000',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000012',
  'Kubernetes Advanced: Workloads, Networking & Storage',
  'kubernetes-advanced',
  'A hands-on advanced course covering Kubernetes workloads, networking deep-dives, storage strategies, and configuration management. Each section pairs a notes module with a terminal lab and a graded quiz.',
  'advanced',
  ARRAY['kubernetes','k8s','devops','containers','advanced'],
  'published', false, 12.0
) ON CONFLICT (id) DO NOTHING;

-- ─── Course 2: Kubernetes Master ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, difficulty, tags, status, is_free, estimated_hours)
VALUES (
  '00000000-0000-0000-0000-000000080000',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000012',
  'Kubernetes Master: CKA Exam Prep & Production Operations',
  'kubernetes-master',
  'Expert-level course covering cluster administration, advanced networking with eBPF and NetworkPolicies, production observability, and CKA exam preparation including etcd backup/restore and cluster upgrades.',
  'expert',
  ARRAY['kubernetes','k8s','cka','production','expert','etcd','rbac'],
  'published', false, 16.0
) ON CONFLICT (id) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- Sections — Advanced Course (4 sections)
-- UNIQUE (course_id, position) is DEFERRABLE INITIALLY DEFERRED — safe to batch.
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO course_sections (id, course_id, title, position) VALUES
  ('00000000-0000-0000-0000-000000071000','00000000-0000-0000-0000-000000070000','Kubernetes Fundamentals',0),
  ('00000000-0000-0000-0000-000000072000','00000000-0000-0000-0000-000000070000','Workloads & Controllers',1),
  ('00000000-0000-0000-0000-000000073000','00000000-0000-0000-0000-000000070000','Networking & Services',2),
  ('00000000-0000-0000-0000-000000074000','00000000-0000-0000-0000-000000070000','Storage & Configuration',3)
ON CONFLICT (id) DO NOTHING;

-- ────────────────────────────────────────────────────────────────────────────
-- Sections — Master Course (4 sections)
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO course_sections (id, course_id, title, position) VALUES
  ('00000000-0000-0000-0000-000000081000','00000000-0000-0000-0000-000000080000','Cluster Administration & Security',0),
  ('00000000-0000-0000-0000-000000082000','00000000-0000-0000-0000-000000080000','Advanced Networking & Network Policies',1),
  ('00000000-0000-0000-0000-000000083000','00000000-0000-0000-0000-000000080000','Observability, Logging & Troubleshooting',2),
  ('00000000-0000-0000-0000-000000084000','00000000-0000-0000-0000-000000080000','CKA Exam Prep & Cluster Lifecycle',3)
ON CONFLICT (id) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- Modules — Advanced Course
-- Section 1: Fundamentals
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, content_body) VALUES
  ('00000000-0000-0000-0000-000000071001','00000000-0000-0000-0000-000000070000','00000000-0000-0000-0000-000000071000',
   'Kubernetes Architecture & Pod Internals','notes',0,45,
   '# Kubernetes Architecture Deep Dive

## Control Plane Components
- **kube-apiserver** — the REST gateway; all state flows through it; horizontally scalable
- **etcd** — distributed KV store; only the apiserver talks to it; snapshot for backup
- **kube-scheduler** — watches unscheduled pods, ranks nodes, binds pod to node
- **kube-controller-manager** — runs all built-in controllers (ReplicaSet, Endpoint, Node, etc.) as goroutines

## Node Components
- **kubelet** — registers node, watches PodSpec from apiserver, manages container lifecycle via CRI
- **kube-proxy** — programs iptables/IPVS for Service VIP routing
- **Container Runtime** — implements CRI (containerd, CRI-O); actually runs containers

## Pod Internals
A Pod is a group of containers sharing:
- Network namespace (same IP, localhost communication)
- IPC namespace (shared memory, semaphores)
- Optional: PID namespace, UTS namespace

**Pause container** (infra container) holds the network and IPC namespaces; app containers join them.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes) VALUES
  ('00000000-0000-0000-0000-000000071002','00000000-0000-0000-0000-000000070000','00000000-0000-0000-0000-000000071000',
   'Lab: Deploy Your First Pod','lab',1,60)
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id) VALUES
  ('00000000-0000-0000-0000-000000071003','00000000-0000-0000-0000-000000070000','00000000-0000-0000-0000-000000071000',
   'Quiz: Kubernetes Fundamentals','assessment',2,25,'00000000-0000-0000-0000-000000060001')
ON CONFLICT (id) DO NOTHING;

-- Section 2: Workloads
INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, content_body) VALUES
  ('00000000-0000-0000-0000-000000072001','00000000-0000-0000-0000-000000070000','00000000-0000-0000-0000-000000072000',
   'Workload Controllers: Deployments, StatefulSets & DaemonSets','notes',0,50,
   '# Kubernetes Workload Controllers

## Deployment
Manages stateless workloads. Owns a chain of ReplicaSets. Supports rolling updates and rollbacks.
Key fields: `replicas`, `strategy.type` (RollingUpdate/Recreate), `revisionHistoryLimit`.

## StatefulSet
For stateful workloads needing stable network identity and persistent storage.
Pods get ordered names (app-0, app-1). Rolling updates go from highest to lowest ordinal.
Each pod gets its own PVC via `volumeClaimTemplates`.

## DaemonSet
Ensures one pod per node (or per matching node). Used for logging agents (fluentd), monitoring (node-exporter), CNI plugins.
Does not respect `replicas` — count is determined by eligible node count.

## HorizontalPodAutoscaler (HPA)
Scales Deployment/StatefulSet replicas based on metrics. Default sync period: 15s.
Formula: `desiredReplicas = ceil(current * (currentMetric / desiredMetric))`
Stabilization window (default 5 min) prevents scale-down thrashing.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes) VALUES
  ('00000000-0000-0000-0000-000000072002','00000000-0000-0000-0000-000000070000','00000000-0000-0000-0000-000000072000',
   'Lab: Deployments, Rolling Updates & HPA','lab',1,75)
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id) VALUES
  ('00000000-0000-0000-0000-000000072003','00000000-0000-0000-0000-000000070000','00000000-0000-0000-0000-000000072000',
   'Quiz: Workloads & Controllers','assessment',2,25,'00000000-0000-0000-0000-000000060002')
ON CONFLICT (id) DO NOTHING;

-- Section 3: Networking
INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, content_body) VALUES
  ('00000000-0000-0000-0000-000000073001','00000000-0000-0000-0000-000000070000','00000000-0000-0000-0000-000000073000',
   'Kubernetes Networking: Services, DNS & Ingress','notes',0,55,
   '# Kubernetes Networking

## Service Types
- **ClusterIP** — stable virtual IP inside the cluster only (default)
- **NodePort** — exposes on a port on every node (30000-32767), builds on ClusterIP
- **LoadBalancer** — provisions a cloud LB, builds on NodePort
- **ExternalName** — CNAME alias to an external DNS name, no proxying

## kube-proxy Modes
- **iptables** (default): NAT rules in netfilter, O(n) lookup, random endpoint selection
- **IPVS**: hash table, O(1) lookup, richer LB algorithms (round-robin, least-conn, source-hash)

## DNS (CoreDNS)
Pod /etc/resolv.conf points to CoreDNS ClusterIP. Search domains added by kubelet.
A record for Service: `<svc>.<ns>.svc.cluster.local → ClusterIP`
SRV record for named ports: `_<port>._<proto>.<svc>.<ns>.svc.cluster.local`

## Ingress
Layer 7 routing (HTTP/HTTPS) using an Ingress controller (nginx, traefik, envoy).
Ingress resource defines rules; controller watches and configures its proxy.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes) VALUES
  ('00000000-0000-0000-0000-000000073002','00000000-0000-0000-0000-000000070000','00000000-0000-0000-0000-000000073000',
   'Lab: Services, Ingress & Network Policies','lab',1,70)
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id) VALUES
  ('00000000-0000-0000-0000-000000073003','00000000-0000-0000-0000-000000070000','00000000-0000-0000-0000-000000073000',
   'Quiz: Networking & Services','assessment',2,25,'00000000-0000-0000-0000-000000060003')
ON CONFLICT (id) DO NOTHING;

-- Section 4: Storage
INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, content_body) VALUES
  ('00000000-0000-0000-0000-000000074001','00000000-0000-0000-0000-000000070000','00000000-0000-0000-0000-000000074000',
   'ConfigMaps, Secrets, PersistentVolumes & StorageClasses','notes',0,50,
   '# Kubernetes Storage & Configuration

## ConfigMaps
Stores non-sensitive key-value config. Consumed as env vars, volume files, or command args.
Mounted volume files are updated automatically (with a short delay) when ConfigMap is updated.

## Secrets
Base64-encoded (not encrypted at rest by default — use EncryptionConfiguration for etcd encryption).
Types: Opaque, kubernetes.io/tls, kubernetes.io/dockerconfigjson, etc.

## PersistentVolumes (PV) & PVCs
PV: cluster-level storage resource (static or dynamically provisioned).
PVC: namespace-level claim for storage (binds to a matching PV).
Access modes: RWO (single node RW), ROX (multi-node RO), RWX (multi-node RW), RWOP (single pod RW).
Reclaim policies: Delete (remove storage on PVC delete), Retain (keep storage), Recycle (deprecated).

## StorageClass
Enables dynamic provisioning — PVC creation triggers the provisioner to create PV and backing storage.
`volumeBindingMode: WaitForFirstConsumer` delays PV creation until pod is scheduled (avoids zone mismatch).')
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes) VALUES
  ('00000000-0000-0000-0000-000000074002','00000000-0000-0000-0000-000000070000','00000000-0000-0000-0000-000000074000',
   'Lab: ConfigMaps, Secrets & Persistent Volumes','lab',1,65)
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id) VALUES
  ('00000000-0000-0000-0000-000000074003','00000000-0000-0000-0000-000000070000','00000000-0000-0000-0000-000000074000',
   'Quiz: Storage & Configuration','assessment',2,25,'00000000-0000-0000-0000-000000060004')
ON CONFLICT (id) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- Modules — Master Course
-- Section 1: Cluster Admin
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, content_body) VALUES
  ('00000000-0000-0000-0000-000000081001','00000000-0000-0000-0000-000000080000','00000000-0000-0000-0000-000000081000',
   'RBAC, Admission Controllers & Cluster Security','notes',0,60,
   '# Kubernetes Cluster Administration

## RBAC Architecture
Four API objects: Role (namespace), ClusterRole (cluster-wide), RoleBinding, ClusterRoleBinding.
Subjects: User, Group, ServiceAccount.
Node Authorizer limits each kubelet to secrets/configmaps/PVCs of pods on its own node.

## Admission Controllers
Built-in controllers run BEFORE the object is persisted. Key ones:
- NamespaceLifecycle: prevents creation in terminating namespaces
- ResourceQuota: enforces namespace quotas
- LimitRanger: injects default limits/requests
- NodeRestriction: prevents kubelets from modifying objects outside their node scope

## Webhooks
MutatingAdmissionWebhook runs first (can modify objects).
ValidatingAdmissionWebhook runs after mutation (read-only, can only allow/deny).
failurePolicy: Fail (deny on error — use for security) vs Ignore (allow on error — use for advisory).

## Audit Logging
Levels: None, Metadata, Request, RequestResponse.
Stages: RequestReceived, ResponseStarted, ResponseComplete, Panic.
Policy rules match verbs, resources, users, and namespaces.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes) VALUES
  ('00000000-0000-0000-0000-000000081002','00000000-0000-0000-0000-000000080000','00000000-0000-0000-0000-000000081000',
   'Lab: RBAC, Service Accounts & Pod Security','lab',1,90)
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id) VALUES
  ('00000000-0000-0000-0000-000000081003','00000000-0000-0000-0000-000000080000','00000000-0000-0000-0000-000000081000',
   'Quiz: Cluster Administration','assessment',2,30,'00000000-0000-0000-0000-000000060005')
ON CONFLICT (id) DO NOTHING;

-- Section 2: Advanced Networking
INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, content_body) VALUES
  ('00000000-0000-0000-0000-000000082001','00000000-0000-0000-0000-000000080000','00000000-0000-0000-0000-000000082000',
   'eBPF Networking, CNI Deep Dive & NetworkPolicies','notes',0,65,
   '# Advanced Kubernetes Networking

## eBPF vs iptables CNI
- iptables: O(n) rule traversal, no L7 visibility, managed by kube-proxy
- eBPF (Cilium): O(1) hash lookups, L7 policy (HTTP/gRPC), identity-based (not IP-based), kube-proxy replacement mode

## IPVS Mode
kube-proxy --proxy-mode=ipvs uses Linux Virtual Server kernel module.
O(1) service lookup via hash table. LB algorithms: rr, lc, dh, sh, sed, nq.
Requires kernel IPVS modules loaded.

## NetworkPolicy
Default: all pods can communicate. NetworkPolicy ADDS restrictions.
Deny-all ingress: `spec.podSelector: {}` with empty `ingress: []`.
podSelector selects target pods. namespaceSelector allows cross-namespace rules.
ipBlock with cidr/except for external IP ranges.

## CNI Plugin Execution
kubelet executes CNI binary from /opt/cni/bin/, passing pod netns via stdin JSON.
IPAM plugins (host-local, Whereabouts) track IP allocation per node.
CNI creates veth pair, assigns IP, sets routes in pod namespace.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes) VALUES
  ('00000000-0000-0000-0000-000000082002','00000000-0000-0000-0000-000000080000','00000000-0000-0000-0000-000000082000',
   'Lab: Network Policies & Zero-Trust Networking','lab',1,90)
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id) VALUES
  ('00000000-0000-0000-0000-000000082003','00000000-0000-0000-0000-000000080000','00000000-0000-0000-0000-000000082000',
   'Quiz: Advanced Networking','assessment',2,30,'00000000-0000-0000-0000-000000060006')
ON CONFLICT (id) DO NOTHING;

-- Section 3: Observability
INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, content_body) VALUES
  ('00000000-0000-0000-0000-000000083001','00000000-0000-0000-0000-000000080000','00000000-0000-0000-0000-000000083000',
   'Monitoring, Logging, Probes & Production Troubleshooting','notes',0,60,
   '# Kubernetes Observability

## Metrics Architecture
- metrics-server: implements metrics.k8s.io, stores short-term CPU/memory (used by HPA, kubectl top)
- Prometheus + prometheus-adapter: implements custom.metrics.k8s.io for custom HPA metrics
- Grafana dashboards for visualization

## Container Probes
- **startupProbe**: fires until success, blocks liveness/readiness — for slow-boot apps
- **readinessProbe**: failure removes pod from Endpoints — traffic stops, pod keeps running
- **livenessProbe**: failure restarts container — for hung/deadlocked processes
Set conservative thresholds to avoid cascading restarts under load.

## Troubleshooting Checklist
1. `kubectl describe pod` — Events section shows scheduling failures, image pull errors
2. `kubectl logs pod --previous` — logs from terminated container
3. `kubectl exec -it pod -- /bin/sh` — inspect env, DNS, connectivity
4. `kubectl top pods/nodes` — CPU/memory usage
5. `kubectl get events --sort-by=.lastTimestamp` — cluster-wide event timeline')
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes) VALUES
  ('00000000-0000-0000-0000-000000083002','00000000-0000-0000-0000-000000080000','00000000-0000-0000-0000-000000083000',
   'Lab: Monitoring, Debugging & Resource Quotas','lab',1,80)
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id) VALUES
  ('00000000-0000-0000-0000-000000083003','00000000-0000-0000-0000-000000080000','00000000-0000-0000-0000-000000083000',
   'Quiz: Observability & Troubleshooting','assessment',2,30,'00000000-0000-0000-0000-000000060007')
ON CONFLICT (id) DO NOTHING;

-- Section 4: CKA Exam Prep
INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, content_body) VALUES
  ('00000000-0000-0000-0000-000000084001','00000000-0000-0000-0000-000000080000','00000000-0000-0000-0000-000000084000',
   'etcd Backup & Restore, Cluster Upgrades & Node Maintenance','notes',0,70,
   '# CKA Exam Preparation

## etcd Backup
```bash
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key
```

## etcd Restore
1. Stop control plane pods (mv manifests out of /etc/kubernetes/manifests/)
2. `etcdctl snapshot restore /backup/etcd-snapshot.db --data-dir=/var/lib/etcd-new`
3. Update etcd.yaml --data-dir to point to restored path
4. Move manifests back, wait for pods to restart
5. Verify: `kubectl get nodes`, `kubectl get pods -A`

## Cluster Upgrade (kubeadm)
1. `apt install kubeadm=1.31.x` on control plane
2. `kubeadm upgrade apply v1.31.x`
3. `apt install kubelet=1.31.x kubectl=1.31.x && systemctl restart kubelet`
4. For each worker: drain → upgrade kubeadm/kubelet/kubectl → `kubeadm upgrade node` → restart kubelet → uncordon

## Node Maintenance
`kubectl cordon <node>` — mark unschedulable
`kubectl drain <node> --ignore-daemonsets --delete-emptydir-data` — evict pods
`kubectl uncordon <node>` — re-enable scheduling')
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes) VALUES
  ('00000000-0000-0000-0000-000000084002','00000000-0000-0000-0000-000000080000','00000000-0000-0000-0000-000000084000',
   'Lab: etcd Backup, Cluster Upgrade & Node Lifecycle','lab',1,100)
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id) VALUES
  ('00000000-0000-0000-0000-000000084003','00000000-0000-0000-0000-000000080000','00000000-0000-0000-0000-000000084000',
   'Quiz: CKA Exam Preparation','assessment',2,30,'00000000-0000-0000-0000-000000060008')
ON CONFLICT (id) DO NOTHING;
