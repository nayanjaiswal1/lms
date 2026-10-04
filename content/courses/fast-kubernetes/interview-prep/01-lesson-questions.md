---
kind: lesson
id_key: k8s/interview-prep/lesson-questions
course: fast-kubernetes
section: interview-prep
section_title: Interview Prep & Production Troubleshooting
section_position: 12
title: Kubernetes Interview Questions and Answers
position: 0
estimated_minutes: 60
source:
  - README.md
---

This lesson collects the Kubernetes questions that come up again and again in DevOps, SRE, platform and backend interviews. They go from basic to advanced, with short, correct answers you can say out loud. Everything here was taught earlier in the course; the goal now is to **explain it clearly and connect it to real situations**.

How to answer well in an interview:

1. **Define** the thing in one sentence.
2. Say **why it exists** (the problem it solves).
3. Give a **real example** or a gotcha you know about. This is what separates people who have used Kubernetes from people who have only read about it.

## Basic questions

**1. What is Kubernetes and why use it?**
An open-source container orchestrator. You declare the desired state (which containers, how many, how they connect) and Kubernetes keeps the cluster in that state: it schedules containers across machines, restarts failed ones, scales them, rolls out updates without downtime, and gives them stable networking and config.

**2. Explain the Kubernetes architecture.**
A control plane (kube-apiserver as the only entry point, etcd as the state store, kube-scheduler to place pods, kube-controller-manager running the reconcile loops) and worker nodes (kubelet to run pods, a container runtime such as containerd, kube-proxy for Service networking). A CNI plugin provides pod networking and CoreDNS provides service discovery.

**3. What is a pod? Why not just containers?**
The smallest deployable unit: one or more containers that share a network namespace (one IP, localhost), volumes and lifecycle. Pods let tightly coupled helpers (sidecars) run next to the main container. Pods are disposable; controllers replace them.

**4. What happens when you run `kubectl apply -f deployment.yaml`?**
kubectl sends the object to the API server → authentication, authorization (RBAC), admission → stored in etcd → the Deployment controller creates a ReplicaSet → the ReplicaSet controller creates pods → the scheduler assigns each pod to a node → the kubelet on that node tells containerd to pull the image and start containers → the CNI plugin gives the pod an IP → once ready, the pod is added to matching Service endpoints.

**5. Deployment vs ReplicaSet vs Pod?**
A pod runs containers. A ReplicaSet keeps N identical pods running. A Deployment manages ReplicaSets to add rolling updates and rollbacks. You create Deployments; the other two are created for you.

**6. What is a namespace?**
A way to split one cluster into named areas for names, RBAC, quotas and policies. It does not isolate the network by default, and nodes and PVs are not namespaced.

**7. What are labels and selectors?**
Key-value tags on objects, and queries that match them. Deployments find their pods, Services find their endpoints, and scheduling rules find nodes, all by label. A label/selector mismatch is a very common cause of "nothing is connected".

**8. What is a Service? Name the types.**
A stable virtual IP and DNS name in front of a changing set of pods chosen by selector. ClusterIP (internal, default), NodePort (a port on every node), LoadBalancer (cloud load balancer), ExternalName (DNS alias). Headless (clusterIP: None) returns pod IPs directly.

**9. ConfigMap vs Secret?**
Both inject configuration as env vars or files. Secrets are for sensitive data, are base64-encoded (not encrypted by default), can be encrypted at rest and should be restricted with RBAC.

**10. What is kubelet? What is kube-proxy?**
kubelet is the node agent that runs the pods assigned to its node and reports their status. kube-proxy programs iptables/IPVS rules so Service IPs reach the right pod IPs (some CNIs like Cilium replace it).

```knowledge-check
{ "questions": [
  { "id": "k8s-int-basic-q1", "type": "mcq",
    "prompt": "In the `kubectl apply` flow, which component actually chooses the node for a new pod?",
    "options": [
      {"id": "a", "text": "The Deployment controller"},
      {"id": "b", "text": "The kube-scheduler"},
      {"id": "c", "text": "The kubelet"},
      {"id": "d", "text": "etcd"}
    ],
    "correct": "b",
    "explanation": "Controllers create pod objects, the scheduler binds them to nodes, and the kubelet on that node runs them." }
] }
```

## Intermediate questions

**11. How does a rolling update work? How do you make it zero-downtime?**
The Deployment creates a new ReplicaSet and shifts pods over gradually within `maxSurge`/`maxUnavailable`. For zero downtime you also need: a readiness probe (so new pods get traffic only when ready), at least 2 replicas, `maxUnavailable: 0`, graceful shutdown (handle SIGTERM, maybe a `preStop` sleep so the load balancer stops sending traffic first), and a PodDisruptionBudget.

**12. How do you roll back?**
`kubectl rollout undo deployment/<name>` (or `--to-revision=N`). With Helm: `helm rollback <release> <revision>`. In GitOps: revert the commit.

**13. Liveness vs readiness vs startup probes?**
Liveness failure → restart the container. Readiness failure → remove from Service endpoints, no restart. Startup → hold the other probes until a slow app has started. Don't check dependencies in liveness, or a database outage restarts every pod.

**14. Requests vs limits? What happens when they are exceeded?**
Requests are reserved and used for scheduling. Limits are hard caps: over the CPU limit the container is throttled, over the memory limit it is OOMKilled. QoS classes (Guaranteed, Burstable, BestEffort) decide eviction order under node pressure.

**15. StatefulSet vs Deployment?**
A StatefulSet gives stable pod names (app-0, app-1), stable DNS through a headless Service, ordered start and stop, and a separate PVC per pod that follows it. Use it for databases and clustered systems; use Deployments for stateless apps.

**16. DaemonSet use cases?**
One pod per node: log collectors, monitoring agents (node-exporter), CNI and storage drivers, kube-proxy itself.

**17. Job vs CronJob?**
A Job runs pods to successful completion (with `completions`, `parallelism`, `backoffLimit`). A CronJob creates Jobs on a cron schedule (`concurrencyPolicy` controls overlap).

**18. PV vs PVC vs StorageClass?**
A PV is actual storage; a PVC is a request for storage that binds to a PV; a StorageClass lets a provisioner create PVs dynamically. Know the access modes (RWO, ROX, RWX, RWOP) and reclaim policies (Retain vs Delete).

**19. How does service discovery work?**
CoreDNS gives every Service a name `<svc>.<ns>.svc.cluster.local`. Pods resolve short names within their namespace. Environment variables for Services also exist but depend on creation order, so DNS is preferred.

**20. Ingress vs LoadBalancer Service? What is Gateway API?**
A LoadBalancer Service exposes one service with its own external load balancer (L4). An Ingress routes HTTP(S) by host and path to many Services behind one entry point and needs an ingress controller. Gateway API is the newer, more expressive successor (GatewayClass/Gateway/HTTPRoute, with traffic splitting and header matching built in).

**21. Taints/tolerations vs node affinity?**
Taints repel pods from nodes unless they tolerate them; affinity attracts pods to nodes. To dedicate nodes, use both.

**22. How do you secure Secrets?**
RBAC to limit access, encryption at rest in etcd (KMS), no plain Secrets in Git (Sealed Secrets, SOPS, External Secrets Operator with a vault), mount as files rather than env vars, and short-lived credentials (workload identity) where possible.

```knowledge-check
{ "questions": [
  { "id": "k8s-int-mid-q1", "type": "mcq",
    "prompt": "An interviewer asks how to guarantee zero downtime during deployments. Which answer is most complete?",
    "options": [
      {"id": "a", "text": "Use the Recreate strategy"},
      {"id": "b", "text": "RollingUpdate with maxUnavailable 0, readiness probes, 2+ replicas, graceful SIGTERM handling, and a PodDisruptionBudget"},
      {"id": "c", "text": "Set replicas to 1 and use a liveness probe"},
      {"id": "d", "text": "Delete the old pods first, then apply"}
    ],
    "correct": "b",
    "explanation": "Rolling updates only avoid downtime when traffic reaches pods only once they're ready and in-flight requests finish cleanly on shutdown." }
] }
```

## Advanced questions

**23. What happens when a node dies?**
The kubelet stops renewing its Lease; the node-lifecycle controller marks it NotReady and adds `not-ready`/`unreachable` NoExecute taints. After the default 5-minute toleration, its pods are evicted and controllers recreate them on healthy nodes. StatefulSet pods are not recreated elsewhere until the old pod is confirmed gone, to avoid two pods using the same identity and disk.

**24. How does the scheduler decide?**
Two phases. **Filtering** removes nodes that cannot run the pod (not enough requested CPU/memory, taints, node selectors/affinity, volume topology, ports). **Scoring** ranks the rest (spreading, affinity preferences, balanced resource use). The best node wins and the pod is bound to it.

**25. What is etcd and why odd numbers of members?**
A consistent key-value store using the Raft consensus algorithm. Writes need a majority (quorum). 3 members tolerate 1 failure and 5 tolerate 2; an even number adds no extra fault tolerance.

**26. How do you upgrade a cluster safely?**
Check deprecated APIs first, back up etcd, upgrade one minor version at a time, control plane before nodes, then drain, upgrade and uncordon nodes one by one (or roll new node pools), with PDBs protecting apps.

**27. Explain RBAC.**
Roles/ClusterRoles define verbs on resources; RoleBindings/ClusterRoleBindings grant them to users, groups or ServiceAccounts. It is additive only, with no deny rules. Follow least privilege and be careful with secrets, pods/exec and escalate/bind verbs.

**28. How does HPA work?**
Every 15 seconds it reads metrics (metrics-server or custom/external metrics) and computes `desired = ceil(current × currentValue / targetValue)`, bounded by min/max, with a stabilization window for scaling down. Utilization is relative to requests. Pair it with a cluster autoscaler for node capacity.

**29. What are CRDs and operators?**
A CustomResourceDefinition adds a new kind to the API (for example `PostgresCluster`). An operator is a controller that watches those objects and runs the operational knowledge (provision, failover, backup) in code. Examples: Prometheus Operator, cert-manager, CloudNativePG, Strimzi.

**30. What is the pod network model and what does CNI do?**
Every pod gets a unique IP and can reach every other pod without NAT. The CNI plugin sets up the pod's network interface, assigns the IP and makes routing between nodes work (overlay such as VXLAN, or native routing/BGP). Calico and Cilium also enforce NetworkPolicy.

**31. How do you make a workload highly available?**
Multiple replicas; spread across nodes and zones (topology spread or anti-affinity); readiness probes; PDBs; resource requests; no single-node storage (or replicate the database); multi-zone control plane (managed clusters do this).

**32. What is GitOps?**
Git holds the desired state of the cluster; a controller in the cluster (Argo CD or Flux) continuously syncs it and reverts drift. Deploys and rollbacks become Git commits and reverts, with a full audit trail.

```knowledge-check
{ "questions": [
  { "id": "k8s-int-adv-q1", "type": "mcq",
    "prompt": "A node loses power. Roughly how long until its Deployment pods are recreated elsewhere with default settings?",
    "options": [
      {"id": "a", "text": "Immediately"},
      {"id": "b", "text": "About 5 minutes (node marked NotReady, then the default 300s toleration for not-ready/unreachable taints expires)"},
      {"id": "c", "text": "Never; you must drain it"},
      {"id": "d", "text": "24 hours"}
    ],
    "correct": "b",
    "explanation": "Pods tolerate the not-ready/unreachable taints for 300 seconds by default before eviction. You can shorten this per pod with tolerationSeconds." },
  { "id": "k8s-int-adv-q2", "type": "mcq",
    "prompt": "What is a Kubernetes operator?",
    "options": [
      {"id": "a", "text": "A person with cluster-admin rights"},
      {"id": "b", "text": "A controller that manages a custom resource and automates the operations of a complex app"},
      {"id": "c", "text": "The kubectl binary"},
      {"id": "d", "text": "A type of Service"}
    ],
    "correct": "b",
    "explanation": "Operators extend the reconcile-loop idea to apps like databases: a CRD describes the desired app, and the operator's controller makes it so." }
] }
```

## Scenario and design questions

These have no single correct answer. Interviewers want to hear a structured approach.

**33. "Design the Kubernetes setup for a typical web app (frontend, API, PostgreSQL, Redis)."**
Namespaces per environment. Frontend and API as Deployments (2+ replicas, readiness/liveness probes, requests/limits, HPA, PDB, topology spread). ClusterIP Services; one Ingress or Gateway with TLS from cert-manager. Config in ConfigMaps, secrets from a vault through External Secrets. PostgreSQL as a managed cloud database (or an operator such as CloudNativePG with backups), Redis via a managed service or a StatefulSet. Prometheus/Grafana/Loki for observability, alerts on error rate and latency. Everything deployed with Helm or Kustomize through GitOps, with NetworkPolicies allowing only frontend → API → data.

**34. "Pods keep getting OOMKilled after a release. What do you do?"**
Confirm with `kubectl describe pod` (Last State: OOMKilled) and memory graphs. Short-term: roll back or raise the memory limit. Then find the cause: a memory leak in the new version, a bigger cache, or a JVM/Node heap setting that ignores the container limit (for example Java's `-XX:MaxRAMPercentage`). Set requests to real usage and limits with headroom.

**35. "Users report intermittent 502 errors during deployments."**
Classic causes: no readiness probe; pods killed before the load balancer stops routing to them (add a `preStop` sleep of a few seconds, handle SIGTERM, set `terminationGracePeriodSeconds`); `maxUnavailable` too high; keep-alive connections to terminated pods. Check the ingress controller logs and the endpoints during a rollout.

**36. "The cluster is out of capacity and pods are Pending."**
`kubectl describe pod` shows `Insufficient cpu/memory`. Check real usage vs requests (`kubectl top`): requests may be far above usage, so right-size them (VPA recommendations help). Add nodes or enable the Cluster Autoscaler/Karpenter. Set ResourceQuotas so one team cannot take everything, and use PriorityClasses so critical pods win.

**37. "How would you give developers access without letting them break production?"**
SSO via OIDC; groups mapped to RBAC. Developers get `edit` in dev namespaces and `view` in production. Production changes only through CI/GitOps, whose ServiceAccount has scoped rights. Pod Security Admission restricted, policies with Kyverno/Gatekeeper, and audit logging.

**38. "A Secret was accidentally committed to Git."**
Treat it as leaked: **rotate** the credential immediately (removing it from Git history is not enough), check access logs, then move to Sealed Secrets or External Secrets and add secret scanning to CI.

```knowledge-check
{ "questions": [
  { "id": "k8s-int-scenario-q1", "type": "mcq",
    "prompt": "A database password was pushed to a public Git repo in a Secret manifest. What is the FIRST priority?",
    "options": [
      {"id": "a", "text": "Rewrite Git history to remove it"},
      {"id": "b", "text": "Rotate the password immediately, because it must be treated as compromised"},
      {"id": "c", "text": "Make the repository private"},
      {"id": "d", "text": "Base64-encode it twice"}
    ],
    "correct": "b",
    "explanation": "Once exposed, a secret may already be copied. Rotating it is the only real fix; cleaning history and adding tooling come after." },
  { "id": "k8s-int-scenario-q2", "type": "mcq",
    "prompt": "During every rollout a few requests fail with 502. Readiness probes exist. What is the most likely missing piece?",
    "options": [
      {"id": "a", "text": "A bigger node"},
      {"id": "b", "text": "Graceful shutdown: handle SIGTERM and add a short preStop delay so traffic drains before the container stops"},
      {"id": "c", "text": "A liveness probe on the database"},
      {"id": "d", "text": "A NodePort Service"}
    ],
    "correct": "b",
    "explanation": "Endpoint removal and container termination happen in parallel. A brief preStop sleep plus proper SIGTERM handling lets in-flight requests finish." }
] }
```
