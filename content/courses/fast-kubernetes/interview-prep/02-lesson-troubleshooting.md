---
kind: lesson
id_key: k8s/interview-prep/lesson-troubleshooting
course: fast-kubernetes
section: interview-prep
section_title: Interview Prep & Production Troubleshooting
section_position: 12
title: Production Troubleshooting Playbook
position: 1
estimated_minutes: 60
source:
  - README.md
lab:
  lab_type: terminal
  environment: mindforge/lab-k8s:1.31
  max_duration: 60
  max_resets: 3
  hint_penalty_pct: 10
  is_required: false
  files:
    - path: shop.yaml
      content: |
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: catalog
          namespace: shop
        spec:
          replicas: 2
          selector:
            matchLabels:
              app: catalog
          template:
            metadata:
              labels:
                app: catalog
            spec:
              containers:
              - name: catalog
                image: nginx:1.27
        ---
        apiVersion: v1
        kind: Service
        metadata:
          name: catalog
          namespace: shop
        spec:
          selector:
            app: catalogue
          ports:
          - port: 80
            targetPort: 80
        ---
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: payments
          namespace: shop
        spec:
          replicas: 2
          selector:
            matchLabels:
              app: payments
          template:
            metadata:
              labels:
                app: payments
            spec:
              nodeSelector:
                pool: payments
              containers:
              - name: payments
                image: nginx:1.27
        ---
        apiVersion: v1
        kind: PersistentVolume
        metadata:
          name: orders-pv
        spec:
          capacity:
            storage: 10Gi
          accessModes: ["ReadWriteOnce"]
          hostPath:
            path: /data/orders
        ---
        apiVersion: v1
        kind: PersistentVolumeClaim
        metadata:
          name: orders-data
          namespace: shop
        spec:
          storageClassName: fast-ssd
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
        ---
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: checkout
          namespace: shop
        spec:
          replicas: 3
          selector:
            matchLabels:
              app: checkout
          template:
            metadata:
              labels:
                app: checkout
            spec:
              containers:
              - name: checkout
                image: nginx:1.27
                resources:
                  requests:
                    cpu: 100m
                    memory: 64Mi
  setup_script: |
    #!/bin/bash
    set -euo pipefail
    kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
    kubectl create namespace shop
    kubectl apply -f /home/labuser/work/shop.yaml
    kubectl rollout status deployment/checkout -n shop --timeout=60s
    kubectl annotate deployment/checkout -n shop kubernetes.io/change-cause="v1: initial release"
    # a bad release: requests far more CPU than any node has
    kubectl set resources deployment/checkout -n shop -c checkout --requests=cpu=64,memory=64Mi
    kubectl annotate deployment/checkout -n shop --overwrite kubernetes.io/change-cause="v2: new resource settings"
  tasks:
    - id_key: fix-empty-endpoints
      title: "Incident 1: the catalog Service sends traffic nowhere"
      points: 20
      is_stateful: false
      description: |
        Everything is in the `shop` namespace. The team says "catalog is up but nobody can reach it through its Service". Find the cause with `kubectl get endpoints -n shop` and friends, and fix it **without** changing the pods.
      verification_script: |
        #!/bin/bash
        test "$(kubectl get endpoints catalog -n shop -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)" = "2"
      hint_context: Compare the Service's selector with the pods' labels (`kubectl get pods -n shop --show-labels`).
      explanation_context: The Service selected app=catalogue, but the pods are labeled app=catalog, so there were no endpoints. Fixing the selector filled the endpoint list immediately.
      solution_script: |
        kubectl patch service catalog -n shop -p '{"spec":{"selector":{"app":"catalog"}}}'
    - id_key: fix-pending-payments
      title: "Incident 2: payments pods are stuck in Pending"
      points: 20
      is_stateful: false
      description: |
        The `payments` pods never start. Find out why from the pod events. The node pool the pods ask for was never created, and the team confirms payments may run on any node. Fix the Deployment so its pods run.
      verification_script: |
        #!/bin/bash
        test "$(kubectl get deploy payments -n shop -o jsonpath='{.status.readyReplicas}')" = "2" || exit 1
        test -z "$(kubectl get deploy payments -n shop -o jsonpath='{.spec.template.spec.nodeSelector.pool}')"
      hint_context: "`kubectl describe pod -n shop -l app=payments` shows a FailedScheduling event about node affinity/selector. Remove the nodeSelector from the Deployment (kubectl edit, or a JSON patch)."
      explanation_context: "The pods required a node with label pool=payments and no node has it. Removing the nodeSelector (or labeling a node, if the pool really existed) lets the scheduler place them."
      solution_script: |
        kubectl patch deployment payments -n shop --type=json -p '[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'
        kubectl rollout status deployment/payments -n shop --timeout=60s
    - id_key: fix-stuck-rollout
      title: "Incident 3: the checkout rollout is stuck"
      points: 20
      is_stateful: false
      description: |
        A new `checkout` release went out a few minutes ago and never finished. Old pods still serve traffic, but new pods are Pending. Look at `kubectl rollout status`, `kubectl rollout history` and the new pods' events, then get checkout back to the last working version.
      verification_script: |
        #!/bin/bash
        test "$(kubectl get deploy checkout -n shop -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')" = "100m" || exit 1
        test "$(kubectl get deploy checkout -n shop -o jsonpath='{.status.updatedReplicas}/{.status.readyReplicas}')" = "3/3"
      hint_context: The new pods request 64 CPUs (Insufficient cpu). The quickest safe fix is `kubectl rollout undo`.
      explanation_context: A bad release that can never become ready leaves the rollout stuck, while the old ReplicaSet keeps serving (that is RollingUpdate protecting you). rollout undo returns to the previous template; then fix the manifest properly before redeploying.
      solution_script: |
        kubectl rollout undo deployment/checkout -n shop
        kubectl rollout status deployment/checkout -n shop --timeout=60s
    - id_key: fix-pending-pvc
      title: "Incident 4: the orders volume never binds"
      points: 20
      is_stateful: false
      description: |
        The claim `orders-data` stays Pending. The cluster has no StorageClass, and the admins pre-created a matching disk `orders-pv`. Make the claim bind to it. (Tip: many PVC fields cannot be changed after creation.)
      verification_script: |
        #!/bin/bash
        test "$(kubectl get pvc orders-data -n shop -o jsonpath='{.status.phase} {.spec.volumeName}')" = "Bound orders-pv"
      hint_context: "`kubectl describe pvc orders-data -n shop` says storageclass fast-ssd was not found. storageClassName is immutable, so delete the claim and recreate it with `storageClassName: \"\"`."
      explanation_context: The claim asked for a StorageClass that does not exist, so nothing could provision or bind it. An empty storageClassName means "bind to a pre-created PV without a class". Because the field is immutable, the claim had to be recreated.
      solution_script: |
        kubectl delete pvc orders-data -n shop
        cat > /home/labuser/work/orders-pvc.yaml <<'Y'
        apiVersion: v1
        kind: PersistentVolumeClaim
        metadata:
          name: orders-data
          namespace: shop
        spec:
          storageClassName: ""
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
        Y
        kubectl apply -f /home/labuser/work/orders-pvc.yaml
---

Knowing the objects is not enough. In a real job you get paged with a vague message like "checkout is broken" and have to find the cause quickly. This playbook gives you a **repeatable method** and the **most common failures**, each with symptoms, commands, causes and fixes. The lab at the end drops you into a broken namespace to practice.

## The method: from symptom to cause

A good doctor does not guess a diagnosis from one symptom. They check vital signs first, ask what changed recently, then run targeted tests before treating. Debugging a cluster follows the same order: work **from the outside in**, and change one thing at a time:

1. **What exactly is broken?** One user or all? One endpoint or everything? Since when? Did anything change (a deploy, a config change, a node upgrade)? Most incidents follow a change.
2. **Is the workload healthy?** `kubectl get deploy,pods -n <ns> -o wide`: status, restarts, age, node.
3. **What does Kubernetes say?** `kubectl describe pod <pod>` → **Events**. `kubectl get events -n <ns> --sort-by=.lastTimestamp`.
4. **What does the app say?** `kubectl logs <pod> [--previous]`.
5. **Is traffic reaching it?** Service → endpoints → pod port; Ingress → Service; DNS.
6. **Is the platform healthy?** Nodes Ready? Resources? Control-plane components?
7. **Mitigate first, then fix.** A rollback that restores service in one minute beats a perfect fix in an hour. Find the root cause afterwards and write it down.

```knowledge-check
{ "questions": [
  { "id": "k8s-ts-method-q1", "type": "mcq",
    "prompt": "Checkout started failing 10 minutes after a deployment. What is usually the fastest way to restore service?",
    "options": [
      {"id": "a", "text": "Debug the new code in production until it works"},
      {"id": "b", "text": "Roll back the deployment, then investigate the root cause"},
      {"id": "c", "text": "Restart every node"},
      {"id": "d", "text": "Delete the namespace and redeploy everything"}
    ],
    "correct": "b",
    "explanation": "Mitigate first. A rollout undo (or helm rollback / git revert) restores the known-good version while you investigate." }
] }
```

## Pod status problems

| Symptom | Look at | Common causes | Fix |
|---|---|---|---|
| `Pending` | `describe pod` → FailedScheduling | Not enough CPU/memory requested capacity; nodeSelector/affinity matches no node; untolerated taint; PVC not bound | Right-size requests, add nodes, fix labels/affinity, add toleration, fix the PVC |
| `ImagePullBackOff` / `ErrImagePull` | `describe pod` → Failed to pull | Typo in image name/tag; private registry without `imagePullSecrets`; registry rate limit; wrong architecture | Fix the tag, add pull secret, use a mirror |
| `CrashLoopBackOff` | `logs --previous`, `describe` (exit code) | App error at startup, missing config/env/secret, wrong command, failing liveness probe, can't reach dependency | Read the logs; fix config; relax the probe or add a startup probe |
| `OOMKilled` (exit code 137) | `describe` → Last State | Memory limit too low, memory leak, runtime heap not container-aware | Raise limit, fix leak, set heap size from the limit |
| `CreateContainerConfigError` | `describe` | Referenced ConfigMap/Secret or key missing | Create it or fix the name |
| `Init:CrashLoopBackOff` | `logs <pod> -c <init-container>` | Init container fails (for example waiting for a DB) | Fix the dependency or the init script |
| `Terminating` forever | `get pod -o yaml` → finalizers | Node unreachable; finalizer never removed | Recover the node; as last resort `--grace-period=0 --force` |
| `Evicted` | `describe` → reason | Node under memory/disk pressure | Set proper requests/limits, clean disk, add capacity |

**Exit codes worth knowing:** `0` finished normally, `1` app error, `137` killed by SIGKILL (usually OOM or failed liveness), `143` SIGTERM (normal shutdown), `126`/`127` command not executable / not found (wrong `command` in the spec).

```knowledge-check
{ "questions": [
  { "id": "k8s-ts-status-q1", "type": "mcq",
    "prompt": "A pod's last state shows exit code 137 and reason OOMKilled. What happened?",
    "options": [
      {"id": "a", "text": "The image could not be pulled"},
      {"id": "b", "text": "The container exceeded its memory limit and was killed"},
      {"id": "c", "text": "The app exited normally"},
      {"id": "d", "text": "The node was drained"}
    ],
    "correct": "b",
    "explanation": "137 = 128 + 9 (SIGKILL). With reason OOMKilled, the kernel killed it for going over its memory limit." },
  { "id": "k8s-ts-status-q2", "type": "mcq",
    "prompt": "A pod shows CreateContainerConfigError. What should you check first?",
    "options": [
      {"id": "a", "text": "Whether the ConfigMaps/Secrets (and keys) it references exist"},
      {"id": "b", "text": "The node's disk"},
      {"id": "c", "text": "The Ingress rules"},
      {"id": "d", "text": "The HPA"}
    ],
    "correct": "a",
    "explanation": "This status means the container's configuration could not be built, usually a missing ConfigMap, Secret or key." }
] }
```

## Networking problems

**"The Service does not work."** Go step by step:

```bash
kubectl get svc <svc> -n <ns>                   # right port / targetPort?
kubectl get endpoints <svc> -n <ns>             # empty = selector/labels mismatch or pods not ready
kubectl get pods -n <ns> --show-labels
kubectl run tmp --rm -it --image=busybox:1.36 -n <ns> -- sh
/ # nslookup <svc>                              # DNS working?
/ # wget -qO- http://<svc>:<port>/              # Service working?
/ # wget -qO- http://<pod-ip>:<containerPort>/  # pod working directly?
```

- Endpoints empty → selector typo or readiness failing.
- Pod IP works but Service does not → wrong `targetPort`, or kube-proxy/CNI problem.
- DNS fails → check CoreDNS pods in `kube-system`; wrong namespace in the name (`svc.otherns`).
- Works from a pod in one namespace but not another → a **NetworkPolicy** is blocking it.
- App listens on `127.0.0.1` instead of `0.0.0.0` → reachable only from inside its own pod.

**Ingress returns 404 / 502 / 503:**

- **404**: no rule matches the host/path (check the `Host` header, `pathType`, `ingressClassName`).
- **502/503**: the rule matches but the backend Service has no ready endpoints, or points to a wrong port.
- No ADDRESS at all: no ingress controller, or a wrong `ingressClassName`.
- TLS errors: the Secret is missing or in another namespace (it must be in the Ingress's namespace), or the certificate does not cover the host.

```knowledge-check
{ "questions": [
  { "id": "k8s-ts-net-q1", "type": "mcq",
    "prompt": "curl to the pod IP works, but curl to the Service name times out and endpoints show the pod. What is the likely cause?",
    "options": [
      {"id": "a", "text": "The Service's targetPort does not match the container port"},
      {"id": "b", "text": "The image tag is wrong"},
      {"id": "c", "text": "The pod has no labels"},
      {"id": "d", "text": "The namespace is missing"}
    ],
    "correct": "a",
    "explanation": "Endpoints exist, so selection works. If the pod answers directly but not through the Service, check port/targetPort mapping (and NetworkPolicies)." },
  { "id": "k8s-ts-net-q2", "type": "mcq",
    "prompt": "An Ingress returns 503 for /api. Which check comes first?",
    "options": [
      {"id": "a", "text": "Does the backend Service for /api have ready endpoints?"},
      {"id": "b", "text": "Is etcd healthy?"},
      {"id": "c", "text": "Are there too many Ingress objects?"},
      {"id": "d", "text": "Is the CronJob suspended?"}
    ],
    "correct": "a",
    "explanation": "503 from the controller usually means the route matched but there is no healthy backend." }
] }
```

## Deployment, storage and scaling problems

**Rollout stuck** (`kubectl rollout status` never finishes):
new pods can't be scheduled (resources), can't pull their image, crash, or never pass readiness. The old ReplicaSet keeps serving, so the service is usually still up. Mitigate with `kubectl rollout undo`, then fix. `progressDeadlineSeconds` (default 600s) marks the rollout as failed in its conditions, which CI can detect.

**Config change not picked up:** env vars need a pod restart (`kubectl rollout restart`); mounted files update after about a minute unless mounted with `subPath`; the app may cache config.

**PVC Pending:** `kubectl describe pvc` → no matching PV (size, access mode, storage class, selector), a StorageClass that does not exist, or `WaitForFirstConsumer` waiting for a pod to be scheduled (normal). `storageClassName` and most PVC spec fields are immutable, so recreate the claim.

**Volume can't attach / Multi-Attach error:** an RWO disk is still attached to the old node (common after a node crash, or RollingUpdate with a single RWO volume). Use `Recreate` for single-replica apps with RWO disks, or wait for the attach/detach controller to time out.

**HPA not scaling:** TARGETS `<unknown>` → metrics-server missing or no requests set; hitting `maxReplicas`; new pods Pending → cluster autoscaler needed.

```knowledge-check
{ "questions": [
  { "id": "k8s-ts-deploy-q1", "type": "mcq",
    "prompt": "You need to change a Pending PVC's storageClassName, but kubectl apply fails with 'field is immutable'. What do you do?",
    "options": [
      {"id": "a", "text": "Use kubectl edit instead of apply"},
      {"id": "b", "text": "Delete the PVC and create it again with the correct storageClassName"},
      {"id": "c", "text": "Restart the API server"},
      {"id": "d", "text": "Change the PV's name"}
    ],
    "correct": "b",
    "explanation": "Most PVC spec fields cannot change after creation. An unbound claim holds no data, so recreating it is safe." }
] }
```

## Node and cluster problems

**Node `NotReady`:**

```bash
kubectl describe node <node>          # Conditions: MemoryPressure, DiskPressure, PIDPressure, Ready
# on the node itself:
systemctl status kubelet containerd
journalctl -u kubelet -n 100 --no-pager
df -h                                  # full disk is a very common cause
```

Common causes: kubelet stopped or crashed, container runtime down, disk full (images and logs), expired kubelet certificate, network or CNI failure, cgroup driver mismatch after an upgrade.

**`kubectl` itself fails:**

- `connection refused` / timeout: wrong context, API server down, VPN/firewall.
- `x509: certificate has expired`: renew control-plane certs (`kubeadm certs renew all`).
- `Forbidden`: RBAC. Check with `kubectl auth can-i ... --as=...`.
- `Unauthorized`: expired token or credentials; log in again.

**Control plane on kubeadm:** the components are static pods, so check `kubectl get pods -n kube-system` and, if the API server itself is down, look at the containers directly on the node with `crictl ps -a` and `crictl logs <id>`.

```knowledge-check
{ "questions": [
  { "id": "k8s-ts-node-q1", "type": "mcq",
    "prompt": "A worker is NotReady. `kubectl describe node` shows DiskPressure=True. What is the likely fix?",
    "options": [
      {"id": "a", "text": "Free disk space (unused images, logs) or add disk, then the kubelet recovers"},
      {"id": "b", "text": "Delete the namespace"},
      {"id": "c", "text": "Add a toleration to every pod"},
      {"id": "d", "text": "Upgrade Helm"}
    ],
    "correct": "a",
    "explanation": "The kubelet reports DiskPressure when the node's disk is nearly full; it evicts pods and marks the node unhealthy until space is freed." }
] }
```

## Practice: fix the broken shop

The lab below starts with a `shop` namespace that has **four real problems**, the same kinds you saw above. Diagnose each one with the method, fix it, and then explain to yourself (as you would in an interview) what the root cause was and how to prevent it.

[[lab-task:1]]

[[lab-task:2]]

[[lab-task:3]]

[[lab-task:4]]

```knowledge-check
{ "questions": [
  { "id": "k8s-ts-practice-q1", "type": "mcq",
    "prompt": "After fixing an incident, what should always follow?",
    "options": [
      {"id": "a", "text": "Nothing, since the service is back"},
      {"id": "b", "text": "A short blameless write-up: timeline, root cause, and a prevention step such as an alert, test, or policy"},
      {"id": "c", "text": "Deleting all logs"},
      {"id": "d", "text": "Disabling the monitoring that fired"}
    ],
    "correct": "b",
    "explanation": "Post-incident reviews turn one outage into lasting improvements, and interviewers love hearing that you do them." }
] }
```
