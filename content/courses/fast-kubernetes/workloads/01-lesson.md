---
kind: lesson
id_key: k8s/workloads/lesson
course: fast-kubernetes
section: workloads
section_title: Deployments & Workload Controllers
section_position: 3
title: 'Deployments: Scaling, Self-Healing and Rolling Updates'
position: 0
estimated_minutes: 50
source:
  - K8s-Deployment.md
  - K8s-Rollout-Rollback.md
---

In the last section you saw that a bare pod is gone for good when it dies. A **Deployment** fixes that. You tell it "run N copies of this pod", and it keeps exactly N running, replaces broken ones, and updates them to new versions without downtime. Most stateless apps (web servers, APIs) run as Deployments.

A Deployment behaves like a hostel warden who has to keep exactly 100 students in the hostel at all times. The warden does not care which 100 students they are, only that the count stays at 100. If one leaves, the warden brings in a replacement. If the hostel switches to a new uniform, the warden swaps students out gradually so the hostel is never empty.

## Deployment, ReplicaSet and Pod

There are three layers, each managing the one below it:

```
Deployment  →  ReplicaSet  →  Pods
(versions,     (keeps N       (run the
 updates)       copies)        containers)
```

- A **ReplicaSet** keeps a set number of identical pods running. If one disappears, it creates another.
- A **Deployment** manages ReplicaSets. Every time you change the pod template (for example, a new image), it creates a *new* ReplicaSet and shifts pods from the old one to the new one. That is how rolling updates and rollbacks work.

You create Deployments. You almost never create ReplicaSets yourself.

The pod names show this chain. A Deployment called `firstdeployment` creates a ReplicaSet like `firstdeployment-7d9f8c6b5` (with a hash of the template), which creates pods like `firstdeployment-7d9f8c6b5-x2k4q`.

```knowledge-check
{ "questions": [
  { "id": "k8s-deploy-layers-q1", "type": "mcq",
    "prompt": "You change the image of a Deployment. What happens to ReplicaSets?",
    "options": [
      {"id": "a", "text": "The existing ReplicaSet edits its pods in place"},
      {"id": "b", "text": "The Deployment creates a new ReplicaSet for the new template and scales the old one down"},
      {"id": "c", "text": "All ReplicaSets are deleted and recreated at once"},
      {"id": "d", "text": "Nothing; ReplicaSets ignore image changes"}
    ],
    "correct": "b",
    "explanation": "Each version of the pod template gets its own ReplicaSet. The old one is kept (scaled to 0) so you can roll back to it." }
] }
```

## Writing a Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: firstdeployment
  labels:
    team: development
spec:
  replicas: 3                  # how many pods you want
  selector:
    matchLabels:
      app: frontend            # which pods this Deployment owns
  template:                    # the pod to create, same fields as a Pod manifest
    metadata:
      labels:
        app: frontend          # MUST match the selector above
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
```

The one rule people get wrong: **`spec.selector.matchLabels` must match `spec.template.metadata.labels`**. The Deployment finds its pods by those labels. If they do not match, the API server rejects the Deployment. Also, the selector cannot be changed after creation.

```bash
kubectl apply -f deployment1.yaml
kubectl get deployments              # READY 3/3, UP-TO-DATE, AVAILABLE
kubectl get rs                       # the ReplicaSet it created
kubectl get pods -l app=frontend -o wide
kubectl describe deployment firstdeployment
```

```knowledge-check
{ "questions": [
  { "id": "k8s-deploy-yaml-q1", "type": "mcq",
    "prompt": "In a Deployment, spec.selector.matchLabels is `app: api` but the pod template has `app: backend`. What happens when you apply it?",
    "options": [
      {"id": "a", "text": "It works, and the Deployment adopts all pods in the namespace"},
      {"id": "b", "text": "The API server rejects it because the selector does not match the template labels"},
      {"id": "c", "text": "The pods are created without labels"},
      {"id": "d", "text": "Kubernetes rewrites the template labels to match"}
    ],
    "correct": "b",
    "explanation": "The selector must match the template's labels, otherwise the Deployment could never find the pods it creates. The API server validates this." }
] }
```

## Self-healing and scaling

Delete one of the pods and watch:

```bash
kubectl delete pod <one-of-the-pod-names>
kubectl get pods -l app=frontend        # a new pod with a new name appears
```

The ReplicaSet saw 2 pods where 3 were wanted and created a replacement. That is the reconcile loop from the first lesson.

**Scaling** changes the number of copies:

```bash
kubectl scale deployment firstdeployment --replicas=5    # imperative
# or change replicas: 5 in the YAML and run kubectl apply -f again (declarative)
kubectl scale deployment firstdeployment --replicas=3
```

When scaling down, Kubernetes chooses which pods to remove (it prefers pods that are not ready or are newest). Do not rely on a particular pod surviving.

If you scale with `kubectl scale` but keep `replicas: 3` in your YAML file, the next `kubectl apply` puts it back to 3. Keep the file as the source of truth. (If you use a HorizontalPodAutoscaler, covered later, leave `replicas` out of the file and let the autoscaler own it.)

```knowledge-check
{ "questions": [
  { "id": "k8s-deploy-scale-q1", "type": "mcq",
    "prompt": "You ran `kubectl scale deployment web --replicas=10`, but web.yaml still says replicas: 3. Later a teammate runs `kubectl apply -f web.yaml`. How many replicas run afterwards?",
    "options": [
      {"id": "a", "text": "10"},
      {"id": "b", "text": "3"},
      {"id": "c", "text": "13"},
      {"id": "d", "text": "0"}
    ],
    "correct": "b",
    "explanation": "apply sets the object to what the file says. Imperative changes that are not written back to the file get overwritten." }
] }
```

## Update strategies: Recreate and RollingUpdate

When the pod template changes, the Deployment replaces old pods with new ones. `spec.strategy` controls how.

**Recreate**: delete all old pods first, then create the new ones. There is downtime between the two. Use it only when two versions must never run at the same time (for example, an app that cannot share its database schema between versions).

```yaml
spec:
  strategy:
    type: Recreate
```

**RollingUpdate** (the default): replace pods gradually, so the app keeps serving during the update.

```yaml
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 2    # at most 2 of the 10 may be down at a time → at least 8 serve traffic
      maxSurge: 2          # at most 2 extra pods may exist → at most 12 pods in total
```

Both values can be numbers or percentages. The defaults are `25%` each. `maxUnavailable: 0` with `maxSurge: 1` gives the safest update: a new pod must be ready before an old one is removed.

A rolling update only counts a new pod as available once it is **ready**. Without a readiness probe (covered in the health section) Kubernetes assumes a pod is ready the moment its container starts, even if the app needs 30 seconds to warm up.

```knowledge-check
{ "questions": [
  { "id": "k8s-deploy-strategy-q1", "type": "mcq",
    "prompt": "A Deployment has replicas: 10, maxUnavailable: 2, maxSurge: 2. During a rolling update, what are the minimum and maximum number of pods?",
    "options": [
      {"id": "a", "text": "Minimum 8 available, maximum 12 in total"},
      {"id": "b", "text": "Minimum 10, maximum 10"},
      {"id": "c", "text": "Minimum 2, maximum 4"},
      {"id": "d", "text": "Minimum 0, maximum 20"}
    ],
    "correct": "a",
    "explanation": "maxUnavailable 2 means at least 10 - 2 = 8 are available. maxSurge 2 means at most 10 + 2 = 12 pods exist." },
  { "id": "k8s-deploy-strategy-q2", "type": "mcq",
    "prompt": "Which strategy causes a short period where no pods are serving?",
    "options": [
      {"id": "a", "text": "RollingUpdate"},
      {"id": "b", "text": "Recreate"},
      {"id": "c", "text": "Both"},
      {"id": "d", "text": "Neither"}
    ],
    "correct": "b",
    "explanation": "Recreate deletes every old pod before starting new ones, so there is downtime in between." }
] }
```

## Rolling out a new version

Three ways to change the image:

```bash
# 1. Imperative: container name = new image
kubectl set image deployment/rolldeployment nginx=nginx:1.27.1

# 2. Edit the live object in an editor (vi by default)
kubectl edit deployment rolldeployment

# 3. Declarative (best): change the image in the YAML, then
kubectl apply -f rolling-deployment.yaml
```

Watch the rollout:

```bash
kubectl rollout status deployment/rolldeployment     # waits until it finishes or fails
kubectl get rs -w                                    # new ReplicaSet grows, old one shrinks
```

Record *why* you changed something, so the history is readable. The old `--record` flag is deprecated. Set the `kubernetes.io/change-cause` annotation instead:

```bash
kubectl annotate deployment/rolldeployment kubernetes.io/change-cause="upgrade nginx to 1.27.1"
```

```knowledge-check
{ "questions": [
  { "id": "k8s-deploy-rollout-q1", "type": "mcq",
    "prompt": "Which command changes the image of the container named nginx in deployment web to nginx:1.27?",
    "options": [
      {"id": "a", "text": "kubectl set image deployment/web nginx=nginx:1.27"},
      {"id": "b", "text": "kubectl update web --image=nginx:1.27"},
      {"id": "c", "text": "kubectl rollout image web nginx:1.27"},
      {"id": "d", "text": "kubectl scale deployment/web --image=nginx:1.27"}
    ],
    "correct": "a",
    "explanation": "set image takes container-name=image pairs. It changes the pod template, which triggers a rolling update." }
] }
```

## Rollback, history, pause and resume

Every template change creates a new **revision**. Kubernetes keeps old ReplicaSets (10 by default, set by `revisionHistoryLimit`) so you can go back.

```bash
kubectl rollout history deployment/rolldeployment                 # list revisions
kubectl rollout history deployment/rolldeployment --revision=2    # details of one
kubectl rollout undo deployment/rolldeployment                    # back to the previous revision
kubectl rollout undo deployment/rolldeployment --to-revision=1    # back to a specific one
```

A rollback is itself a new rollout: the old template becomes the newest revision.

You can **pause** a rollout to make several changes and then release them together, or to stop a bad update from spreading:

```bash
kubectl rollout pause deployment/rolldeployment
kubectl set image deployment/rolldeployment nginx=nginx:1.27.2
kubectl set resources deployment/rolldeployment -c nginx --limits=memory=256Mi
kubectl rollout resume deployment/rolldeployment      # both changes roll out as one
```

`kubectl rollout restart deployment/<name>` replaces all pods with fresh ones without changing the template. It is handy after a ConfigMap or Secret change.

```knowledge-check
{ "questions": [
  { "id": "k8s-deploy-rollback-q1", "type": "mcq",
    "prompt": "Version 3 of your app has a bug. What is the fastest way to go back to the previous version?",
    "options": [
      {"id": "a", "text": "kubectl delete deployment and recreate it"},
      {"id": "b", "text": "kubectl rollout undo deployment/<name>"},
      {"id": "c", "text": "kubectl rollout pause deployment/<name>"},
      {"id": "d", "text": "kubectl scale deployment/<name> --replicas=0"}
    ],
    "correct": "b",
    "explanation": "rollout undo switches back to the previous ReplicaSet's template with a normal rolling update, so there is no downtime." },
  { "id": "k8s-deploy-rollback-q2", "type": "mcq",
    "prompt": "What does `kubectl rollout pause` do?",
    "options": [
      {"id": "a", "text": "Stops all pods of the Deployment"},
      {"id": "b", "text": "Stops new template changes from being rolled out until you resume"},
      {"id": "c", "text": "Freezes the processes inside containers"},
      {"id": "d", "text": "Deletes the rollout history"}
    ],
    "correct": "b",
    "explanation": "While paused, changes to the template are recorded but not rolled out. Existing pods keep running. resume rolls out everything at once." }
] }
```

## Interview questions and real-world scenarios

**Q: Deployment vs ReplicaSet?**
A ReplicaSet keeps N identical pods. A Deployment manages ReplicaSets to provide rolling updates, history and rollbacks. You work with Deployments.

**Q: Explain maxSurge and maxUnavailable.**
maxSurge: how many extra pods above `replicas` may exist during an update. maxUnavailable: how many may be missing. `maxSurge: 1, maxUnavailable: 0` is the safest.

**Q: How does Kubernetes know a rollout succeeded or failed?**
New pods must become ready. If the rollout makes no progress within `progressDeadlineSeconds` (default 600), its Progressing condition turns False and `kubectl rollout status` exits non-zero. CI pipelines rely on this.

**Q: How do you do blue/green or canary releases?**
Blue/green: two Deployments, switch the Service selector (or Ingress backend) at once. Canary: send a small share of traffic to the new version, with weighted routing in Gateway API or an ingress/service mesh, or tools like Argo Rollouts and Flagger that automate analysis and promotion.

**Q: Why might old ReplicaSets with 0 replicas pile up?**
They are the rollback history (`revisionHistoryLimit`, default 10). That is normal; lower the limit if you want fewer.

**Real-world scenario: the new version is broken and users see errors.**
Mitigate first: `kubectl rollout undo deployment/<name>` (or revert in Git for GitOps). Then find the cause from logs and events. Add a readiness probe and a canary step so the next bad version is caught before it reaches everyone.

**Real-world scenario: every deploy causes a few seconds of errors.**
No readiness probe, or no graceful shutdown. Add readiness, handle SIGTERM, add a short `preStop` sleep, and use `maxUnavailable: 0`.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-deploy-int-q1",
      "type": "mcq",
      "prompt": "A CI pipeline must fail when a new version never becomes healthy. What should it run after applying?",
      "options": [
        {
          "id": "a",
          "text": "kubectl get pods"
        },
        {
          "id": "b",
          "text": "kubectl rollout status deployment/<name> --timeout=5m"
        },
        {
          "id": "c",
          "text": "kubectl describe node"
        },
        {
          "id": "d",
          "text": "kubectl scale --replicas=0"
        }
      ],
      "correct": "b",
      "explanation": "rollout status waits for success and exits non-zero on failure or timeout, which fails the pipeline."
    }
  ]
}
```
