---
kind: lesson
id_key: k8s/cluster-ops/lesson-day2
course: fast-kubernetes
section: cluster-ops
section_title: 'Real Clusters: Setup, Security and Operations'
section_position: 10
title: 'Day-2 Operations: Maintenance, Upgrades and Backups'
position: 2
estimated_minutes: 45
source:
  - K8s-Kubeadm-Cluster-Setup.md
lab:
  lab_type: terminal
  environment: mindforge/lab-k8s:1.31
  max_duration: 45
  max_resets: 3
  hint_penalty_pct: 10
  is_required: false
  setup_script: |
    #!/bin/bash
    set -euo pipefail
    kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
  files:
    - path: node2.yaml
      content: |
        apiVersion: v1
        kind: Node
        metadata:
          name: node2
          labels:
            kubernetes.io/hostname: node2
            kubernetes.io/os: linux
            type: kwok
          annotations:
            kwok.x-k8s.io/node: fake
        status:
          allocatable:
            cpu: "8"
            memory: 32Gi
            pods: "110"
          capacity:
            cpu: "8"
            memory: 32Gi
            pods: "110"
    - path: web.yaml
      content: |
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: web
        spec:
          replicas: 4
          selector:
            matchLabels:
              app: web
          template:
            metadata:
              labels:
                app: web
            spec:
              topologySpreadConstraints:
              - maxSkew: 1
                topologyKey: kubernetes.io/hostname
                whenUnsatisfiable: ScheduleAnyway
                labelSelector:
                  matchLabels:
                    app: web
              containers:
              - name: nginx
                image: nginx:1.27
  tasks:
    - id_key: two-nodes
      title: Run an app across two nodes
      points: 10
      is_stateful: true
      description: Register a second node (`kubectl apply -f node2.yaml`), then apply `web.yaml`. Check with `kubectl get pods -o wide` that the 4 pods are spread over both nodes.
      verification_script: |
        #!/bin/bash
        test "$(kubectl get deploy web -o jsonpath='{.status.readyReplicas}')" = "4" || exit 1
        kubectl get pods -l app=web -o jsonpath='{.items[*].spec.nodeName}' | grep -q node2
      hint_context: Apply node2.yaml first, wait until `kubectl get nodes` shows it Ready, then apply web.yaml.
      explanation_context: The topologySpreadConstraint asked the scheduler to keep the pod count per node within 1, so the pods landed 2 and 2.
      solution_script: |
        kubectl apply -f /home/labuser/work/node2.yaml
        for i in $(seq 1 30); do kubectl get node node2 -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -qx True && break; sleep 1; done
        kubectl apply -f /home/labuser/work/web.yaml
    - id_key: create-pdb
      title: Protect the app with a PodDisruptionBudget
      points: 15
      is_stateful: true
      description: Create a PodDisruptionBudget named `web-pdb` that keeps at least **3** pods with label `app=web` available during voluntary disruptions like a drain.
      verification_script: |
        #!/bin/bash
        test "$(kubectl get pdb web-pdb -o jsonpath='{.spec.minAvailable} {.spec.selector.matchLabels.app}')" = "3 web"
      hint_context: "`kubectl create pdb <name> --selector=app=web --min-available=3`"
      explanation_context: A drain evicts pods through the Eviction API, which respects PDBs. It will never take the app below 3 available pods at once.
      solution_script: kubectl create pdb web-pdb --selector=app=web --min-available=3
    - id_key: cordon-node
      title: Cordon a node
      points: 10
      is_stateful: true
      description: Mark `node2` as unschedulable so no new pods go there. Look at `kubectl get nodes`.
      verification_script: |
        #!/bin/bash
        test "$(kubectl get node node2 -o jsonpath='{.spec.unschedulable}')" = "true"
      hint_context: "`kubectl cordon <node>`"
      explanation_context: The node now shows SchedulingDisabled. Pods already running there are not touched. Cordon only stops new placements.
      solution_script: kubectl cordon node2
    - id_key: drain-node
      title: Drain the node for maintenance
      points: 20
      is_stateful: true
      description: Drain `node2` so all `web` pods move to `kwok-node`. Then check `kubectl get pods -o wide`.
      verification_script: |
        #!/bin/bash
        ! kubectl get pods -l app=web -o jsonpath='{.items[*].spec.nodeName}' | grep -q node2 || exit 1
        test "$(kubectl get deploy web -o jsonpath='{.status.readyReplicas}')" = "4"
      hint_context: "`kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`"
      explanation_context: drain cordons the node and evicts its pods (respecting the PDB). The Deployment recreated them on kwok-node. The node is now safe to patch or reboot.
      solution_script: |
        kubectl drain node2 --ignore-daemonsets --delete-emptydir-data --timeout=60s
        kubectl rollout status deployment/web --timeout=60s
    - id_key: uncordon-node
      title: Bring the node back
      points: 10
      is_stateful: false
      description: Maintenance is done. Make `node2` schedulable again. (Existing pods do not move back on their own; new pods can use it again.)
      verification_script: |
        #!/bin/bash
        test -z "$(kubectl get node node2 -o jsonpath='{.spec.unschedulable}')"
      hint_context: "`kubectl uncordon <node>`"
      explanation_context: uncordon removes the unschedulable flag. The scheduler does not rebalance running pods; a rollout restart or future scaling spreads them again.
      solution_script: kubectl uncordon node2
    - id_key: etcd-snapshot
      title: Back up etcd
      points: 20
      is_stateful: false
      description: |
        This sandbox's etcd listens on `http://127.0.0.1:2379` without TLS. Save a snapshot to `~/work/etcd-backup.db` with `etcdctl snapshot save`, then check it with `etcdctl --write-out=table snapshot status ~/work/etcd-backup.db`.
      verification_script: |
        #!/bin/bash
        f=/home/labuser/work/etcd-backup.db
        test -s "$f" && ETCDCTL_API=3 etcdctl snapshot status "$f" >/dev/null 2>&1
      hint_context: "`ETCDCTL_API=3 etcdctl --endpoints=http://127.0.0.1:2379 snapshot save <file>`. On a kubeadm cluster you would also pass --cacert, --cert and --key from /etc/kubernetes/pki/etcd/."
      explanation_context: The snapshot contains every object in the cluster. Store it off the cluster, on a schedule. Restoring it (etcdutl snapshot restore) brings the whole cluster state back.
      solution_script: ETCDCTL_API=3 etcdctl --endpoints=http://127.0.0.1:2379 snapshot save /home/labuser/work/etcd-backup.db
---

"Day 1" is building the cluster. "Day 2" is everything after that: patching nodes without downtime, upgrading Kubernetes, backing up, renewing certificates and removing machines. These are the tasks that decide whether production stays up, and they come up often in interviews for DevOps and SRE roles.

## Node maintenance: cordon, drain, uncordon

Think of a bank closing one teller counter for the day while keeping the branch open. First a sign goes up so no new customer joins that queue (cordon), then the remaining customers in that queue are guided to other counters (drain), and only then is the counter actually shut for cleaning. To patch, reboot or replace a node without breaking apps:

```bash
kubectl cordon worker2                     # 1. no new pods here (SchedulingDisabled)
kubectl drain worker2 --ignore-daemonsets --delete-emptydir-data   # 2. evict pods; controllers recreate them elsewhere
# ... patch / reboot / replace the machine ...
kubectl uncordon worker2                   # 3. allow scheduling again
```

What `drain` does and why the flags exist:

- It cordons the node, then **evicts** every pod on it, one by one, respecting PodDisruptionBudgets.
- `--ignore-daemonsets`: DaemonSet pods would be recreated on the same node immediately, so drain skips them.
- `--delete-emptydir-data`: confirms you accept losing emptyDir data of evicted pods.
- Bare pods (no controller) block the drain, because they would be lost forever. `--force` deletes them anyway.

Drain only works well if apps have **more than one replica** and pods can run on other nodes (enough room, no tight node affinity). A single-replica app always has a short outage during a drain.

After maintenance, `uncordon` does **not** move pods back. The node fills up again as new pods are created.

```knowledge-check
{ "questions": [
  { "id": "k8s-day2-drain-q1", "type": "mcq",
    "prompt": "What is the difference between `kubectl cordon` and `kubectl drain`?",
    "options": [
      {"id": "a", "text": "They are the same"},
      {"id": "b", "text": "cordon only stops new pods from being scheduled; drain also evicts the pods already running there"},
      {"id": "c", "text": "cordon deletes the node; drain reboots it"},
      {"id": "d", "text": "drain only affects DaemonSets"}
    ],
    "correct": "b",
    "explanation": "Cordon = mark unschedulable. Drain = cordon + evict existing pods so the node is empty for maintenance." },
  { "id": "k8s-day2-drain-q2", "type": "mcq",
    "prompt": "A drain stops with 'cannot delete Pods not managed by ReplicationController, ReplicaSet, Job, DaemonSet or StatefulSet'. Why?",
    "options": [
      {"id": "a", "text": "The node is offline"},
      {"id": "b", "text": "A bare pod runs there; evicting it would lose it forever, so drain asks for --force"},
      {"id": "c", "text": "The PDB is too strict"},
      {"id": "d", "text": "The kubelet must be restarted first"}
    ],
    "correct": "b",
    "explanation": "Nothing would recreate a bare pod. Move it into a Deployment, or use --force if losing it is acceptable." }
] }
```

## PodDisruptionBudgets

Like a bank's rule that at least 3 tellers must always be on duty no matter how many are on tea break at once, a **PodDisruptionBudget (PDB)** limits how many pods of an app may be down at the same time because of **voluntary** disruptions (drains, cluster upgrades, autoscaler scale-downs):

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
spec:
  minAvailable: 3            # or: maxUnavailable: 1
  selector:
    matchLabels:
      app: web
```

Drains wait until evicting another pod would not break the budget. PDBs do **not** protect against involuntary failures (a node crashing).

A classic mistake: a PDB of `minAvailable: 1` on a single-replica Deployment (or `maxUnavailable: 0`). That makes every drain hang forever, and node upgrades get stuck.

```knowledge-check
{ "questions": [
  { "id": "k8s-day2-pdb-q1", "type": "mcq",
    "prompt": "A Deployment has 1 replica and a PDB with minAvailable: 1. What happens when you drain its node?",
    "options": [
      {"id": "a", "text": "The pod is evicted immediately"},
      {"id": "b", "text": "The drain waits forever, because evicting the only pod would violate the budget"},
      {"id": "c", "text": "The PDB is ignored for single replicas"},
      {"id": "d", "text": "A second replica is created automatically"}
    ],
    "correct": "b",
    "explanation": "The budget can never be satisfied during eviction. Run at least 2 replicas or allow maxUnavailable: 1." }
] }
```

## Removing a node for good

```bash
kubectl drain worker2 --ignore-daemonsets --delete-emptydir-data
kubectl delete node worker2
# on worker2 itself, to wipe its Kubernetes state:
sudo kubeadm reset
```

On managed clusters, you scale the node group instead and the provider drains the node for you.

```knowledge-check
{ "questions": [
  { "id": "k8s-day2-remove-q1", "type": "mcq",
    "prompt": "What is the correct order to permanently remove a worker node?",
    "options": [
      {"id": "a", "text": "kubeadm reset on the node, then drain"},
      {"id": "b", "text": "drain the node, delete the Node object, then kubeadm reset on the machine"},
      {"id": "c", "text": "delete the Node object only"},
      {"id": "d", "text": "uncordon, then delete"}
    ],
    "correct": "b",
    "explanation": "Drain first so workloads move safely, then remove it from the API, then clean the machine." }
] }
```

## Upgrading a kubeadm cluster

Kubernetes releases a new minor version about three times a year, and each is supported for about 14 months. Staying current is not optional. Rules:

- Upgrade **one minor version at a time** (1.32 → 1.33 → 1.34, never skip).
- Upgrade the **control plane first**, then the workers. Kubelets may be older than the API server (up to three minor versions) but **never newer**.
- Read the release notes for **removed APIs** first. An upgrade can break manifests or Helm charts that still use an old `apiVersion`.

On the first control-plane node:

```bash
# point apt at the next minor repo (edit /etc/apt/sources.list.d/kubernetes.list: v1.33 -> v1.34)
sudo apt-mark unhold kubeadm && sudo apt-get update && sudo apt-get install -y kubeadm && sudo apt-mark hold kubeadm
sudo kubeadm upgrade plan              # shows what will change
sudo kubeadm upgrade apply v1.34.x
kubectl drain master --ignore-daemonsets
sudo apt-mark unhold kubelet kubectl && sudo apt-get install -y kubelet kubectl && sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
kubectl uncordon master
```

Then on each worker, **one at a time**: upgrade kubeadm, run `sudo kubeadm upgrade node`, drain it, upgrade kubelet/kubectl, restart kubelet, uncordon it. On managed clusters, you click "upgrade" for the control plane, then roll the node groups; the idea is the same.

```knowledge-check
{ "questions": [
  { "id": "k8s-day2-upgrade-q1", "type": "mcq",
    "prompt": "Your cluster runs 1.31. You want to reach 1.33. What is the correct path?",
    "options": [
      {"id": "a", "text": "Upgrade workers to 1.33 first, then the control plane"},
      {"id": "b", "text": "Upgrade the control plane 1.31 → 1.32, then workers; then repeat for 1.32 → 1.33"},
      {"id": "c", "text": "Jump the control plane straight to 1.33"},
      {"id": "d", "text": "Reinstall the cluster at 1.33"}
    ],
    "correct": "b",
    "explanation": "One minor version at a time, control plane before nodes, since kubelets must never be newer than the API server." }
] }
```

## Backing up etcd and certificates

**etcd holds the whole cluster state.** If you lose it without a backup, you lose every Deployment, Service, Secret and RBAC rule. Back it up on a schedule and keep copies off the cluster:

```bash
sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /backup/etcd-$(date +%F).db

etcdutl --write-out=table snapshot status /backup/etcd-2026-09-27.db
# restore (disaster recovery): etcdutl snapshot restore <file> --data-dir /var/lib/etcd-restored,
# then point the etcd static pod manifest at the new data dir
```

An etcd backup is not an application-data backup. PersistentVolume contents need their own backups (volume snapshots, or **Velero**, which backs up both Kubernetes objects and volumes).

**Certificates expire.** kubeadm's control-plane certificates are valid for **one year**. When they expire, kubectl and the components stop working ("x509: certificate has expired"). Check and renew them:

```bash
sudo kubeadm certs check-expiration
sudo kubeadm certs renew all        # then restart the control-plane static pods
```

A normal kubeadm upgrade renews them too, which is one more reason to upgrade regularly.

[[lab-task:1]]

[[lab-task:2]]

[[lab-task:3]]

[[lab-task:4]]

[[lab-task:5]]

[[lab-task:6]]

```knowledge-check
{ "questions": [
  { "id": "k8s-day2-backup-q1", "type": "mcq",
    "prompt": "One morning every kubectl command fails with 'x509: certificate has expired or is not yet valid' on a kubeadm cluster that is exactly one year old. What happened?",
    "options": [
      {"id": "a", "text": "etcd lost its data"},
      {"id": "b", "text": "The control-plane certificates reached their 1-year expiry; renew them with kubeadm certs renew"},
      {"id": "c", "text": "The CNI plugin crashed"},
      {"id": "d", "text": "Someone deleted the kubeconfig"}
    ],
    "correct": "b",
    "explanation": "kubeadm certificates last one year unless renewed (upgrades renew them). Monitor expiry with kubeadm certs check-expiration." },
  { "id": "k8s-day2-backup-q2", "type": "mcq",
    "prompt": "Does an etcd snapshot back up the data inside your PostgreSQL PersistentVolume?",
    "options": [
      {"id": "a", "text": "Yes, etcd contains all volume data"},
      {"id": "b", "text": "No, it only contains Kubernetes objects; volume data needs its own backup (snapshots, Velero, database dumps)"},
      {"id": "c", "text": "Only for StatefulSets"},
      {"id": "d", "text": "Only if the PV uses NFS"}
    ],
    "correct": "b",
    "explanation": "etcd stores the PV and PVC objects, not the bytes on the disk." }
] }
```

## Interview questions and real-world scenarios

**Q: How do you patch a node's OS without downtime?**
cordon → drain (PDBs respected, apps have 2+ replicas) → patch/reboot → uncordon; one node at a time. On clouds, roll the node group with surge.

**Q: What is a PodDisruptionBudget, and what can go wrong with it?**
It limits voluntary evictions for an app. Too strict (minAvailable equal to replicas) blocks drains and upgrades forever.

**Q: Describe a cluster upgrade.**
Read release notes for removed APIs, back up etcd, upgrade one minor at a time, control plane first, then nodes one by one (drain/upgrade/uncordon), verify workloads after each step.

**Q: How do you back up and restore a cluster?**
etcd snapshots (objects) plus volume backups (snapshots, Velero), stored off-cluster, and tested with regular restores. With GitOps, the manifests in Git are also a form of backup.

**Q: What breaks when kubeadm certificates expire?**
The API server, kubelet communication and kubectl all fail with x509 errors. Renew with `kubeadm certs renew all` and restart the control-plane pods; monitor expiry dates.

**Real-world scenario: a node upgrade has been "draining" for an hour.**
A PDB can't be satisfied (single replica with minAvailable 1), a pod has no controller, or replacement pods can't schedule elsewhere. `kubectl get pdb -A` (ALLOWED DISRUPTIONS 0) usually shows the culprit.

**Real-world scenario: the upgrade to a new version broke deployments with "no matches for kind Ingress in version extensions/v1beta1".**
The manifests used an API version removed in the new release. Scan for deprecated APIs before upgrading (tools like pluto or kubent) and update manifests and charts.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-day2-int-q1",
      "type": "mcq",
      "prompt": "A node drain has hung for 30 minutes. `kubectl get pdb -A` shows one PDB with ALLOWED DISRUPTIONS 0. What does that mean?",
      "options": [
        {
          "id": "a",
          "text": "The PDB is broken and should be ignored"
        },
        {
          "id": "b",
          "text": "Evicting any more pods of that app would violate its budget, so the drain waits; the app needs more replicas or a looser PDB"
        },
        {
          "id": "c",
          "text": "The node is already empty"
        },
        {
          "id": "d",
          "text": "etcd is down"
        }
      ],
      "correct": "b",
      "explanation": "ALLOWED DISRUPTIONS 0 blocks evictions. Scale the app up or adjust the PDB, then the drain continues."
    }
  ]
}
```
