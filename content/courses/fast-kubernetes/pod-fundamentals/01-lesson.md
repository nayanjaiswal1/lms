---
kind: lesson
id_key: k8s/pod-fundamentals/lesson
course: fast-kubernetes
section: pod-fundamentals
section_title: Pods
section_position: 2
title: Pods, the Smallest Unit in Kubernetes
position: 0
estimated_minutes: 50
source:
  - K8s-CreatingPod-Imperative.md
  - K8-CreatingPod-Declerative.md
  - K8s-Multicontainer-Sidecar.md
---

Kubernetes never runs a container on its own. It always wraps containers in a **Pod**. Every other workload you will learn (Deployments, Jobs, StatefulSets) exists to create and manage pods, so this lesson is the foundation for the rest of the course.

## What a pod is

Think of a tiffin carrier with two or three stacked compartments (dabbas). The whole carrier travels together, hangs on one hook, and reaches the same person at the same time, even though each compartment holds different food. A pod is that carrier: it can hold one or more containers, but they always move, start and stop together.

A **pod** is a wrapper around one or more containers that always run together on the same node. Containers in one pod share:

- **One IP address and one set of ports.** They talk to each other over `localhost`. Two containers in the same pod cannot both listen on port 80.
- **Volumes.** A volume declared on the pod can be mounted into any of its containers.
- **A lifecycle.** They are scheduled together, start together, and are removed together.

Most pods run **exactly one** container. You add a second container only when it must live right next to the first (you will see examples below).

Pods are **disposable**. When a pod dies it is not repaired. A controller creates a *new* pod with a new name and usually a new IP address. So never hard-code a pod's IP. Services (a later lesson) give you a stable address.

```knowledge-check
{ "questions": [
  { "id": "k8s-pod-what-q1", "type": "mcq",
    "prompt": "Two containers run in the same pod. How can container A reach a web server listening on port 8080 in container B?",
    "options": [
      {"id": "a", "text": "Through http://localhost:8080"},
      {"id": "b", "text": "Only through a Service"},
      {"id": "c", "text": "They cannot communicate"},
      {"id": "d", "text": "Through the node's public IP"}
    ],
    "correct": "a",
    "explanation": "Containers in a pod share one network namespace, so they see each other on localhost." },
  { "id": "k8s-pod-what-q2", "type": "mcq",
    "prompt": "A pod crashes and a controller replaces it. What is true about the replacement?",
    "options": [
      {"id": "a", "text": "It keeps the same name and IP address"},
      {"id": "b", "text": "It is a new pod, usually with a new name and a new IP address"},
      {"id": "c", "text": "It reuses the old container's memory"},
      {"id": "d", "text": "It must be created manually"}
    ],
    "correct": "b",
    "explanation": "Pods are disposable. A replacement is a brand-new object, which is why clients should use a Service instead of pod IPs." }
] }
```

## Creating a pod the imperative way

The quickest way to start a pod is `kubectl run`:

```bash
kubectl run firstpod --image=nginx:1.27 --port=80 --labels=app=frontend
kubectl get pods
kubectl get pods -o wide        # also shows the pod IP and the node
```

```
NAME       READY   STATUS    RESTARTS   AGE   IP           NODE
firstpod   1/1     Running   0          12s   10.244.0.5   minikube
```

What the columns mean:

- `READY 1/1`: 1 of 1 containers is ready.
- `STATUS`: the pod's current state (see the lifecycle section below).
- `RESTARTS`: how many times the kubelet restarted a container. A number that keeps growing means the app keeps crashing.

This is fine for a quick test, but it leaves no file behind to review or repeat. That is why the declarative way is the normal way.

```knowledge-check
{ "questions": [
  { "id": "k8s-pod-imperative-q1", "type": "mcq",
    "prompt": "`kubectl get pods` shows RESTARTS = 14 for a pod and the number keeps growing. What does that tell you?",
    "options": [
      {"id": "a", "text": "The pod has been moved to 14 different nodes"},
      {"id": "b", "text": "The container keeps crashing and the kubelet keeps restarting it"},
      {"id": "c", "text": "14 copies of the pod are running"},
      {"id": "d", "text": "The image was pulled 14 times successfully"}
    ],
    "correct": "b",
    "explanation": "RESTARTS counts container restarts inside the same pod. A growing number means the process keeps exiting; check `kubectl logs --previous` and `kubectl describe`." }
] }
```

## Creating a pod from a YAML file

Save this as `pod1.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: firstpod
  labels:
    app: frontend            # labels let Services and tools find this pod
spec:
  containers:
  - name: nginx              # container name, unique inside the pod
    image: nginx:1.27        # always pin a version; avoid :latest
    ports:
    - containerPort: 80      # documents the port the app listens on
    env:                     # environment variables for the container
    - name: USER
      value: "username"
```

Apply it and check it:

```bash
kubectl apply -f pod1.yaml
kubectl get pod firstpod
kubectl describe pod firstpod
kubectl delete -f pod1.yaml
```

Two good habits:

- **Pin image versions** (`nginx:1.27`, not `nginx` or `nginx:latest`). `latest` can change under you, so two nodes may end up running different code.
- `containerPort` is informational. The app listens on whatever port it listens on. Still, write it down, because it documents the pod and named ports can be referenced by Services.

You cannot change most fields of a running pod (for example, its image list or ports). To change them you delete and recreate the pod. This is one more reason you will soon use Deployments, which handle replacement for you.

```knowledge-check
{ "questions": [
  { "id": "k8s-pod-yaml-q1", "type": "mcq",
    "prompt": "Why is `image: nginx:latest` a bad idea in a real manifest?",
    "options": [
      {"id": "a", "text": "Kubernetes rejects the latest tag"},
      {"id": "b", "text": "latest can point to a different image over time, so pods created at different times may run different versions"},
      {"id": "c", "text": "latest images cannot expose ports"},
      {"id": "d", "text": "latest is always an older version"}
    ],
    "correct": "b",
    "explanation": "A tag like latest moves. Pinning a version (or even an image digest) makes every pod run the exact same code and makes rollbacks meaningful." }
] }
```

## Inspecting and debugging a pod

These commands answer almost every "why is my pod broken?" question:

```bash
kubectl describe pod firstpod          # config + Events (scheduling, image pull, probe failures)
kubectl logs firstpod                  # what the container printed to stdout/stderr
kubectl logs -f firstpod               # follow logs live (Ctrl+C to stop)
kubectl logs firstpod --previous       # logs of the last crashed container
kubectl logs firstpod -c nginx         # pick a container in a multi-container pod
kubectl exec firstpod -- ls /usr/share/nginx/html   # run one command inside
kubectl exec -it firstpod -- sh        # open a shell inside (type exit to leave)
kubectl get pod firstpod -o yaml       # the full object, including status
kubectl get events --sort-by=.lastTimestamp
```

A simple debugging order that works:

1. `kubectl get pods`: what is the STATUS?
2. `kubectl describe pod <name>`: read the **Events** at the bottom.
3. `kubectl logs <name>` (add `--previous` if it restarted): what did the app say before it died?

In `kubectl exec`, the `--` separates kubectl's own flags from the command to run inside the container. Many small images have `sh` but not `bash`.

```knowledge-check
{ "questions": [
  { "id": "k8s-pod-debug-q1", "type": "mcq",
    "prompt": "A container crashed and was restarted. `kubectl logs mypod` shows only the new container's startup lines. How do you see why the old one died?",
    "options": [
      {"id": "a", "text": "kubectl logs mypod --previous"},
      {"id": "b", "text": "kubectl describe node"},
      {"id": "c", "text": "kubectl logs mypod -f"},
      {"id": "d", "text": "It is impossible once a container restarts"}
    ],
    "correct": "a",
    "explanation": "--previous shows the logs of the previous (crashed) instance of the container, which usually contains the error." }
] }
```

## Pod lifecycle and common statuses

A pod moves through **phases**:

| Phase | Meaning |
|---|---|
| `Pending` | Accepted, but not running yet: waiting for a node, or pulling the image. |
| `Running` | Bound to a node and at least one container is running. |
| `Succeeded` | All containers exited with code 0 and will not restart (typical for Jobs). |
| `Failed` | All containers stopped and at least one failed. |
| `Unknown` | The node stopped reporting. |

`kubectl get pods` often shows a more specific reason in the STATUS column. The ones you will meet most:

- **`ImagePullBackOff` / `ErrImagePull`**: wrong image name or tag, or a private registry without credentials.
- **`CrashLoopBackOff`**: the container starts, crashes, and Kubernetes waits longer and longer before each restart. Check `kubectl logs --previous`.
- **`Pending` for a long time**: no node fits (not enough CPU/memory, or scheduling rules that no node matches). `kubectl describe` says why.
- **`OOMKilled`**: the container used more memory than its limit.
- **`Completed`**: the container finished successfully.

The `restartPolicy` field decides what the kubelet does when a container exits:

- `Always` (default): restart it every time. Right for servers.
- `OnFailure`: restart only if it exited with an error. Used for Jobs.
- `Never`: never restart.

```knowledge-check
{ "questions": [
  { "id": "k8s-pod-lifecycle-q1", "type": "mcq",
    "prompt": "A pod shows ImagePullBackOff. What is the most likely cause?",
    "options": [
      {"id": "a", "text": "The app crashes on startup"},
      {"id": "b", "text": "The image name or tag is wrong, or the registry needs credentials"},
      {"id": "c", "text": "The node ran out of disk space for logs"},
      {"id": "d", "text": "The pod has too many labels"}
    ],
    "correct": "b",
    "explanation": "ImagePullBackOff means the kubelet could not download the image. Check the image name/tag, and use imagePullSecrets for private registries." },
  { "id": "k8s-pod-lifecycle-q2", "type": "mcq",
    "prompt": "Which restartPolicy is the default for a pod?",
    "options": [
      {"id": "a", "text": "Never"},
      {"id": "b", "text": "OnFailure"},
      {"id": "c", "text": "Always"},
      {"id": "d", "text": "OnSuccess"}
    ],
    "correct": "c",
    "explanation": "Always is the default and is what long-running servers need. Jobs use OnFailure or Never." }
] }
```

## Multi-container pods: sidecars and shared volumes

Sometimes a helper process must run right next to the main app. Putting both in one pod is called the **sidecar pattern**. Examples: a log shipper that reads the app's log files, a proxy in front of the app, or a process that refreshes files the app serves.

In this example, `webcontainer` (nginx) serves files, and `sidecarcontainer` rewrites `index.html` every 15 seconds. They share an `emptyDir` volume:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multicontainer
spec:
  containers:
  - name: webcontainer
    image: nginx:1.27
    ports:
    - containerPort: 80
    volumeMounts:
    - name: sharedvolume
      mountPath: /usr/share/nginx/html     # nginx serves files from here
  - name: sidecarcontainer
    image: busybox:1.36
    command: ["/bin/sh", "-c"]
    args: ["while true; do echo \"<h1>Updated at $(date)</h1>\" > /var/log/index.html; sleep 15; done"]
    volumeMounts:
    - name: sharedvolume
      mountPath: /var/log                  # same volume, different path
  volumes:
  - name: sharedvolume
    emptyDir: {}                           # empty folder created with the pod
```

Key points:

- The two containers mount the **same volume** at **different paths**. A file written by one is instantly visible to the other.
- An **`emptyDir`** volume is created empty when the pod starts on a node and is **deleted when the pod is deleted**. It survives container restarts, but not pod deletion. Use it for scratch space and sharing, never for data you must keep.
- Both containers share the pod's IP. You could check this by running `ip addr` (or `hostname -i`) inside each one: the address is the same.

Use `-c` to pick a container:

```bash
kubectl apply -f multicontainer.yaml
kubectl exec -it multicontainer -c webcontainer -- sh
kubectl logs multicontainer -c sidecarcontainer
```

Kubernetes 1.29+ also supports **native sidecar containers**: an init container with `restartPolicy: Always`. It starts before the app and keeps running beside it. You will see this in newer charts.

```knowledge-check
{ "questions": [
  { "id": "k8s-pod-sidecar-q1", "type": "mcq",
    "prompt": "A pod uses an emptyDir volume. What happens to the files in it when the pod is deleted?",
    "options": [
      {"id": "a", "text": "They are kept on the node forever"},
      {"id": "b", "text": "They are moved to a PersistentVolume"},
      {"id": "c", "text": "They are deleted together with the pod"},
      {"id": "d", "text": "They are copied into the image"}
    ],
    "correct": "c",
    "explanation": "emptyDir lives exactly as long as the pod. It survives container restarts, but deleting the pod removes it. For lasting data, use a PersistentVolumeClaim." },
  { "id": "k8s-pod-sidecar-q2", "type": "mcq",
    "prompt": "In a two-container pod, how do you open a shell in the second container, named helper?",
    "options": [
      {"id": "a", "text": "kubectl exec -it mypod --container-index=2 -- sh"},
      {"id": "b", "text": "kubectl exec -it mypod -c helper -- sh"},
      {"id": "c", "text": "kubectl exec -it helper -- sh"},
      {"id": "d", "text": "kubectl logs -it mypod helper"}
    ],
    "correct": "b",
    "explanation": "-c (or --container) picks a container by name. Without it kubectl uses the default (first) container." }
] }
```

## Init containers

Like a society watchman who checks every visitor's ID before opening the gate, and only then lets them walk in: nobody reaches the flat before the watchman is done. An **init container** runs *before* the app containers start, and must finish successfully. If there are several, they run one after another. Typical uses: wait for a database to be reachable, download config, or run a migration.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: initpod
spec:
  initContainers:
  - name: wait-for-db
    image: busybox:1.36
    command: ["sh", "-c", "until nslookup db-service; do echo waiting for db; sleep 2; done"]
  containers:
  - name: app
    image: nginx:1.27
```

While an init container is running, the pod status shows `Init:0/1`. If it keeps failing, the pod shows `Init:CrashLoopBackOff` and the app containers never start.

```knowledge-check
{ "questions": [
  { "id": "k8s-pod-init-q1", "type": "mcq",
    "prompt": "A pod has one init container that never exits because the database it waits for does not exist. What happens to the app container?",
    "options": [
      {"id": "a", "text": "It starts anyway after 30 seconds"},
      {"id": "b", "text": "It never starts; the pod stays in the Init state"},
      {"id": "c", "text": "It starts in parallel with the init container"},
      {"id": "d", "text": "Kubernetes deletes the init container and continues"}
    ],
    "correct": "b",
    "explanation": "App containers only start after every init container has completed successfully." }
] }
```

## Reaching a pod from your laptop: port-forward

`kubectl port-forward` opens a tunnel from a port on your machine to a port on a pod. It is meant for testing and debugging, not for real users:

```bash
kubectl port-forward pod/multicontainer 8080:80    # localPort:podPort
# now open http://127.0.0.1:8080 in a browser; Ctrl+C stops the tunnel
```

The tunnel goes through the API server, so it works even when the pod has no public address. For real traffic you will use Services and Ingress.

```knowledge-check
{ "questions": [
  { "id": "k8s-pod-portfwd-q1", "type": "mcq",
    "prompt": "In `kubectl port-forward pod/web 8080:80`, what do the two numbers mean?",
    "options": [
      {"id": "a", "text": "8080 is the pod port and 80 is your local port"},
      {"id": "b", "text": "8080 is the port on your machine and 80 is the port inside the pod"},
      {"id": "c", "text": "Both are ports on the node"},
      {"id": "d", "text": "8080 is the Service port and 80 is the NodePort"}
    ],
    "correct": "b",
    "explanation": "The format is LOCAL:REMOTE. Your machine listens on 8080 and forwards to port 80 of the pod." }
] }
```

## Why you rarely create bare pods

A pod created on its own (a "bare" pod) is **not** recreated if its node dies, and you cannot do rolling updates with it. In real work you almost always create a **Deployment** (or another controller), which creates and replaces pods for you. That is the next section.

Cleanup commands you will use often:

```bash
kubectl delete pod firstpod
kubectl delete -f multicontainer.yaml
kubectl delete pod firstpod --grace-period=0 --force   # last resort for stuck pods
```

```knowledge-check
{ "questions": [
  { "id": "k8s-pod-bare-q1", "type": "mcq",
    "prompt": "You created a pod directly with kubectl apply. Its node loses power. What happens to the pod?",
    "options": [
      {"id": "a", "text": "It is automatically recreated on another node"},
      {"id": "b", "text": "Nothing recreates it, because no controller owns it"},
      {"id": "c", "text": "It is paused until the node comes back and then migrated live"},
      {"id": "d", "text": "The scheduler clones it to every node"}
    ],
    "correct": "b",
    "explanation": "Only controllers (Deployment, ReplicaSet, StatefulSet, ...) recreate pods. A bare pod is gone for good if its node dies." }
] }
```

## Interview questions and real-world scenarios

**Q: Why is the pod, not the container, the smallest unit?**
Some containers must share network and storage and be scheduled together (app + sidecar). The pod is that shared context: one IP, shared volumes, one lifecycle.

**Q: How do containers in a pod communicate?**
Over `localhost` (shared network namespace) and through shared volumes. They do not share a filesystem unless a volume is mounted into both.

**Q: What is an init container, and how is it different from a sidecar?**
Init containers run to completion, in order, before the app starts. Sidecars run alongside the app for its whole life. Native sidecars are init containers with `restartPolicy: Always`.

**Q: A pod is in CrashLoopBackOff. How do you debug it?**
`kubectl describe pod` (events, last state, exit code), then `kubectl logs --previous`. Common causes: missing config or secret, wrong command, app error, failing liveness probe, dependency unreachable.

**Q: What does the pod `status.phase` tell you, and what does it not?**
The high-level phase (Pending/Running/Succeeded/Failed/Unknown). Running does not mean healthy: check READY and restarts.

**Real-world scenario: a pod shows Running but READY 0/1.**
The container is up but the readiness probe fails, so the Service sends it no traffic. Check the probe path and port in `describe`, and the app logs, for a dependency it is waiting on.

**Real-world scenario: someone "fixed" production with `kubectl exec` and edited files in a container.**
The change is lost at the next restart, and nobody can review it. Fix it in the image or the manifest instead, and treat containers as disposable.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-pod-int-q1",
      "type": "mcq",
      "prompt": "A pod shows STATUS Running but READY 0/1. What is the most likely reason?",
      "options": [
        {
          "id": "a",
          "text": "The image could not be pulled"
        },
        {
          "id": "b",
          "text": "The readiness probe is failing, so the pod receives no Service traffic"
        },
        {
          "id": "c",
          "text": "The node is out of disk"
        },
        {
          "id": "d",
          "text": "The pod has finished its work"
        }
      ],
      "correct": "b",
      "explanation": "Running means the container process exists; READY 0/1 means it has not passed readiness."
    }
  ]
}
```
