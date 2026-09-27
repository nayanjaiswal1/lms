---
kind: lesson
id_key: k8s/basics/lesson
course: fast-kubernetes
section: basics
section_title: Kubernetes Basics
section_position: 1
title: What Kubernetes Is and How It Works
position: 0
estimated_minutes: 45
source:
  - README.md
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
  tasks:
    - id_key: generate-yaml
      title: Generate YAML instead of typing it
      points: 10
      is_stateful: false
      description: Without creating anything, generate the YAML for a pod called `web` (image `nginx`) and save it to `~/work/web.yaml`.
      verification_script: |
        #!/bin/bash
        f=/home/labuser/work/web.yaml
        test -f "$f" && grep -q 'kind: Pod' "$f" && grep -q 'name: web' "$f" && ! kubectl get pod web >/dev/null 2>&1
      hint_context: Add `--dry-run=client -o yaml` to a `kubectl run` command and redirect the output with `>`.
      explanation_context: "`--dry-run=client` builds the object locally without sending it to the cluster, and `-o yaml` prints it. This is the fastest way to start a new manifest."
      solution_script: kubectl run web --image=nginx --dry-run=client -o yaml > /home/labuser/work/web.yaml
    - id_key: create-namespace
      title: Create a namespace
      points: 10
      is_stateful: true
      description: Create a namespace called `dev`.
      verification_script: |
        #!/bin/bash
        kubectl get namespace dev -o jsonpath='{.status.phase}' | grep -qx Active
      hint_context: "`kubectl create namespace <name>` creates a namespace."
      explanation_context: A namespace is a named folder inside the cluster. Objects in `dev` do not clash with objects of the same name in `default`.
      solution_script: kubectl create namespace dev
    - id_key: run-pod-in-namespace
      title: Run a pod in that namespace
      points: 10
      is_stateful: true
      description: Run a pod called `hello` from the `nginx` image in the `dev` namespace, with the label `app=hello`.
      verification_script: |
        #!/bin/bash
        kubectl get pod hello -n dev -o jsonpath='{.spec.containers[0].image} {.metadata.labels.app}' | grep -qx 'nginx hello'
      hint_context: "`kubectl run` takes `--image`, `--labels` and `-n <namespace>`."
      explanation_context: "`kubectl run hello --image=nginx --labels=app=hello -n dev` asks the API server to store a Pod object. The scheduler then picks a node for it and the node starts it."
      solution_script: kubectl run hello --image=nginx --labels=app=hello -n dev
    - id_key: label-node
      title: Label a node
      points: 10
      is_stateful: false
      description: Add the label `env=lab` to the node `kwok-node`, then list nodes with `kubectl get nodes --show-labels` to see it.
      verification_script: |
        #!/bin/bash
        kubectl get node kwok-node -o jsonpath='{.metadata.labels.env}' | grep -qx lab
      hint_context: "`kubectl label <kind> <name> key=value` adds a label to any object."
      explanation_context: Labels work the same on every kind of object. Later lessons use node labels to control where pods run.
      solution_script: kubectl label node kwok-node env=lab
---

Kubernetes (often written **K8s**, because there are 8 letters between the K and the s) is a system that runs containers for you across many machines. You tell it *what* you want running, and it keeps making that true.

This lesson covers the ideas every later lesson depends on. Read it once carefully, and the rest of the course becomes much easier. You do not need any prior Kubernetes knowledge to start. Basic comfort with a terminal, running a command and reading its output, is enough.

## First, what is a container?

Think about packing a tiffin box before a train journey. You pack everything you will need (rice, sabzi, a spoon, maybe pickle) into one box, so you are not depending on the train pantry to have what you like. Wherever the train goes, your tiffin works the same way.

A **container** packages an app the same way: your code, plus every library and setting it needs, sealed into one box. Move that box to a different laptop, a different server, or a different cloud provider, and it behaves exactly the same. This is why "works on my machine" stops being a problem: the machine's contents travel with the app.

A few words you will see everywhere from here on:

- **Image**: the packed box itself, a read-only file holding the app and everything it needs. You build an image once.
- **Tag**: a label on an image, usually a version, for example `nginx:1.27`. Leave the tag off and Kubernetes uses `latest`, which is risky because `latest` can quietly change to a different version.
- **Container**: a running copy of an image. You can start many containers from one image, the way you can pack many identical tiffins from one recipe.
- **Registry**: a shared shelf where images are stored and downloaded from, for example Docker Hub or a private company registry.
- **Docker**: the most common tool for building images and running containers. It is not the only one, but it is the one that made the idea popular.

**Container vs virtual machine.** A virtual machine (VM) is like renting a whole separate house: it carries a full copy of an operating system inside it, so it takes minutes to start and uses a lot of memory and disk. A container is like renting one room in a house that already exists: it shares the host machine's operating system kernel, so it is light and starts in a second or two. That is why a laptop that can barely run three or four VMs can run dozens of containers.

If you have Docker installed, try this:

```bash
docker run -d -p 8080:80 nginx:1.27   # start a container from the nginx image; your port 8080 -> its port 80
docker ps                             # list running containers
```

Docker is great at running containers on **one** machine. The moment you need many containers spread across many machines, restarted automatically when they crash, and updated without downtime, you need something above Docker to manage all of that. That is Kubernetes: it manages containers across many machines instead of just one.

```knowledge-check
{ "questions": [
  { "id": "k8s-basics-container-q1", "type": "mcq",
    "prompt": "What is a container image?",
    "options": [
      {"id": "a", "text": "A running process on a server"},
      {"id": "b", "text": "A read-only package containing an app and everything it needs to run"},
      {"id": "c", "text": "A virtual machine with its own operating system"},
      {"id": "d", "text": "A Kubernetes cluster"}
    ],
    "correct": "b",
    "explanation": "An image is the packaged, read-only template. A container is a running copy of that image." },
  { "id": "k8s-basics-container-q2", "type": "mcq",
    "prompt": "Why does a container start in a second or two while a virtual machine can take minutes?",
    "options": [
      {"id": "a", "text": "Containers do not run any code at startup"},
      {"id": "b", "text": "A container shares the host's operating system kernel instead of booting its own full OS like a VM does"},
      {"id": "c", "text": "Virtual machines always run on slower hardware"},
      {"id": "d", "text": "Containers skip loading the application code"}
    ],
    "correct": "b",
    "explanation": "A VM boots a complete guest operating system. A container reuses the host kernel and only starts the app process, which is much faster and lighter." }
] }
```

## Why Kubernetes exists

A container packages an app with everything it needs (code, runtime, libraries). Docker can run a container on one machine. That is enough for a laptop, but a real product needs more:

- **Many copies.** One copy of your app is not enough for real traffic, and if it crashes your site is down.
- **Many machines.** Copies should spread over several servers so one broken server does not take everything down.
- **Self-healing.** When a container crashes or a server dies, something must start a replacement automatically.
- **Updates without downtime.** You want to ship version 2 while version 1 keeps serving users.
- **Networking.** Copies come and go and their IP addresses change. Users need one stable address.
- **Configuration and secrets.** Settings and passwords should live outside the image.

Doing all of this by hand with scripts is slow and fragile. Kubernetes is the standard tool that does it for you. The general name for this job is **container orchestration**.

```knowledge-check
{ "questions": [
  { "id": "k8s-basics-why-q1", "type": "mcq",
    "prompt": "Your app runs fine in one Docker container on one server. What problem does Kubernetes solve that plain Docker on one machine does not?",
    "options": [
      {"id": "a", "text": "It makes the container image smaller"},
      {"id": "b", "text": "It runs many copies across many machines and replaces them automatically when they fail"},
      {"id": "c", "text": "It lets you write the app in any programming language"},
      {"id": "d", "text": "It removes the need for container images"}
    ],
    "correct": "b",
    "explanation": "Kubernetes is an orchestrator: it schedules containers across a group of machines, keeps the requested number of copies running, and replaces failed ones. Image size and programming language have nothing to do with it." }
] }
```

## The cluster: control plane and worker nodes

A Kubernetes **cluster** is a group of machines (physical or virtual) that work together. They have two roles.

Think of a school. The **principal's office** decides what should happen (which class runs where, who teaches what) but does not teach itself. The **classrooms** are where the actual work happens. The control plane is the principal's office; worker nodes are the classrooms.

**The control plane** is the brain. It stores what you asked for and decides what should happen. It has four main parts:

| Component | What it does |
|---|---|
| `kube-apiserver` | The front door. Every command (from you, from tools, from other components) goes through its REST API. |
| `etcd` | A key-value database that stores the whole state of the cluster. If etcd is lost, the cluster forgets everything. |
| `kube-scheduler` | Picks a node for every new pod, based on free CPU/memory and your rules. |
| `kube-controller-manager` | Runs *controllers*: small loops that watch the cluster and fix differences (for example, "3 copies wanted, 2 running, start 1 more"). |

**Worker nodes** are the machines that actually run your containers. Each node runs:

| Component | What it does |
|---|---|
| `kubelet` | The node agent. It receives pods from the API server and makes sure their containers are running and healthy. |
| Container runtime | The software that really starts containers, usually `containerd` (older clusters used Docker). |
| `kube-proxy` | Sets up network rules so traffic sent to a Service reaches the right pods. |

You almost never talk to nodes directly. You talk to the API server, and the rest follows.

```knowledge-check
{ "questions": [
  { "id": "k8s-basics-arch-q1", "type": "mcq",
    "prompt": "Which component decides which node a new pod will run on?",
    "options": [
      {"id": "a", "text": "kubelet"},
      {"id": "b", "text": "etcd"},
      {"id": "c", "text": "kube-scheduler"},
      {"id": "d", "text": "kube-proxy"}
    ],
    "correct": "c",
    "explanation": "The scheduler assigns each pending pod to a node. The kubelet on that node then starts it. etcd only stores data and kube-proxy handles Service networking." },
  { "id": "k8s-basics-arch-q2", "type": "mcq",
    "prompt": "Where is the state of the whole cluster (every object you created) stored?",
    "options": [
      {"id": "a", "text": "In etcd"},
      {"id": "b", "text": "In the kubelet on each node"},
      {"id": "c", "text": "In your local kubeconfig file"},
      {"id": "d", "text": "Inside each container image"}
    ],
    "correct": "a",
    "explanation": "etcd is the cluster's database. The API server is the only component that reads and writes it directly. Your kubeconfig only holds connection details." }
] }
```

## Desired state and the reconcile loop

This is the most important idea in Kubernetes.

It works like a hostel warden who keeps a fixed head count. The warden does not personally carry each student back to their room; the warden just keeps counting heads and, whenever the count is short, sends someone to bring the missing student back. Kubernetes controllers do the same thing to your pods, over and over, forever.

You do not say "start a container now". You say "**I want** 3 copies of this app running". That statement is the **desired state**. Kubernetes stores it and compares it with the **actual state** again and again. Whenever they differ, a controller acts to close the gap:

1. You declare: "3 copies of `web`".
2. A controller sees 0 copies exist and creates 3.
3. A node crashes and 1 copy disappears. Actual = 2.
4. The controller notices the difference and creates 1 more. Actual = 3 again.

This never-ending "watch, compare, fix" cycle is called the **reconcile loop**. It is why Kubernetes heals itself: nobody has to be awake at 3 a.m. to restart a crashed container.

```knowledge-check
{ "questions": [
  { "id": "k8s-basics-desired-q1", "type": "mcq",
    "prompt": "You asked for 4 copies of an app. One node dies and takes 2 copies with it. What does Kubernetes do?",
    "options": [
      {"id": "a", "text": "Nothing, until you run the deploy command again"},
      {"id": "b", "text": "Sends you an email and waits for approval"},
      {"id": "c", "text": "Notices only 2 of the desired 4 exist and starts 2 new copies on healthy nodes"},
      {"id": "d", "text": "Deletes the remaining 2 copies to stay consistent"}
    ],
    "correct": "c",
    "explanation": "The desired state (4) is still stored. A controller sees the actual state (2), and creates replacements until actual matches desired." }
] }
```

## YAML in 5 minutes

Kubernetes manifests are written in **YAML**, a plain-text format for describing data with almost no punctuation. If you can read a form with labels and values filled in, you can read YAML. A handful of rules cover almost all of it:

- **`key: value`** is the basic building block: a name, a colon, a space, then the value. For example `name: web`.
- **Nesting** is shown with spaces, never tabs. A value indented under a key belongs to that key. Wrong indentation (or a stray tab) is the single most common YAML mistake.
- **Lists** use a leading dash `-` for each item.
- **Strings, numbers and booleans** look like `name: web` (string), `replicas: 3` (number), `enabled: true` (boolean). Quote a value when it could be misread as something else, for example a version number: `tag: "1.27"`.
- **Multi-line text** uses a pipe `|`, which keeps every line break exactly as written. You will see this for scripts embedded inside a manifest.
- **Multiple documents in one file** are separated by a line that contains only `---`.
- **Comments** start with `#` and are ignored by the parser.

A small example that uses all of these at once:

```yaml
# a short example
name: web
replicas: 3
enabled: true
tags:
  - frontend
  - v1
image:
  repository: nginx
  tag: "1.27"
script: |
  echo "first line"
  echo "second line"
```

Once this feels comfortable, the manifests in the next section will look familiar instead of intimidating.

```knowledge-check
{ "questions": [
  { "id": "k8s-basics-yamlbasics-q1", "type": "mcq",
    "prompt": "In YAML, how is nesting (a value belonging to a key) shown?",
    "options": [
      {"id": "a", "text": "With curly braces"},
      {"id": "b", "text": "With indentation using spaces, never tabs"},
      {"id": "c", "text": "With a semicolon at the end of the line"},
      {"id": "d", "text": "Nesting is not possible in YAML"}
    ],
    "correct": "b",
    "explanation": "YAML uses consistent space indentation to show that a value belongs under a key. Tabs are not allowed and cause parse errors." }
] }
```

## Objects and YAML manifests

Everything you create in Kubernetes is an **object**: a Pod, a Deployment, a Service, a Secret, and so on. You usually describe an object in a YAML file called a **manifest**. Almost every manifest has the same four top-level fields:

```yaml
apiVersion: v1          # which API group/version defines this kind
kind: Pod               # what type of object this is
metadata:               # identity: name, namespace, labels
  name: web
  labels:
    app: web
spec:                   # the desired state: what you want
  containers:
  - name: nginx
    image: nginx:1.27
```

- `apiVersion` and `kind` tell Kubernetes what you are creating. Core objects like Pod and Service use `v1`. Deployments use `apps/v1`. Jobs use `batch/v1`.
- `metadata` holds the name (unique per kind within a namespace), the namespace and labels.
- `spec` is **your** part: the desired state.
- `status` is **Kubernetes'** part. You never write it. The cluster fills it in to report the actual state. You see it with `kubectl get <kind> <name> -o yaml`.

YAML uses indentation (spaces, never tabs) to show nesting. A leading `-` starts a list item. Most beginner errors are wrong indentation.

To see every field a kind supports, ask the cluster itself:

```bash
kubectl explain pod.spec.containers
kubectl explain deployment.spec --recursive | less
```

```knowledge-check
{ "questions": [
  { "id": "k8s-basics-yaml-q1", "type": "mcq",
    "prompt": "In a manifest, which field do you fill in to describe what you want, and which field does Kubernetes fill in to report what is actually happening?",
    "options": [
      {"id": "a", "text": "You write metadata; Kubernetes writes spec"},
      {"id": "b", "text": "You write spec; Kubernetes writes status"},
      {"id": "c", "text": "You write status; Kubernetes writes spec"},
      {"id": "d", "text": "You write kind; Kubernetes writes apiVersion"}
    ],
    "correct": "b",
    "explanation": "spec is the desired state you declare. status is written by the cluster and shows the actual state. Comparing them is exactly what controllers do." }
] }
```

## kubectl: talking to the cluster

`kubectl` is the command-line client for the API server. The shape of most commands is:

```bash
kubectl <verb> <kind> [name] [flags]
```

The verbs you will use every day:

```bash
kubectl get pods                    # list objects (short summary)
kubectl get pods -o wide            # extra columns: IP, node
kubectl get pod web -o yaml         # full object, including status
kubectl describe pod web            # human-readable details + recent events
kubectl apply -f web.yaml           # create or update from a file
kubectl delete -f web.yaml          # delete what the file describes
kubectl delete pod web              # delete by name
kubectl get all                     # common kinds in the current namespace
kubectl api-resources               # every kind the cluster knows, with short names
```

Many kinds have short names: `po` (pods), `deploy` (deployments), `svc` (services), `ns` (namespaces), `cm` (configmaps), `pvc`, `pv`, `no` (nodes).

**Which cluster am I talking to?** kubectl reads a **kubeconfig** file (by default `~/.kube/config`). It lists clusters, users and *contexts* (a cluster + user + default namespace):

```bash
kubectl config get-contexts          # list contexts; * marks the current one
kubectl config use-context prod      # switch cluster
kubectl config set-context --current --namespace=dev   # change default namespace
```

Always check your context before deleting anything. Running a delete against the wrong cluster is a classic, painful mistake.

```knowledge-check
{ "questions": [
  { "id": "k8s-basics-kubectl-q1", "type": "mcq",
    "prompt": "A pod will not start and you want to see its recent events (for example, image pull errors). Which command shows them?",
    "options": [
      {"id": "a", "text": "kubectl get pods"},
      {"id": "b", "text": "kubectl describe pod <name>"},
      {"id": "c", "text": "kubectl api-resources"},
      {"id": "d", "text": "kubectl config get-contexts"}
    ],
    "correct": "b",
    "explanation": "kubectl describe prints the object's details plus an Events section at the bottom, which is where scheduling and image-pull problems show up." },
  { "id": "k8s-basics-kubectl-q2", "type": "mcq",
    "prompt": "What decides which cluster your kubectl commands go to?",
    "options": [
      {"id": "a", "text": "The current context in your kubeconfig file"},
      {"id": "b", "text": "The first node in the cluster"},
      {"id": "c", "text": "The namespace in the YAML file"},
      {"id": "d", "text": "The kubelet on your laptop"}
    ],
    "correct": "a",
    "explanation": "kubeconfig holds clusters, users and contexts. The current context picks the cluster, the credentials and the default namespace." }
] }
```

## Imperative vs declarative

There are two ways to make changes.

**Imperative**: you give a direct command.

```bash
kubectl run web --image=nginx
kubectl scale deployment web --replicas=5
```

Fast for experiments, but nothing records what you did. Another person cannot repeat it exactly.

**Declarative**: you write the desired state in a file and apply it.

```bash
kubectl apply -f web.yaml
```

The file can live in Git, be reviewed, and be applied again at any time with the same result. `apply` creates the object if it does not exist and updates it if it does. **Real projects use declarative files.**

A useful trick combines both: let an imperative command *write* the YAML for you, then edit and apply it.

```bash
kubectl run web --image=nginx --dry-run=client -o yaml > web.yaml
kubectl create deployment web --image=nginx --replicas=3 --dry-run=client -o yaml > deploy.yaml
```

`--dry-run=client` means "build it, but do not send it".

```knowledge-check
{ "questions": [
  { "id": "k8s-basics-declarative-q1", "type": "mcq",
    "prompt": "Why do teams prefer `kubectl apply -f file.yaml` over typing `kubectl run`/`kubectl scale` commands?",
    "options": [
      {"id": "a", "text": "apply is the only command that works in production"},
      {"id": "b", "text": "The file records the desired state, can be kept in Git and reviewed, and applying it again gives the same result"},
      {"id": "c", "text": "Imperative commands are slower to execute"},
      {"id": "d", "text": "apply skips the API server"}
    ],
    "correct": "b",
    "explanation": "Declarative files are repeatable and reviewable. Imperative commands work, but leave no record of the intended state." }
] }
```

[[lab-task:1]]

## Namespaces

A **namespace** divides one cluster into separate areas, like folders. Names must be unique inside a namespace, but two namespaces can each have a pod called `web`. Teams often use one namespace per team or per environment (`dev`, `staging`).

```bash
kubectl get namespaces
kubectl create namespace dev
kubectl get pods -n dev              # -n picks a namespace
kubectl get pods -A                  # all namespaces
```

Every cluster starts with a few namespaces:

- `default` is used when you do not specify one.
- `kube-system` holds Kubernetes' own components. Do not deploy your apps there.
- `kube-public` and `kube-node-lease` are used internally.

Namespaces separate *names*, and you can attach access rules and resource quotas to them. They do **not** isolate network traffic by default: a pod in `dev` can still reach a pod in `staging` unless you add NetworkPolicies. Nodes and PersistentVolumes are *cluster-wide* objects and do not belong to any namespace.

```knowledge-check
{ "questions": [
  { "id": "k8s-basics-ns-q1", "type": "mcq",
    "prompt": "Which statement about namespaces is true?",
    "options": [
      {"id": "a", "text": "Pods in different namespaces can never talk to each other"},
      {"id": "b", "text": "Each namespace runs on its own set of nodes"},
      {"id": "c", "text": "Two namespaces can each contain a pod with the same name"},
      {"id": "d", "text": "Nodes belong to exactly one namespace"}
    ],
    "correct": "c",
    "explanation": "Namespaces scope names. They do not block network traffic by default and do not own nodes; nodes are cluster-wide." }
] }
```

[[lab-task:2]]

[[lab-task:3]]

## Labels and selectors

A **label** is a `key: value` tag on any object, for example `app: web` or `env: prod`. Labels mean nothing to Kubernetes by themselves. Their power comes from **selectors**, which pick objects by label:

```bash
kubectl get pods -l app=web                 # pods where app = web
kubectl get pods -l 'env in (dev,staging)'  # set-based selector
kubectl get pods --show-labels
kubectl label pod web tier=frontend         # add a label
kubectl label pod web tier-                 # remove it (note the trailing -)
```

This is how Kubernetes objects find each other. It is not a side feature:

- A **Deployment** finds the pods it owns by label.
- A **Service** sends traffic to every pod whose labels match its selector.
- **Scheduling rules** pick nodes by node labels.

If a label and a selector do not match exactly, things silently do not connect. When something "isn't finding its pods", check labels first.

**Annotations** look similar (`key: value` in `metadata.annotations`) but are *not* used for selection. They hold extra information for tools and people, such as a build number or a description.

```knowledge-check
{ "questions": [
  { "id": "k8s-basics-labels-q1", "type": "mcq",
    "prompt": "A Service has `selector: app: shop`, but your pods are labeled `app: store`. What happens?",
    "options": [
      {"id": "a", "text": "Kubernetes rejects the Service"},
      {"id": "b", "text": "The Service matches the pods anyway because they are in the same namespace"},
      {"id": "c", "text": "The Service has no pods behind it, so traffic sent to it goes nowhere"},
      {"id": "d", "text": "The pods are relabeled automatically"}
    ],
    "correct": "c",
    "explanation": "Selectors match labels exactly. With no matching pods the Service is valid but empty. This mismatch is one of the most common real-world bugs." }
] }
```

[[lab-task:4]]

## Where to run Kubernetes

For learning you need a small cluster:

- **minikube** runs a single-node cluster in a VM or container on your laptop. It has handy add-ons (`minikube addons enable ingress`).
- **kind** (Kubernetes in Docker) runs nodes as Docker containers. It is fast and popular in CI.
- **k3s** is a lightweight, production-capable distribution, good for small servers.
- **Managed cloud clusters** (Amazon EKS, Google GKE, Azure AKS): the cloud runs the control plane for you.
- **kubeadm** builds a real cluster on your own machines. The last part of this course walks through it.

```bash
minikube start
kubectl get nodes
```

**About this course's labs:** the lab terminal gives you a real Kubernetes control plane (API server, etcd, scheduler and controllers). The nodes, however, are *simulated*. Pods get scheduled, become `Running`, get IP addresses, and Jobs complete, but no real container process runs inside them. So everything about objects, scheduling, scaling, rollouts and Services works exactly as in a real cluster, while commands that need a real process (`kubectl logs`, `kubectl exec`, `kubectl port-forward`) are not available there. Try those on minikube or kind.

```knowledge-check
{ "questions": [
  { "id": "k8s-basics-where-q1", "type": "mcq",
    "prompt": "In a managed service like EKS, GKE or AKS, who runs the control plane?",
    "options": [
      {"id": "a", "text": "You must install etcd and the API server yourself"},
      {"id": "b", "text": "The cloud provider runs and maintains it; you manage workloads and usually the worker nodes"},
      {"id": "c", "text": "There is no control plane in managed clusters"},
      {"id": "d", "text": "Each worker node runs its own separate control plane"}
    ],
    "correct": "b",
    "explanation": "Managed Kubernetes means the provider operates the control plane (API server, etcd, scheduler, controllers). You deploy your apps and choose node sizes." }
] }
```

## Interview questions and real-world scenarios

**Q: What problem does Kubernetes solve? Why not just Docker?**
Docker runs containers on one machine. Kubernetes runs them across many machines and keeps them in the desired state: it schedules, restarts, scales, updates and connects them. In an interview, mention self-healing and declarative configuration.

**Q: Walk me through the control-plane components.**
API server (front door, the only one talking to etcd), etcd (state), scheduler (picks nodes), controller-manager (reconcile loops). Nodes: kubelet, container runtime, kube-proxy.

**Q: What does "declarative" mean in Kubernetes?**
You describe the end state (a manifest), not the steps. Controllers continuously work to make reality match it. Applying the same file twice is safe.

**Q: What happens if etcd is lost?**
The cluster forgets every object. Running containers keep running for a while, but nothing can be changed or healed. That is why etcd backups (or a managed control plane) matter.

**Real-world scenario: "I ran a delete and it removed things from production."**
The kubeconfig context pointed at the prod cluster. Prevention: always check `kubectl config current-context`, show the context in your shell prompt, use separate kubeconfig files or tools like kubectx, and give people read-only access to production by default.

**Real-world scenario: "Two teams keep overwriting each other's objects."**
Both deploy into `default` with the same names. Give each team or environment its own namespace, with RBAC and ResourceQuotas per namespace.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-basics-int-q1",
      "type": "mcq",
      "prompt": "An interviewer asks: 'If the whole control plane goes down for 10 minutes, what happens to running apps?'",
      "options": [
        {
          "id": "a",
          "text": "All containers stop immediately"
        },
        {
          "id": "b",
          "text": "Running pods keep running, but nothing new can be scheduled, scaled, healed or changed until it returns"
        },
        {
          "id": "c",
          "text": "Nodes delete their pods"
        },
        {
          "id": "d",
          "text": "Traffic is automatically blocked"
        }
      ],
      "correct": "b",
      "explanation": "Nodes keep running what they already have. Without the API server and controllers, no changes or self-healing happen."
    }
  ]
}
```
