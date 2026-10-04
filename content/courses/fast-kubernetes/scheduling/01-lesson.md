---
kind: lesson
id_key: k8s/scheduling/lesson
course: fast-kubernetes
section: scheduling
section_title: Health, Resources & Scheduling
section_position: 7
title: Health Probes, Resources and Scheduling Rules
position: 0
estimated_minutes: 60
source:
  - K8s-Liveness-App.md
  - K8s-Node-Affinity.md
  - K8s-Taint-Toleration.md
---

So far Kubernetes has placed pods wherever it liked and assumed they were healthy as long as the process was running. Real apps need more: detecting a frozen app, not sending traffic to a pod that is still starting, reserving enough CPU and memory, and keeping certain pods on certain machines. This lesson covers all four.

## Health probes: liveness, readiness and startup

The kubelet can check your container in three different ways, each answering a different question:

| Probe | Question | If it fails |
|---|---|---|
| **Liveness** | "Is the app still working, or is it stuck?" | The container is **restarted**. |
| **Readiness** | "Can the app handle traffic right now?" | The pod is **removed from Service endpoints** (no restart). When it passes again, traffic comes back. |
| **Startup** | "Has the app finished starting?" | Liveness and readiness wait until it passes. If it never does, the container is restarted. |

Why they matter:

- A process can be running but **deadlocked**. Without a liveness probe, Kubernetes sees a running process and does nothing.
- An app may need 30 seconds to load data. Without a readiness probe, it gets traffic the moment the container starts, and users see errors. Rolling updates also rely on readiness to know when a new pod is really available.
- A slow-starting app (for example, a large Java service) with a strict liveness probe gets killed before it ever finishes booting. A startup probe prevents that.

```knowledge-check
{ "questions": [
  { "id": "k8s-sched-probes-q1", "type": "mcq",
    "prompt": "A pod's readiness probe starts failing because its database connection dropped. What does Kubernetes do?",
    "options": [
      {"id": "a", "text": "Restarts the container"},
      {"id": "b", "text": "Stops sending Service traffic to that pod until the probe passes again"},
      {"id": "c", "text": "Deletes the pod and creates a new one"},
      {"id": "d", "text": "Moves the pod to another node"}
    ],
    "correct": "b",
    "explanation": "Readiness failures only remove the pod from endpoints. Restarting is what a liveness failure does." },
  { "id": "k8s-sched-probes-q2", "type": "mcq",
    "prompt": "A Java app needs 2 minutes to start, and its liveness probe kills it after 30 seconds, so it never comes up. What is the right fix?",
    "options": [
      {"id": "a", "text": "Remove all probes"},
      {"id": "b", "text": "Add a startup probe that allows enough time; liveness only begins after it succeeds"},
      {"id": "c", "text": "Change restartPolicy to Never"},
      {"id": "d", "text": "Add more replicas"}
    ],
    "correct": "b",
    "explanation": "A startup probe covers the slow boot. Liveness keeps its short period for detecting hangs later." }
] }
```

## Writing probes

Every probe uses one of four check types:

```yaml
livenessProbe:
  httpGet:                  # healthy if the HTTP status is 200-399
    path: /healthz
    port: 8080
    httpHeaders:
    - name: Custom-Header
      value: Awesome
  initialDelaySeconds: 3    # wait before the first check
  periodSeconds: 3          # check every 3 seconds
  timeoutSeconds: 1         # each check must answer within 1 second
  failureThreshold: 3       # 3 failures in a row = unhealthy
```

```yaml
livenessProbe:
  exec:                     # healthy if the command exits with code 0
    command: ["cat", "/tmp/healthy"]
  initialDelaySeconds: 5
  periodSeconds: 5
```

```yaml
readinessProbe:
  tcpSocket:                # healthy if the port accepts a TCP connection
    port: 3306
  periodSeconds: 10
```

```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  periodSeconds: 10
  failureThreshold: 30      # allows up to 30 × 10 s = 5 minutes to start
```

There is also `grpc:` for gRPC services that implement the standard health check.

Good practice:

- The **liveness** endpoint should check only the app itself ("am I alive?"), **not** its dependencies. If it checks the database and the database goes down, every pod restarts at once, which makes things worse.
- The **readiness** endpoint may check dependencies ("can I serve requests?").
- `kubectl describe pod` shows probe failures in Events, for example `Liveness probe failed: HTTP probe failed with statuscode: 500`.

```knowledge-check
{ "questions": [
  { "id": "k8s-sched-writeprobe-q1", "type": "mcq",
    "prompt": "An exec liveness probe runs `cat /tmp/healthy`. The file is deleted. What happens after failureThreshold checks fail?",
    "options": [
      {"id": "a", "text": "Nothing; exec probes only log warnings"},
      {"id": "b", "text": "The kubelet restarts the container"},
      {"id": "c", "text": "The pod is marked Succeeded"},
      {"id": "d", "text": "The node is drained"}
    ],
    "correct": "b",
    "explanation": "cat exits non-zero when the file is missing. Repeated liveness failures make the kubelet restart the container, and RESTARTS goes up." },
  { "id": "k8s-sched-writeprobe-q2", "type": "mcq",
    "prompt": "Why should a liveness probe usually NOT check the database?",
    "options": [
      {"id": "a", "text": "Probes cannot open network connections"},
      {"id": "b", "text": "If the database goes down, every app pod would be restarted at once, even though restarting cannot fix the database"},
      {"id": "c", "text": "Databases do not support HTTP"},
      {"id": "d", "text": "Liveness probes run only once"}
    ],
    "correct": "b",
    "explanation": "Liveness answers 'is this process broken?'. Put dependency checks in readiness, which only stops traffic." }
] }
```

## Resource requests and limits

Think of an Indian Railways ticket. Your **reserved berth** is guaranteed to you, nobody else can be seated there, that is your **request**. The **maximum luggage allowed** per passenger is a hard ceiling you should not cross, that is your **limit**. Each container can declare both:

```yaml
resources:
  requests:            # guaranteed minimum; used by the scheduler
    cpu: 250m          # 250 millicores = a quarter of one CPU core
    memory: 128Mi
  limits:              # hard maximum
    cpu: 500m
    memory: 256Mi
```

- **Units**: CPU in cores or millicores (`1` = `1000m`). Memory in bytes with suffixes: `Mi`/`Gi` (powers of 2) or `M`/`G` (powers of 10).
- **Requests** are used for **scheduling**. The scheduler places a pod only on a node with enough *unrequested* capacity. If no node has room, the pod stays **Pending** with a message like `Insufficient cpu`.
- **Limits** are enforced at **runtime**:
  - Over the **CPU** limit → the container is **throttled** (slowed down), not killed.
  - Over the **memory** limit → the container is **killed** (`OOMKilled`) and restarted.

Kubernetes gives each pod a **QoS class** from these settings. It decides who is evicted first when a node runs low on memory:

| QoS class | When | Evicted |
|---|---|---|
| `Guaranteed` | Every container has requests = limits for both CPU and memory | Last |
| `Burstable` | At least one request or limit set, but not Guaranteed | Middle |
| `BestEffort` | No requests or limits at all | First |

Always set at least memory requests and limits for production apps. Namespaces can enforce defaults with a **LimitRange** and cap total usage with a **ResourceQuota**.

```knowledge-check
{ "questions": [
  { "id": "k8s-sched-resources-q1", "type": "mcq",
    "prompt": "A container with memory limit 256Mi tries to use 400Mi. What happens?",
    "options": [
      {"id": "a", "text": "It is slowed down"},
      {"id": "b", "text": "It is killed (OOMKilled) and restarted"},
      {"id": "c", "text": "The limit is raised automatically"},
      {"id": "d", "text": "The node gets more memory"}
    ],
    "correct": "b",
    "explanation": "Memory cannot be throttled, so exceeding the memory limit kills the container. Exceeding a CPU limit only throttles it." },
  { "id": "k8s-sched-resources-q2", "type": "mcq",
    "prompt": "A pod requests cpu: 8 but every node has only 4 CPUs. What happens?",
    "options": [
      {"id": "a", "text": "It runs slowly on the biggest node"},
      {"id": "b", "text": "It stays Pending; describe shows Insufficient cpu"},
      {"id": "c", "text": "It is split across two nodes"},
      {"id": "d", "text": "It runs as BestEffort"}
    ],
    "correct": "b",
    "explanation": "The scheduler only places a pod where its requests fit. A request larger than any node can never be scheduled." },
  { "id": "k8s-sched-resources-q3", "type": "mcq",
    "prompt": "Which QoS class does a pod get when its only container has requests equal to limits for both CPU and memory?",
    "options": [
      {"id": "a", "text": "BestEffort"},
      {"id": "b", "text": "Burstable"},
      {"id": "c", "text": "Guaranteed"},
      {"id": "d", "text": "Critical"}
    ],
    "correct": "c",
    "explanation": "Requests equal to limits for CPU and memory on every container makes the pod Guaranteed, the last to be evicted." }
] }
```

## Namespace limits: ResourceQuota and LimitRange

Requests and limits control one container. Two more objects control a whole **namespace**.

A **ResourceQuota** caps the total resources a namespace can use, across every pod in it:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 4Gi
    limits.cpu: "8"
    limits.memory: 8Gi
    pods: "20"
```

Once a ResourceQuota exists for `cpu`/`memory` in a namespace, every new pod in that namespace **must** declare requests and limits for those resources, or the API server rejects it. If the namespace's total usage would go over the quota, the new object is rejected outright with an error like `exceeded quota: dev-quota, requested: requests.cpu=2, used: requests.cpu=3, limited: requests.cpu=4`.

A **LimitRange** fills in defaults so people do not have to type requests/limits on every single pod, and can also set min/max bounds:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
  namespace: dev
spec:
  limits:
  - type: Container
    default:              # applied as the limit if a container does not set one
      cpu: 500m
      memory: 256Mi
    defaultRequest:        # applied as the request if a container does not set one
      cpu: 250m
      memory: 128Mi
    max:
      cpu: "2"
      memory: 1Gi
```

Put both together and you get a namespace that is safe by default: a LimitRange fills in sane requests/limits automatically, and a ResourceQuota stops the namespace as a whole from ever using more than you have budgeted for it.

```knowledge-check
{ "questions": [
  { "id": "k8s-sched-quota-q1", "type": "mcq",
    "prompt": "A namespace has a ResourceQuota on requests.cpu of 4, and it is already using all 4. Someone tries to create one more pod that requests cpu. What happens?",
    "options": [
      {"id": "a", "text": "The pod is created and runs slower"},
      {"id": "b", "text": "The API server rejects creating the pod, with an 'exceeded quota' error"},
      {"id": "c", "text": "The oldest pod in the namespace is deleted to make room"},
      {"id": "d", "text": "The quota is automatically raised"}
    ],
    "correct": "b",
    "explanation": "A ResourceQuota is a hard cap enforced by the API server at creation time. Going over it rejects the new object instead of scaling anything down." },
  { "id": "k8s-sched-quota-q2", "type": "mcq",
    "prompt": "A namespace has a ResourceQuota on cpu and memory. A developer creates a pod with no resources section at all. What determines its requests and limits?",
    "options": [
      {"id": "a", "text": "It gets unlimited resources since none were set"},
      {"id": "b", "text": "The pod is rejected, unless a LimitRange in the namespace supplies default requests/limits"},
      {"id": "c", "text": "Kubernetes guesses based on the image size"},
      {"id": "d", "text": "It is scheduled as Guaranteed automatically"}
    ],
    "correct": "b",
    "explanation": "Once a ResourceQuota covers cpu/memory, pods must declare requests/limits. A LimitRange with default and defaultRequest values can supply them automatically so the pod does not have to spell them out." }
] }
```

## Choosing nodes: nodeSelector and node affinity

By default the scheduler may place a pod on any node with enough room. To keep pods on specific nodes (for example, nodes with GPUs or SSDs), label the nodes and select them.

**nodeSelector** is the simple way: the node must have **all** listed labels.

```bash
kubectl label node node1 disktype=ssd
```

```yaml
spec:
  nodeSelector:
    disktype: ssd
```

**Node affinity** is the flexible version, with operators and soft preferences:

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:     # hard rule
        nodeSelectorTerms:
        - matchExpressions:
          - key: app
            operator: In               # In, NotIn, Exists, DoesNotExist, Gt, Lt
            values: ["production"]
      preferredDuringSchedulingIgnoredDuringExecution:    # soft rule
      - weight: 2                      # 1-100; higher weight wins
        preference:
          matchExpressions:
          - key: app
            operator: In
            values: ["test"]
```

How to read the long names:

- **`required...`**: a hard rule. If no node matches, the pod stays **Pending** until one does.
- **`preferred...`**: a wish. The scheduler tries matching nodes first (higher `weight` = stronger preference), but runs the pod elsewhere if needed.
- **`...IgnoredDuringExecution`**: the rule is only checked when the pod is scheduled. If you remove the label from the node later, pods already running there **stay**.

```bash
kubectl label node minikube app=production     # add a label
kubectl label node minikube app-               # remove it
kubectl get nodes --show-labels
```

```knowledge-check
{ "questions": [
  { "id": "k8s-sched-affinity-q1", "type": "mcq",
    "prompt": "A pod has a required node affinity for app=production, but no node has that label. What happens?",
    "options": [
      {"id": "a", "text": "It runs on any node"},
      {"id": "b", "text": "It stays Pending until a node gets the label"},
      {"id": "c", "text": "It is deleted"},
      {"id": "d", "text": "The scheduler adds the label to a node"}
    ],
    "correct": "b",
    "explanation": "Required rules are hard constraints. Once you label a node app=production, the pod is scheduled there." },
  { "id": "k8s-sched-affinity-q2", "type": "mcq",
    "prompt": "A pod was scheduled because of a required affinity to disktype=ssd. You then remove that label from the node. What happens to the running pod?",
    "options": [
      {"id": "a", "text": "It is evicted immediately"},
      {"id": "b", "text": "It keeps running, because the rule is IgnoredDuringExecution"},
      {"id": "c", "text": "It is restarted on the same node"},
      {"id": "d", "text": "It becomes Pending"}
    ],
    "correct": "b",
    "explanation": "IgnoredDuringExecution means the rule is checked only at scheduling time." }
] }
```

## Spreading pods: pod anti-affinity and topology spread

Three replicas on the same node do not protect you when that node dies. You can tell the scheduler to spread them.

**Pod anti-affinity**: "do not put me on a node that already runs a pod with label app=web":

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            app: web
        topologyKey: kubernetes.io/hostname    # "same node" = same hostname label
```

**Pod affinity** is the opposite: place a pod *near* another (for example, a cache next to its app).

**topologySpreadConstraints** is the modern, simpler way to spread evenly across nodes or zones:

```yaml
topologySpreadConstraints:
- maxSkew: 1                                  # counts may differ by at most 1
  topologyKey: topology.kubernetes.io/zone    # spread across availability zones
  whenUnsatisfiable: ScheduleAnyway
  labelSelector:
    matchLabels:
      app: web
```

```knowledge-check
{ "questions": [
  { "id": "k8s-sched-spread-q1", "type": "mcq",
    "prompt": "You want the 3 replicas of a Deployment to land on 3 different nodes if possible. Which feature fits?",
    "options": [
      {"id": "a", "text": "nodeSelector"},
      {"id": "b", "text": "Pod anti-affinity (or topologySpreadConstraints) on the pods' own label with topologyKey kubernetes.io/hostname"},
      {"id": "c", "text": "A DaemonSet"},
      {"id": "d", "text": "A NoExecute taint"}
    ],
    "correct": "b",
    "explanation": "Anti-affinity against its own label keeps replicas apart. Topology spread constraints do the same with an explicit skew." }
] }
```

## Taints and tolerations

Affinity *attracts* pods to nodes. **Taints** do the opposite: they *repel* pods from a node. Think of a reserved train coach, "ladies only" or a defence-quota coach: an ordinary passenger cannot sit there. Only someone holding the matching ticket, the **toleration**, is allowed in. A pod can only be scheduled onto a tainted node if it has a matching toleration.

```bash
kubectl taint node node1 app=production:NoSchedule     # add a taint (key=value:effect)
kubectl taint node node1 app-                          # remove all taints with key app
kubectl describe node node1 | grep Taints
```

The three **effects**:

| Effect | Meaning |
|---|---|
| `NoSchedule` | New pods without a toleration are not scheduled here. Pods already running stay. |
| `PreferNoSchedule` | Avoid this node if possible (soft version). |
| `NoExecute` | New pods are not scheduled, **and running pods without a toleration are evicted.** |

A toleration in the pod spec:

```yaml
tolerations:
- key: "app"
  operator: "Equal"        # key and value must match
  value: "production"
  effect: "NoSchedule"
- key: "gpu"
  operator: "Exists"       # any value of key gpu
  effect: "NoSchedule"
```

Important: a toleration only **allows** a pod onto a tainted node. It does not **send** it there. To *dedicate* nodes to a team or workload, combine both: taint the nodes (keep others off) **and** add node affinity to the right pods (pull them on).

You have already met a real taint: control-plane nodes carry `node-role.kubernetes.io/control-plane:NoSchedule`, which is why your apps do not run there. Kubernetes also adds taints automatically, such as `node.kubernetes.io/not-ready:NoExecute` when a node fails. Pods tolerate that one for 5 minutes by default before they are evicted and rescheduled elsewhere.

```knowledge-check
{ "questions": [
  { "id": "k8s-sched-taint-q1", "type": "mcq",
    "prompt": "A node gets the taint maintenance=true:NoExecute. What happens to running pods that do not tolerate it?",
    "options": [
      {"id": "a", "text": "They keep running; only new pods are blocked"},
      {"id": "b", "text": "They are evicted from the node"},
      {"id": "c", "text": "They are paused"},
      {"id": "d", "text": "They get the toleration added automatically"}
    ],
    "correct": "b",
    "explanation": "NoExecute evicts running pods without a matching toleration. NoSchedule would only affect new pods." },
  { "id": "k8s-sched-taint-q2", "type": "mcq",
    "prompt": "A pod tolerates gpu=true:NoSchedule. The cluster has one tainted GPU node and five normal nodes. Where can the pod run?",
    "options": [
      {"id": "a", "text": "Only on the GPU node"},
      {"id": "b", "text": "On any of the six nodes; the toleration permits the GPU node but does not force it"},
      {"id": "c", "text": "Only on the five normal nodes"},
      {"id": "d", "text": "Nowhere"}
    ],
    "correct": "b",
    "explanation": "Tolerations allow, they do not attract. Add node affinity to require the GPU node." }
] }
```

## Interview questions and real-world scenarios

**Q: How does the scheduler pick a node?**
Filter (nodes that fit requests, selectors, affinity, taints, volumes), then score (spread, preferences, balance), then bind the pod to the best node.

**Q: What are QoS classes and why do they matter?**
Guaranteed, Burstable, BestEffort, derived from requests and limits. Under memory pressure the kubelet evicts BestEffort first and Guaranteed last.

**Q: Should you set CPU limits?**
A real debate. CPU limits can cause throttling even when the node has idle CPU, so many teams set CPU **requests** always, memory requests and limits always, and CPU limits only where they need strict isolation. Showing you know the trade-off is what counts in interviews.

**Q: Liveness vs readiness: which one would you add first?**
Readiness, because it protects users during rollouts and startup. A badly written liveness probe can cause restart storms.

**Q: Taints vs node affinity: when do you use which?**
Taints keep unwanted pods off nodes (dedicated or special nodes). Affinity steers pods onto nodes. Use both to dedicate a node pool.

**Q: What is a PriorityClass?**
It gives pods a priority. When the cluster is full, the scheduler can preempt (evict) lower-priority pods to make room for higher-priority ones, which is useful for critical system workloads.

**Real-world scenario: a Java service is OOMKilled although its heap is set to 512MB and the limit is 600MB.**
The JVM uses memory beyond the heap (metaspace, threads, buffers). Leave headroom, or size the heap from the container limit (`-XX:MaxRAMPercentage=75`).

**Real-world scenario: all replicas went down together when one node failed.**
They were all scheduled on the same node. Add topologySpreadConstraints or pod anti-affinity across nodes and zones, and a PodDisruptionBudget.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-sched-int-q1",
      "type": "mcq",
      "prompt": "All three replicas of a service ran on one node, and a node failure took the service down. What prevents this?",
      "options": [
        {
          "id": "a",
          "text": "A higher CPU request"
        },
        {
          "id": "b",
          "text": "topologySpreadConstraints or pod anti-affinity on kubernetes.io/hostname (and zones)"
        },
        {
          "id": "c",
          "text": "A liveness probe"
        },
        {
          "id": "d",
          "text": "A NodePort Service"
        }
      ],
      "correct": "b",
      "explanation": "Spreading replicas across failure domains is the fix; probes and resources do not control placement."
    }
  ]
}
```
