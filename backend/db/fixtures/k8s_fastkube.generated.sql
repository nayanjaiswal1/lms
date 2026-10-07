-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-09-27T11:14:53Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: Kubernetes from Zero to Production ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, is_public, estimated_hours)
VALUES ('36d5d8be-468e-5eb6-b650-0f5c827cb390', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'Kubernetes from Zero to Production', 'fast-kubernetes', 'Learn Kubernetes from the very first idea to running real workloads in production. Starts with what a cluster is and how it works, then builds up step by step: pods, Deployments and rolling updates, DaemonSets, StatefulSets, Jobs and CronJobs, Services, DNS, Ingress and Gateway API, ConfigMaps and Secrets, persistent storage, health probes, resources and scheduling, Helm, monitoring and autoscaling, building a real cluster with kubeadm, RBAC and node maintenance. Every lesson has quick knowledge checks, interview questions with answers, and real-world troubleshooting scenarios, and every section has hands-on labs in a live Kubernetes terminal.', '/course-covers/fast-kubernetes.svg', 'beginner', ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 'published', true, false, 20.5)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, cover_url=EXCLUDED.cover_url, tags=EXCLUDED.tags, is_public=EXCLUDED.is_public, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();

-- Section: Kubernetes Basics
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('85bd3d1f-d6a7-55f2-a8f2-52ff1a44d37b', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Kubernetes Basics', 1)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('75e5690e-cdcb-5a0f-befa-1e97e0d99175', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '85bd3d1f-d6a7-55f2-a8f2-52ff1a44d37b', 'What Kubernetes Is and How It Works', 'notes', 0, $md$Kubernetes (often written **K8s**, because there are 8 letters between the K and the s) is a system that runs containers for you across many machines. You tell it *what* you want running, and it keeps making that true.

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
$md$, 45, $json$[{"id":"k8s-basics-container-q1","type":"mcq","correct":"b"},{"id":"k8s-basics-container-q2","type":"mcq","correct":"b"},{"id":"k8s-basics-why-q1","type":"mcq","correct":"b"},{"id":"k8s-basics-arch-q1","type":"mcq","correct":"c"},{"id":"k8s-basics-arch-q2","type":"mcq","correct":"a"},{"id":"k8s-basics-desired-q1","type":"mcq","correct":"c"},{"id":"k8s-basics-yamlbasics-q1","type":"mcq","correct":"b"},{"id":"k8s-basics-yaml-q1","type":"mcq","correct":"b"},{"id":"k8s-basics-kubectl-q1","type":"mcq","correct":"b"},{"id":"k8s-basics-kubectl-q2","type":"mcq","correct":"a"},{"id":"k8s-basics-declarative-q1","type":"mcq","correct":"b"},{"id":"k8s-basics-ns-q1","type":"mcq","correct":"c"},{"id":"k8s-basics-labels-q1","type":"mcq","correct":"c"},{"id":"k8s-basics-where-q1","type":"mcq","correct":"b"},{"id":"k8s-basics-int-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('97d72332-3dbc-59da-8e6a-28c158220138', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '75e5690e-cdcb-5a0f-befa-1e97e0d99175', 'module', 'What Kubernetes Is and How It Works', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'ed5f91ee-3c0d-52dd-bc40-d669579a174b' AND id NOT IN ('598d33a2-2402-513f-a8db-dd75d3d09499', '7adc0c3e-c91b-5fdc-936c-c2d8e9569551', '0ad6b6b8-90a9-5cd4-86a1-e11e2a9ac6bc', 'dee73158-421c-5e4a-889b-767b68757f34');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'ed5f91ee-3c0d-52dd-bc40-d669579a174b';
DELETE FROM lab_tasks WHERE lab_id = '97d72332-3dbc-59da-8e6a-28c158220138' AND id NOT IN ('8113611a-ab05-5dfc-8f34-06fff3edb3f6', '5abfa821-0c30-5363-a94f-6f915d9abb72', '97a7b47b-eeda-5ff1-987b-a4e75e0d77e6', '26f65eac-83ed-5110-ab47-0defe940b7db');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '97d72332-3dbc-59da-8e6a-28c158220138';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('8113611a-ab05-5dfc-8f34-06fff3edb3f6', '97d72332-3dbc-59da-8e6a-28c158220138', 1, 'Generate YAML instead of typing it', $md$Without creating anything, generate the YAML for a pod called `web` (image `nginx`) and save it to `~/work/web.yaml`.$md$, $script$#!/bin/bash
f=/home/labuser/work/web.yaml
test -f "$f" && grep -q 'kind: Pod' "$f" && grep -q 'name: web' "$f" && ! kubectl get pod web >/dev/null 2>&1
$script$, 'Add `--dry-run=client -o yaml` to a `kubectl run` command and redirect the output with `>`.', '`--dry-run=client` builds the object locally without sending it to the cluster, and `-o yaml` prints it. This is the fastest way to start a new manifest.', 10, false, false),
('5abfa821-0c30-5363-a94f-6f915d9abb72', '97d72332-3dbc-59da-8e6a-28c158220138', 2, 'Create a namespace', $md$Create a namespace called `dev`.$md$, $script$#!/bin/bash
kubectl get namespace dev -o jsonpath='{.status.phase}' | grep -qx Active
$script$, '`kubectl create namespace <name>` creates a namespace.', 'A namespace is a named folder inside the cluster. Objects in `dev` do not clash with objects of the same name in `default`.', 10, false, true),
('97a7b47b-eeda-5ff1-987b-a4e75e0d77e6', '97d72332-3dbc-59da-8e6a-28c158220138', 3, 'Run a pod in that namespace', $md$Run a pod called `hello` from the `nginx` image in the `dev` namespace, with the label `app=hello`.$md$, $script$#!/bin/bash
kubectl get pod hello -n dev -o jsonpath='{.spec.containers[0].image} {.metadata.labels.app}' | grep -qx 'nginx hello'
$script$, '`kubectl run` takes `--image`, `--labels` and `-n <namespace>`.', '`kubectl run hello --image=nginx --labels=app=hello -n dev` asks the API server to store a Pod object. The scheduler then picks a node for it and the node starts it.', 10, false, true),
('26f65eac-83ed-5110-ab47-0defe940b7db', '97d72332-3dbc-59da-8e6a-28c158220138', 4, 'Label a node', $md$Add the label `env=lab` to the node `kwok-node`, then list nodes with `kubectl get nodes --show-labels` to see it.$md$, $script$#!/bin/bash
kubectl get node kwok-node -o jsonpath='{.metadata.labels.env}' | grep -qx lab
$script$, '`kubectl label <kind> <name> key=value` adds a label to any object.', 'Labels work the same on every kind of object. Later lessons use node labels to control where pods run.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('ed5f91ee-3c0d-52dd-bc40-d669579a174b', '97d72332-3dbc-59da-8e6a-28c158220138', 1, $json$[{"id":"8113611a-ab05-5dfc-8f34-06fff3edb3f6","lab_id":"97d72332-3dbc-59da-8e6a-28c158220138","position":1,"title":"Generate YAML instead of typing it","description":"Without creating anything, generate the YAML for a pod called `web` (image `nginx`) and save it to `~/work/web.yaml`.","verification_script":"#!/bin/bash\nf=/home/labuser/work/web.yaml\ntest -f \"$f\" \u0026\u0026 grep -q 'kind: Pod' \"$f\" \u0026\u0026 grep -q 'name: web' \"$f\" \u0026\u0026 ! kubectl get pod web \u003e/dev/null 2\u003e\u00261\n","hint_context":"Add `--dry-run=client -o yaml` to a `kubectl run` command and redirect the output with `\u003e`.","explanation_context":"`--dry-run=client` builds the object locally without sending it to the cluster, and `-o yaml` prints it. This is the fastest way to start a new manifest.","points":10,"is_optional":false,"is_stateful":false},{"id":"5abfa821-0c30-5363-a94f-6f915d9abb72","lab_id":"97d72332-3dbc-59da-8e6a-28c158220138","position":2,"title":"Create a namespace","description":"Create a namespace called `dev`.","verification_script":"#!/bin/bash\nkubectl get namespace dev -o jsonpath='{.status.phase}' | grep -qx Active\n","hint_context":"`kubectl create namespace \u003cname\u003e` creates a namespace.","explanation_context":"A namespace is a named folder inside the cluster. Objects in `dev` do not clash with objects of the same name in `default`.","points":10,"is_optional":false,"is_stateful":true},{"id":"97a7b47b-eeda-5ff1-987b-a4e75e0d77e6","lab_id":"97d72332-3dbc-59da-8e6a-28c158220138","position":3,"title":"Run a pod in that namespace","description":"Run a pod called `hello` from the `nginx` image in the `dev` namespace, with the label `app=hello`.","verification_script":"#!/bin/bash\nkubectl get pod hello -n dev -o jsonpath='{.spec.containers[0].image} {.metadata.labels.app}' | grep -qx 'nginx hello'\n","hint_context":"`kubectl run` takes `--image`, `--labels` and `-n \u003cnamespace\u003e`.","explanation_context":"`kubectl run hello --image=nginx --labels=app=hello -n dev` asks the API server to store a Pod object. The scheduler then picks a node for it and the node starts it.","points":10,"is_optional":false,"is_stateful":true},{"id":"26f65eac-83ed-5110-ab47-0defe940b7db","lab_id":"97d72332-3dbc-59da-8e6a-28c158220138","position":4,"title":"Label a node","description":"Add the label `env=lab` to the node `kwok-node`, then list nodes with `kubectl get nodes --show-labels` to see it.","verification_script":"#!/bin/bash\nkubectl get node kwok-node -o jsonpath='{.metadata.labels.env}' | grep -qx lab\n","hint_context":"`kubectl label \u003ckind\u003e \u003cname\u003e key=value` adds a label to any object.","explanation_context":"Labels work the same on every kind of object. Later lessons use node labels to control where pods run.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('598d33a2-2402-513f-a8db-dd75d3d09499', 'ed5f91ee-3c0d-52dd-bc40-d669579a174b', '8113611a-ab05-5dfc-8f34-06fff3edb3f6', 1, 'Generate YAML instead of typing it', $md$Without creating anything, generate the YAML for a pod called `web` (image `nginx`) and save it to `~/work/web.yaml`.$md$, $script$#!/bin/bash
f=/home/labuser/work/web.yaml
test -f "$f" && grep -q 'kind: Pod' "$f" && grep -q 'name: web' "$f" && ! kubectl get pod web >/dev/null 2>&1
$script$, 'Add `--dry-run=client -o yaml` to a `kubectl run` command and redirect the output with `>`.', '`--dry-run=client` builds the object locally without sending it to the cluster, and `-o yaml` prints it. This is the fastest way to start a new manifest.', 10, false, false),
('7adc0c3e-c91b-5fdc-936c-c2d8e9569551', 'ed5f91ee-3c0d-52dd-bc40-d669579a174b', '5abfa821-0c30-5363-a94f-6f915d9abb72', 2, 'Create a namespace', $md$Create a namespace called `dev`.$md$, $script$#!/bin/bash
kubectl get namespace dev -o jsonpath='{.status.phase}' | grep -qx Active
$script$, '`kubectl create namespace <name>` creates a namespace.', 'A namespace is a named folder inside the cluster. Objects in `dev` do not clash with objects of the same name in `default`.', 10, false, true),
('0ad6b6b8-90a9-5cd4-86a1-e11e2a9ac6bc', 'ed5f91ee-3c0d-52dd-bc40-d669579a174b', '97a7b47b-eeda-5ff1-987b-a4e75e0d77e6', 3, 'Run a pod in that namespace', $md$Run a pod called `hello` from the `nginx` image in the `dev` namespace, with the label `app=hello`.$md$, $script$#!/bin/bash
kubectl get pod hello -n dev -o jsonpath='{.spec.containers[0].image} {.metadata.labels.app}' | grep -qx 'nginx hello'
$script$, '`kubectl run` takes `--image`, `--labels` and `-n <namespace>`.', '`kubectl run hello --image=nginx --labels=app=hello -n dev` asks the API server to store a Pod object. The scheduler then picks a node for it and the node starts it.', 10, false, true),
('dee73158-421c-5e4a-889b-767b68757f34', 'ed5f91ee-3c0d-52dd-bc40-d669579a174b', '26f65eac-83ed-5110-ab47-0defe940b7db', 4, 'Label a node', $md$Add the label `env=lab` to the node `kwok-node`, then list nodes with `kubectl get nodes --show-labels` to see it.$md$, $script$#!/bin/bash
kubectl get node kwok-node -o jsonpath='{.metadata.labels.env}' | grep -qx lab
$script$, '`kubectl label <kind> <name> key=value` adds a label to any object.', 'Labels work the same on every kind of object. Later lessons use node labels to control where pods run.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'ed5f91ee-3c0d-52dd-bc40-d669579a174b', updated_at = now()
WHERE id = '97d72332-3dbc-59da-8e6a-28c158220138' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0cbe2e73-2b17-5899-98ae-2a6cfd9a0920', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the job of the kube-apiserver?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('8601d97c-dae7-5505-b8b0-961767d021c4', '0cbe2e73-2b17-5899-98ae-2a6cfd9a0920', 1, $json${"prompt":"What is the job of the kube-apiserver?","multiple":false,"options":[{"id":"a","text":"It runs containers on each node","is_correct":false},{"id":"b","text":"It is the single entry point for every read and write to the cluster state","is_correct":true},{"id":"c","text":"It balances network traffic between pods","is_correct":false},{"id":"d","text":"It builds container images","is_correct":false}],"explanation":"Every client (kubectl, controllers, the scheduler, kubelets) talks to the API server. It validates requests and is the only component that reads and writes etcd directly."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('72273b5c-9278-5dd1-9321-8151d0eb2d07', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which component runs on every worker node and makes sure the pods assigned to...', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0790820b-ec96-5e0f-a171-6fd699a7d6f8', '72273b5c-9278-5dd1-9321-8151d0eb2d07', 1, $json${"prompt":"Which component runs on every worker node and makes sure the pods assigned to that node are running?","multiple":false,"options":[{"id":"a","text":"kube-scheduler","is_correct":false},{"id":"b","text":"etcd","is_correct":false},{"id":"c","text":"kubelet","is_correct":true},{"id":"d","text":"kube-controller-manager","is_correct":false}],"explanation":"The kubelet is the node agent. It watches for pods assigned to its node and asks the container runtime to start and restart their containers."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('4b5c922d-e8d0-5a14-9c1f-e1f73c4e9127', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does "desired state" mean in Kubernetes?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e89d3fc9-21c9-5a26-b9db-67572ba438da', '4b5c922d-e8d0-5a14-9c1f-e1f73c4e9127', 1, $json${"prompt":"What does \"desired state\" mean in Kubernetes?","multiple":false,"options":[{"id":"a","text":"The state the cluster was in when it was first created","is_correct":false},{"id":"b","text":"What you declared you want (for example, 3 replicas), which controllers keep comparing with reality and enforcing","is_correct":true},{"id":"c","text":"The fastest possible configuration for your app","is_correct":false},{"id":"d","text":"A backup of etcd","is_correct":false}],"explanation":"You declare what you want in spec. Controllers run a reconcile loop that compares desired with actual state and acts whenever they differ."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('36c3e61a-25b6-54cb-9eff-eb25a6418499', '00000000-0000-0000-0000-000000000001', 'mcq', 'In a manifest, which field is written by Kubernetes rather than by you?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('176f2576-75c7-5db1-bffc-7643e738ca15', '36c3e61a-25b6-54cb-9eff-eb25a6418499', 1, $json${"prompt":"In a manifest, which field is written by Kubernetes rather than by you?","multiple":false,"options":[{"id":"a","text":"spec","is_correct":false},{"id":"b","text":"metadata.name","is_correct":false},{"id":"c","text":"kind","is_correct":false},{"id":"d","text":"status","is_correct":true}],"explanation":"status reports the actual state and is maintained by the cluster. You write apiVersion, kind, metadata and spec."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('dfe03da8-fdbe-5c19-9bc5-7c9da2ba6252', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command lists pods in every namespace?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('46553d31-db26-55c0-8fe1-b05e1b977aa2', 'dfe03da8-fdbe-5c19-9bc5-7c9da2ba6252', 1, $json${"prompt":"Which command lists pods in every namespace?","multiple":false,"options":[{"id":"a","text":"kubectl get pods --all","is_correct":false},{"id":"b","text":"kubectl get pods -A","is_correct":true},{"id":"c","text":"kubectl get pods -n all","is_correct":false},{"id":"d","text":"kubectl get namespaces --pods","is_correct":false}],"explanation":"-A is short for --all-namespaces. -n \u003cname\u003e selects one specific namespace."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('58fadce8-a26d-501b-9898-bbb399f095ce', '00000000-0000-0000-0000-000000000001', 'mcq', 'How does a Service know which pods to send traffic to?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a2046784-0e57-577a-834b-93ea83005370', '58fadce8-a26d-501b-9898-bbb399f095ce', 1, $json${"prompt":"How does a Service know which pods to send traffic to?","multiple":false,"options":[{"id":"a","text":"By pod name prefix","is_correct":false},{"id":"b","text":"By matching its label selector against pod labels","is_correct":true},{"id":"c","text":"By creation time","is_correct":false},{"id":"d","text":"It sends traffic to every pod in the namespace","is_correct":false}],"explanation":"Selectors match labels. Deployments find their pods and Services find their backends the same way."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('bec29041-4413-5e2f-a983-14fef3b4d295', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does `kubectl create deployment web --image=nginx --dry-run=client -o ya...', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('28ca9a43-a39e-5102-bd77-a85a0447d652', 'bec29041-4413-5e2f-a983-14fef3b4d295', 1, $json${"prompt":"What does `kubectl create deployment web --image=nginx --dry-run=client -o yaml` do?","multiple":false,"options":[{"id":"a","text":"Creates the deployment and prints it","is_correct":false},{"id":"b","text":"Prints the YAML for the deployment without creating anything in the cluster","is_correct":true},{"id":"c","text":"Validates an existing deployment called web","is_correct":false},{"id":"d","text":"Deletes the deployment and prints its last YAML","is_correct":false}],"explanation":"--dry-run=client builds the object on your machine only. It is the usual way to generate a starting manifest."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c1aa1187-0f55-5d14-ac68-2bb49147d434', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which of these objects is cluster-wide, meaning it does not belong to any nam...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4503123d-2c1b-519f-9327-7ec26b9ecb02', 'c1aa1187-0f55-5d14-ac68-2bb49147d434', 1, $json${"prompt":"Which of these objects is cluster-wide, meaning it does not belong to any namespace?","multiple":false,"options":[{"id":"a","text":"Pod","is_correct":false},{"id":"b","text":"Service","is_correct":false},{"id":"c","text":"Node","is_correct":true},{"id":"d","text":"ConfigMap","is_correct":false}],"explanation":"Nodes, PersistentVolumes, Namespaces and StorageClasses are cluster-scoped. `kubectl api-resources --namespaced=false` lists them all."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('d790eaba-01f1-5073-b491-1b027a3489ec', '00000000-0000-0000-0000-000000000001', 'Quiz: Kubernetes Basics', 'k8s-basics-quiz', 'Quiz covering Kubernetes Basics.', 'mcq', 'published', 'module', '4ef990d4-eedb-566d-b6d3-5ad316996fc0', 15, 70, 5, 8, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = 'd790eaba-01f1-5073-b491-1b027a3489ec' AND question_id NOT IN ('0cbe2e73-2b17-5899-98ae-2a6cfd9a0920', '72273b5c-9278-5dd1-9321-8151d0eb2d07', '4b5c922d-e8d0-5a14-9c1f-e1f73c4e9127', '36c3e61a-25b6-54cb-9eff-eb25a6418499', 'dfe03da8-fdbe-5c19-9bc5-7c9da2ba6252', '58fadce8-a26d-501b-9898-bbb399f095ce', 'bec29041-4413-5e2f-a983-14fef3b4d295', 'c1aa1187-0f55-5d14-ac68-2bb49147d434');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('920907eb-5d04-5d34-9f4b-279f70c8b487', 'd790eaba-01f1-5073-b491-1b027a3489ec', '0cbe2e73-2b17-5899-98ae-2a6cfd9a0920', '8601d97c-dae7-5505-b8b0-961767d021c4', 0, 1),
('272d7752-39f8-50de-a6f4-09742bd3fd18', 'd790eaba-01f1-5073-b491-1b027a3489ec', '72273b5c-9278-5dd1-9321-8151d0eb2d07', '0790820b-ec96-5e0f-a171-6fd699a7d6f8', 1, 1),
('b8a1a212-86c8-52ec-a967-1026ee016b04', 'd790eaba-01f1-5073-b491-1b027a3489ec', '4b5c922d-e8d0-5a14-9c1f-e1f73c4e9127', 'e89d3fc9-21c9-5a26-b9db-67572ba438da', 2, 1),
('ba9a37bd-021f-5f83-81d7-b9c5b4540233', 'd790eaba-01f1-5073-b491-1b027a3489ec', '36c3e61a-25b6-54cb-9eff-eb25a6418499', '176f2576-75c7-5db1-bffc-7643e738ca15', 3, 1),
('f70d967c-16c2-5ea1-95e6-9b81c8f5f7e2', 'd790eaba-01f1-5073-b491-1b027a3489ec', 'dfe03da8-fdbe-5c19-9bc5-7c9da2ba6252', '46553d31-db26-55c0-8fe1-b05e1b977aa2', 4, 1),
('d86995b8-9d18-5158-a484-3173ee365b07', 'd790eaba-01f1-5073-b491-1b027a3489ec', '58fadce8-a26d-501b-9898-bbb399f095ce', 'a2046784-0e57-577a-834b-93ea83005370', 5, 1),
('4fc46716-ee34-54f5-a1c7-42be308f153b', 'd790eaba-01f1-5073-b491-1b027a3489ec', 'bec29041-4413-5e2f-a983-14fef3b4d295', '28ca9a43-a39e-5102-bd77-a85a0447d652', 6, 1),
('0d9bb982-3cd0-59bb-9a99-8e8ca8344ae4', 'd790eaba-01f1-5073-b491-1b027a3489ec', 'c1aa1187-0f55-5d14-ac68-2bb49147d434', '4503123d-2c1b-519f-9327-7ec26b9ecb02', 7, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('4ef990d4-eedb-566d-b6d3-5ad316996fc0', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '85bd3d1f-d6a7-55f2-a8f2-52ff1a44d37b', 'Quiz: Kubernetes Basics', 'assessment', 1, 10, 'd790eaba-01f1-5073-b491-1b027a3489ec')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Pods
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('375a87e0-e417-5b1c-8bc5-3852ed089e52', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Pods', 2)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6d93934c-2315-5e0e-adcc-774073f33cd5', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '375a87e0-e417-5b1c-8bc5-3852ed089e52', 'Pods, the Smallest Unit in Kubernetes', 'notes', 0, $md$Kubernetes never runs a container on its own. It always wraps containers in a **Pod**. Every other workload you will learn (Deployments, Jobs, StatefulSets) exists to create and manage pods, so this lesson is the foundation for the rest of the course.

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
$md$, 50, $json$[{"id":"k8s-pod-what-q1","type":"mcq","correct":"a"},{"id":"k8s-pod-what-q2","type":"mcq","correct":"b"},{"id":"k8s-pod-imperative-q1","type":"mcq","correct":"b"},{"id":"k8s-pod-yaml-q1","type":"mcq","correct":"b"},{"id":"k8s-pod-debug-q1","type":"mcq","correct":"a"},{"id":"k8s-pod-lifecycle-q1","type":"mcq","correct":"b"},{"id":"k8s-pod-lifecycle-q2","type":"mcq","correct":"c"},{"id":"k8s-pod-sidecar-q1","type":"mcq","correct":"c"},{"id":"k8s-pod-sidecar-q2","type":"mcq","correct":"b"},{"id":"k8s-pod-init-q1","type":"mcq","correct":"b"},{"id":"k8s-pod-portfwd-q1","type":"mcq","correct":"b"},{"id":"k8s-pod-bare-q1","type":"mcq","correct":"b"},{"id":"k8s-pod-int-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('d9f9a269-17b3-56ec-9885-3b8af346cd13', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '375a87e0-e417-5b1c-8bc5-3852ed089e52', 'Lab: Create and Inspect Pods', 'lab', 1, 25)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('3a2dfb5c-a7c1-589b-814e-0179fd5221b3', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'd9f9a269-17b3-56ec-9885-3b8af346cd13', 'module', 'Lab: Create and Inspect Pods', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/pod1.yaml <<'MFEOF'
apiVersion: v1
kind: Pod
metadata:
  name: firstpod
  labels:
    app: frontend
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    ports:
    - containerPort: 80
    env:
    - name: USER
      value: "username"

MFEOF
chmod 666 /home/labuser/work/pod1.yaml
cat > /home/labuser/work/multicontainer.yaml <<'MFEOF'
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
      mountPath: /usr/share/nginx/html
  - name: sidecarcontainer
    image: busybox:1.36
    command: ["/bin/sh", "-c"]
    args: ["while true; do echo \"<h1>Updated at $(date)</h1>\" > /var/log/index.html; sleep 15; done"]
    volumeMounts:
    - name: sharedvolume
      mountPath: /var/log
  volumes:
  - name: sharedvolume
    emptyDir: {}

MFEOF
chmod 666 /home/labuser/work/multicontainer.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '56093b77-4d3c-5060-90f2-2a7b752fb261' AND id NOT IN ('084a2d90-3178-5d67-8e78-cce1957a1156', '40c1ec45-4276-5cf7-8bbf-bc3d5176cc11', 'cacfe6ba-16ca-5de0-9ef7-52bd4304a853', '0d80a6c7-ad16-503b-bac2-97b49ecbac45', 'c69f5061-bbfd-5a96-9adc-9bb89f2849a3', '06dd3706-3cb8-5887-8c81-17c1b76d6d98');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '56093b77-4d3c-5060-90f2-2a7b752fb261';
DELETE FROM lab_tasks WHERE lab_id = '3a2dfb5c-a7c1-589b-814e-0179fd5221b3' AND id NOT IN ('51c3cdd8-23d3-5852-acdd-f54faa1f693f', 'f88262b7-ca3b-52e0-bb25-061104763aa4', 'd2c42c3c-036c-5e3a-be5d-4b15eba02e29', 'ed999a30-a452-5ac0-ab00-2965b568bbd7', '05663f5e-e3bb-5874-bab0-0c64fe456a46', '3af9977b-b6fa-5651-b0f6-b7c6e97200d7');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '3a2dfb5c-a7c1-589b-814e-0179fd5221b3';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('51c3cdd8-23d3-5852-acdd-f54faa1f693f', '3a2dfb5c-a7c1-589b-814e-0179fd5221b3', 1, 'Run a pod with one command', $md$Create a pod called `mypod` from the image `nginx:1.27` using `kubectl run`. Then look at it with `kubectl get pods -o wide`.

Note: nodes in this sandbox are simulated. Pods really get scheduled and become `Running`, but no real process runs inside them, so `kubectl logs`, `exec` and `port-forward` will not work here.
$md$, $script$#!/bin/bash
kubectl get pod mypod -o jsonpath='{.spec.containers[0].image} {.status.phase}' | grep -qx 'nginx:1.27 Running'
$script$, '`kubectl run <name> --image=<image>`', '`kubectl run mypod --image=nginx:1.27` creates a Pod object. The scheduler assigns it to a node and the node reports it as Running.', 10, false, true),
('f88262b7-ca3b-52e0-bb25-061104763aa4', '3a2dfb5c-a7c1-589b-814e-0179fd5221b3', 2, 'Create a pod from a YAML file', $md$Your work folder already has `pod1.yaml`. Read it with `cat pod1.yaml`, then create the pod from it. Use `kubectl describe pod firstpod` to find its labels and environment variables.$md$, $script$#!/bin/bash
kubectl get pod firstpod -o jsonpath='{.metadata.labels.app} {.spec.containers[0].env[?(@.name=="USER")].value} {.status.phase}' | grep -qx 'frontend username Running'
$script$, '`kubectl apply -f <file>`', '`kubectl apply -f pod1.yaml` sends the manifest to the API server. Because it is a file, you can apply it again later and get the same pod.', 10, false, true),
('d2c42c3c-036c-5e3a-be5d-4b15eba02e29', '3a2dfb5c-a7c1-589b-814e-0179fd5221b3', 3, 'Add a label to a running pod', $md$Add the label `tier=web` to `firstpod`. Then list only pods with that label using a selector.$md$, $script$#!/bin/bash
kubectl get pods -l tier=web -o name | grep -qx pod/firstpod
$script$, '`kubectl label pod <name> key=value`, then `kubectl get pods -l key=value`.', 'Labels can be added or removed at any time without restarting the pod. Selectors like `-l tier=web` are exactly how Services and Deployments find pods.', 10, false, false),
('ed999a30-a452-5ac0-ab00-2965b568bbd7', '3a2dfb5c-a7c1-589b-814e-0179fd5221b3', 4, 'Run a pod with a sidecar container', $md$Create the pod in `multicontainer.yaml`. Check that it shows `READY 2/2`, and use `kubectl describe pod multicontainer` to see that both containers mount the same `sharedvolume`.$md$, $script$#!/bin/bash
kubectl get pod multicontainer -o jsonpath='{.spec.containers[*].name}' | grep -qx 'webcontainer sidecarcontainer' || exit 1
kubectl get pod multicontainer -o jsonpath='{.spec.volumes[0].emptyDir}' | grep -q '{}' || exit 1
kubectl get pod multicontainer -o jsonpath='{.status.phase}' | grep -qx Running
$script$, 'Apply the file the same way as `pod1.yaml`.', 'Both containers mount the `sharedvolume` emptyDir, so a file written by the sidecar is served by nginx. READY 2/2 means both containers are ready.', 15, false, true),
('05663f5e-e3bb-5874-bab0-0c64fe456a46', '3a2dfb5c-a7c1-589b-814e-0179fd5221b3', 5, 'Write a pod with an init container', $md$Write your own manifest `initpod.yaml` for a pod named `initpod` that has:
- an init container named `setup` using image `busybox:1.36` with command `["sh", "-c", "echo preparing"]`
- an app container named `app` using image `nginx:1.27`

Apply it. Tip: start from `kubectl run initpod --image=nginx:1.27 --dry-run=client -o yaml > initpod.yaml` and add the `initContainers` list under `spec`.
$md$, $script$#!/bin/bash
kubectl get pod initpod -o jsonpath='{.spec.initContainers[0].name} {.spec.initContainers[0].image} {.spec.containers[0].image}' | grep -qx 'setup busybox:1.36 nginx:1.27'
$script$, '`initContainers` is a list at the same level as `containers` inside `spec`, and each entry has name, image and command.', 'Init containers run to completion, one by one, before any app container starts. They are the right place for setup work such as waiting for a dependency.', 20, false, false),
('3af9977b-b6fa-5651-b0f6-b7c6e97200d7', '3a2dfb5c-a7c1-589b-814e-0179fd5221b3', 6, 'Delete a pod', $md$Delete `mypod`. Notice that nothing recreates it, because no controller owns a bare pod.$md$, $script$#!/bin/bash
kubectl get pod firstpod >/dev/null 2>&1 || exit 1
! kubectl get pod mypod >/dev/null 2>&1
$script$, '`kubectl delete pod <name>`', 'A bare pod is gone for good once deleted. In the next section a Deployment will recreate deleted pods automatically.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('56093b77-4d3c-5060-90f2-2a7b752fb261', '3a2dfb5c-a7c1-589b-814e-0179fd5221b3', 1, $json$[{"id":"51c3cdd8-23d3-5852-acdd-f54faa1f693f","lab_id":"3a2dfb5c-a7c1-589b-814e-0179fd5221b3","position":1,"title":"Run a pod with one command","description":"Create a pod called `mypod` from the image `nginx:1.27` using `kubectl run`. Then look at it with `kubectl get pods -o wide`.\n\nNote: nodes in this sandbox are simulated. Pods really get scheduled and become `Running`, but no real process runs inside them, so `kubectl logs`, `exec` and `port-forward` will not work here.\n","verification_script":"#!/bin/bash\nkubectl get pod mypod -o jsonpath='{.spec.containers[0].image} {.status.phase}' | grep -qx 'nginx:1.27 Running'\n","hint_context":"`kubectl run \u003cname\u003e --image=\u003cimage\u003e`","explanation_context":"`kubectl run mypod --image=nginx:1.27` creates a Pod object. The scheduler assigns it to a node and the node reports it as Running.","points":10,"is_optional":false,"is_stateful":true},{"id":"f88262b7-ca3b-52e0-bb25-061104763aa4","lab_id":"3a2dfb5c-a7c1-589b-814e-0179fd5221b3","position":2,"title":"Create a pod from a YAML file","description":"Your work folder already has `pod1.yaml`. Read it with `cat pod1.yaml`, then create the pod from it. Use `kubectl describe pod firstpod` to find its labels and environment variables.","verification_script":"#!/bin/bash\nkubectl get pod firstpod -o jsonpath='{.metadata.labels.app} {.spec.containers[0].env[?(@.name==\"USER\")].value} {.status.phase}' | grep -qx 'frontend username Running'\n","hint_context":"`kubectl apply -f \u003cfile\u003e`","explanation_context":"`kubectl apply -f pod1.yaml` sends the manifest to the API server. Because it is a file, you can apply it again later and get the same pod.","points":10,"is_optional":false,"is_stateful":true},{"id":"d2c42c3c-036c-5e3a-be5d-4b15eba02e29","lab_id":"3a2dfb5c-a7c1-589b-814e-0179fd5221b3","position":3,"title":"Add a label to a running pod","description":"Add the label `tier=web` to `firstpod`. Then list only pods with that label using a selector.","verification_script":"#!/bin/bash\nkubectl get pods -l tier=web -o name | grep -qx pod/firstpod\n","hint_context":"`kubectl label pod \u003cname\u003e key=value`, then `kubectl get pods -l key=value`.","explanation_context":"Labels can be added or removed at any time without restarting the pod. Selectors like `-l tier=web` are exactly how Services and Deployments find pods.","points":10,"is_optional":false,"is_stateful":false},{"id":"ed999a30-a452-5ac0-ab00-2965b568bbd7","lab_id":"3a2dfb5c-a7c1-589b-814e-0179fd5221b3","position":4,"title":"Run a pod with a sidecar container","description":"Create the pod in `multicontainer.yaml`. Check that it shows `READY 2/2`, and use `kubectl describe pod multicontainer` to see that both containers mount the same `sharedvolume`.","verification_script":"#!/bin/bash\nkubectl get pod multicontainer -o jsonpath='{.spec.containers[*].name}' | grep -qx 'webcontainer sidecarcontainer' || exit 1\nkubectl get pod multicontainer -o jsonpath='{.spec.volumes[0].emptyDir}' | grep -q '{}' || exit 1\nkubectl get pod multicontainer -o jsonpath='{.status.phase}' | grep -qx Running\n","hint_context":"Apply the file the same way as `pod1.yaml`.","explanation_context":"Both containers mount the `sharedvolume` emptyDir, so a file written by the sidecar is served by nginx. READY 2/2 means both containers are ready.","points":15,"is_optional":false,"is_stateful":true},{"id":"05663f5e-e3bb-5874-bab0-0c64fe456a46","lab_id":"3a2dfb5c-a7c1-589b-814e-0179fd5221b3","position":5,"title":"Write a pod with an init container","description":"Write your own manifest `initpod.yaml` for a pod named `initpod` that has:\n- an init container named `setup` using image `busybox:1.36` with command `[\"sh\", \"-c\", \"echo preparing\"]`\n- an app container named `app` using image `nginx:1.27`\n\nApply it. Tip: start from `kubectl run initpod --image=nginx:1.27 --dry-run=client -o yaml \u003e initpod.yaml` and add the `initContainers` list under `spec`.\n","verification_script":"#!/bin/bash\nkubectl get pod initpod -o jsonpath='{.spec.initContainers[0].name} {.spec.initContainers[0].image} {.spec.containers[0].image}' | grep -qx 'setup busybox:1.36 nginx:1.27'\n","hint_context":"`initContainers` is a list at the same level as `containers` inside `spec`, and each entry has name, image and command.","explanation_context":"Init containers run to completion, one by one, before any app container starts. They are the right place for setup work such as waiting for a dependency.","points":20,"is_optional":false,"is_stateful":false},{"id":"3af9977b-b6fa-5651-b0f6-b7c6e97200d7","lab_id":"3a2dfb5c-a7c1-589b-814e-0179fd5221b3","position":6,"title":"Delete a pod","description":"Delete `mypod`. Notice that nothing recreates it, because no controller owns a bare pod.","verification_script":"#!/bin/bash\nkubectl get pod firstpod \u003e/dev/null 2\u003e\u00261 || exit 1\n! kubectl get pod mypod \u003e/dev/null 2\u003e\u00261\n","hint_context":"`kubectl delete pod \u003cname\u003e`","explanation_context":"A bare pod is gone for good once deleted. In the next section a Deployment will recreate deleted pods automatically.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('084a2d90-3178-5d67-8e78-cce1957a1156', '56093b77-4d3c-5060-90f2-2a7b752fb261', '51c3cdd8-23d3-5852-acdd-f54faa1f693f', 1, 'Run a pod with one command', $md$Create a pod called `mypod` from the image `nginx:1.27` using `kubectl run`. Then look at it with `kubectl get pods -o wide`.

Note: nodes in this sandbox are simulated. Pods really get scheduled and become `Running`, but no real process runs inside them, so `kubectl logs`, `exec` and `port-forward` will not work here.
$md$, $script$#!/bin/bash
kubectl get pod mypod -o jsonpath='{.spec.containers[0].image} {.status.phase}' | grep -qx 'nginx:1.27 Running'
$script$, '`kubectl run <name> --image=<image>`', '`kubectl run mypod --image=nginx:1.27` creates a Pod object. The scheduler assigns it to a node and the node reports it as Running.', 10, false, true),
('40c1ec45-4276-5cf7-8bbf-bc3d5176cc11', '56093b77-4d3c-5060-90f2-2a7b752fb261', 'f88262b7-ca3b-52e0-bb25-061104763aa4', 2, 'Create a pod from a YAML file', $md$Your work folder already has `pod1.yaml`. Read it with `cat pod1.yaml`, then create the pod from it. Use `kubectl describe pod firstpod` to find its labels and environment variables.$md$, $script$#!/bin/bash
kubectl get pod firstpod -o jsonpath='{.metadata.labels.app} {.spec.containers[0].env[?(@.name=="USER")].value} {.status.phase}' | grep -qx 'frontend username Running'
$script$, '`kubectl apply -f <file>`', '`kubectl apply -f pod1.yaml` sends the manifest to the API server. Because it is a file, you can apply it again later and get the same pod.', 10, false, true),
('cacfe6ba-16ca-5de0-9ef7-52bd4304a853', '56093b77-4d3c-5060-90f2-2a7b752fb261', 'd2c42c3c-036c-5e3a-be5d-4b15eba02e29', 3, 'Add a label to a running pod', $md$Add the label `tier=web` to `firstpod`. Then list only pods with that label using a selector.$md$, $script$#!/bin/bash
kubectl get pods -l tier=web -o name | grep -qx pod/firstpod
$script$, '`kubectl label pod <name> key=value`, then `kubectl get pods -l key=value`.', 'Labels can be added or removed at any time without restarting the pod. Selectors like `-l tier=web` are exactly how Services and Deployments find pods.', 10, false, false),
('0d80a6c7-ad16-503b-bac2-97b49ecbac45', '56093b77-4d3c-5060-90f2-2a7b752fb261', 'ed999a30-a452-5ac0-ab00-2965b568bbd7', 4, 'Run a pod with a sidecar container', $md$Create the pod in `multicontainer.yaml`. Check that it shows `READY 2/2`, and use `kubectl describe pod multicontainer` to see that both containers mount the same `sharedvolume`.$md$, $script$#!/bin/bash
kubectl get pod multicontainer -o jsonpath='{.spec.containers[*].name}' | grep -qx 'webcontainer sidecarcontainer' || exit 1
kubectl get pod multicontainer -o jsonpath='{.spec.volumes[0].emptyDir}' | grep -q '{}' || exit 1
kubectl get pod multicontainer -o jsonpath='{.status.phase}' | grep -qx Running
$script$, 'Apply the file the same way as `pod1.yaml`.', 'Both containers mount the `sharedvolume` emptyDir, so a file written by the sidecar is served by nginx. READY 2/2 means both containers are ready.', 15, false, true),
('c69f5061-bbfd-5a96-9adc-9bb89f2849a3', '56093b77-4d3c-5060-90f2-2a7b752fb261', '05663f5e-e3bb-5874-bab0-0c64fe456a46', 5, 'Write a pod with an init container', $md$Write your own manifest `initpod.yaml` for a pod named `initpod` that has:
- an init container named `setup` using image `busybox:1.36` with command `["sh", "-c", "echo preparing"]`
- an app container named `app` using image `nginx:1.27`

Apply it. Tip: start from `kubectl run initpod --image=nginx:1.27 --dry-run=client -o yaml > initpod.yaml` and add the `initContainers` list under `spec`.
$md$, $script$#!/bin/bash
kubectl get pod initpod -o jsonpath='{.spec.initContainers[0].name} {.spec.initContainers[0].image} {.spec.containers[0].image}' | grep -qx 'setup busybox:1.36 nginx:1.27'
$script$, '`initContainers` is a list at the same level as `containers` inside `spec`, and each entry has name, image and command.', 'Init containers run to completion, one by one, before any app container starts. They are the right place for setup work such as waiting for a dependency.', 20, false, false),
('06dd3706-3cb8-5887-8c81-17c1b76d6d98', '56093b77-4d3c-5060-90f2-2a7b752fb261', '3af9977b-b6fa-5651-b0f6-b7c6e97200d7', 6, 'Delete a pod', $md$Delete `mypod`. Notice that nothing recreates it, because no controller owns a bare pod.$md$, $script$#!/bin/bash
kubectl get pod firstpod >/dev/null 2>&1 || exit 1
! kubectl get pod mypod >/dev/null 2>&1
$script$, '`kubectl delete pod <name>`', 'A bare pod is gone for good once deleted. In the next section a Deployment will recreate deleted pods automatically.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '56093b77-4d3c-5060-90f2-2a7b752fb261', updated_at = now()
WHERE id = '3a2dfb5c-a7c1-589b-814e-0179fd5221b3' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ed5daec9-cbbf-522a-82dc-99453e20dd44', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which statement best describes a pod?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('dd355da9-cdb5-5eea-ac7d-9aca920d93c9', 'ed5daec9-cbbf-522a-82dc-99453e20dd44', 1, $json${"prompt":"Which statement best describes a pod?","multiple":false,"options":[{"id":"a","text":"A virtual machine that runs one container","is_correct":false},{"id":"b","text":"One or more containers that are scheduled together and share an IP address and volumes","is_correct":true},{"id":"c","text":"A group of nodes","is_correct":false},{"id":"d","text":"A saved copy of a container image","is_correct":false}],"explanation":"A pod is the smallest deployable unit. Its containers share one network namespace (one IP, localhost between them) and can share volumes."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a9efe830-6e2c-5102-8b10-4bbeae811655', '00000000-0000-0000-0000-000000000001', 'mcq', 'A pod stays in CrashLoopBackOff. Which command is the best first step to find...', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('84a4c890-2e0d-561c-bd7c-555968d87a4f', 'a9efe830-6e2c-5102-8b10-4bbeae811655', 1, $json${"prompt":"A pod stays in CrashLoopBackOff. Which command is the best first step to find out why the app dies?","multiple":false,"options":[{"id":"a","text":"kubectl logs \u003cpod\u003e --previous","is_correct":true},{"id":"b","text":"kubectl get nodes","is_correct":false},{"id":"c","text":"kubectl delete pod \u003cpod\u003e","is_correct":false},{"id":"d","text":"kubectl scale --replicas=0","is_correct":false}],"explanation":"CrashLoopBackOff means the process keeps exiting. The logs of the previous (crashed) container usually show the error."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('dd94a27e-2662-562a-9a21-dfd675dc4585', '00000000-0000-0000-0000-000000000001', 'mcq', 'A pod has been Pending for 10 minutes. What does that usually mean?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f6b76fdc-0f6e-59b8-a94f-d4f7e60a452c', 'dd94a27e-2662-562a-9a21-dfd675dc4585', 1, $json${"prompt":"A pod has been Pending for 10 minutes. What does that usually mean?","multiple":false,"options":[{"id":"a","text":"The app inside is crashing","is_correct":false},{"id":"b","text":"It has not started yet, often because no node has enough resources or no node matches its scheduling rules","is_correct":true},{"id":"c","text":"The pod finished its work successfully","is_correct":false},{"id":"d","text":"The pod is being deleted","is_correct":false}],"explanation":"Pending means the pod is not running yet. `kubectl describe pod` shows the scheduler's reason in Events, for example \"0/3 nodes are available: insufficient memory\"."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6f028f35-5362-57c2-8196-d0ceb24978b9', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the sidecar pattern?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1b7a8394-a794-5c04-9df6-f4ee049e5a91', '6f028f35-5362-57c2-8196-d0ceb24978b9', 1, $json${"prompt":"What is the sidecar pattern?","multiple":false,"options":[{"id":"a","text":"Running two copies of the same app in different pods","is_correct":false},{"id":"b","text":"A helper container in the same pod as the main app, for example a log shipper or proxy","is_correct":true},{"id":"c","text":"A pod that runs only on the control plane","is_correct":false},{"id":"d","text":"A backup node for a failed node","is_correct":false}],"explanation":"A sidecar lives in the same pod so it shares the app's network and volumes."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2597e234-622b-557c-8553-b187981d0ea5', '00000000-0000-0000-0000-000000000001', 'mcq', 'What happens to data in an emptyDir volume when one container in the pod rest...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('16c40eb0-56cf-5a4b-bf56-05686a43ff65', '2597e234-622b-557c-8553-b187981d0ea5', 1, $json${"prompt":"What happens to data in an emptyDir volume when one container in the pod restarts (but the pod is not deleted)?","multiple":false,"options":[{"id":"a","text":"The data is lost","is_correct":false},{"id":"b","text":"The data is kept, because emptyDir lives as long as the pod","is_correct":true},{"id":"c","text":"The data is moved to etcd","is_correct":false},{"id":"d","text":"The whole pod is recreated","is_correct":false}],"explanation":"emptyDir belongs to the pod, not the container. It survives container restarts and is removed only when the pod is removed from the node."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('da4dba26-9511-5712-a310-b2a29596e17a', '00000000-0000-0000-0000-000000000001', 'mcq', 'When do init containers run?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2c6eb29a-7a96-5c91-a6b5-a57d629fc08e', 'da4dba26-9511-5712-a310-b2a29596e17a', 1, $json${"prompt":"When do init containers run?","multiple":false,"options":[{"id":"a","text":"In parallel with the app containers","is_correct":false},{"id":"b","text":"Before the app containers, one at a time, and each must succeed","is_correct":true},{"id":"c","text":"After the app containers exit","is_correct":false},{"id":"d","text":"Only when the pod is deleted","is_correct":false}],"explanation":"Init containers run sequentially to completion before any app container starts."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('52d4ccb2-d3ea-59b2-86a1-2b5bfd84e9b6', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which restartPolicy should a long-running web server use?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('73d747ad-a053-5c9a-b8c3-6e8236a2556c', '52d4ccb2-d3ea-59b2-86a1-2b5bfd84e9b6', 1, $json${"prompt":"Which restartPolicy should a long-running web server use?","multiple":false,"options":[{"id":"a","text":"Never","is_correct":false},{"id":"b","text":"OnFailure","is_correct":false},{"id":"c","text":"Always","is_correct":true},{"id":"d","text":"OnSuccess","is_correct":false}],"explanation":"A server should always come back if it exits. Always is also the default."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d8660631-ad48-5049-925b-661c84c15cc3', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does `kubectl port-forward pod/web 9000:80` do?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2230f6b2-5d14-5be6-8cb3-4a776724d550', 'd8660631-ad48-5049-925b-661c84c15cc3', 1, $json${"prompt":"What does `kubectl port-forward pod/web 9000:80` do?","multiple":false,"options":[{"id":"a","text":"Changes the pod's container port to 9000","is_correct":false},{"id":"b","text":"Opens port 9000 on your machine and tunnels it to port 80 of the pod","is_correct":true},{"id":"c","text":"Creates a Service on port 9000","is_correct":false},{"id":"d","text":"Opens port 9000 on every node","is_correct":false}],"explanation":"port-forward is a temporary tunnel for testing. It creates no Kubernetes object."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('5e2d8ed2-43f0-5529-b423-1c1399dde5df', '00000000-0000-0000-0000-000000000001', 'Quiz: Pods', 'k8s-pod-fundamentals-quiz', 'Quiz covering Pods.', 'mcq', 'published', 'module', 'f9a32647-aa50-5e64-beaf-e8af561b8c06', 15, 70, 5, 8, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '5e2d8ed2-43f0-5529-b423-1c1399dde5df' AND question_id NOT IN ('ed5daec9-cbbf-522a-82dc-99453e20dd44', 'a9efe830-6e2c-5102-8b10-4bbeae811655', 'dd94a27e-2662-562a-9a21-dfd675dc4585', '6f028f35-5362-57c2-8196-d0ceb24978b9', '2597e234-622b-557c-8553-b187981d0ea5', 'da4dba26-9511-5712-a310-b2a29596e17a', '52d4ccb2-d3ea-59b2-86a1-2b5bfd84e9b6', 'd8660631-ad48-5049-925b-661c84c15cc3');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('99374a14-302e-514d-8603-54c5b697d9bf', '5e2d8ed2-43f0-5529-b423-1c1399dde5df', 'ed5daec9-cbbf-522a-82dc-99453e20dd44', 'dd355da9-cdb5-5eea-ac7d-9aca920d93c9', 0, 1),
('358ba2f1-beaf-5b72-9110-0b935e6edbb0', '5e2d8ed2-43f0-5529-b423-1c1399dde5df', 'a9efe830-6e2c-5102-8b10-4bbeae811655', '84a4c890-2e0d-561c-bd7c-555968d87a4f', 1, 1),
('98ab90a1-dead-5b34-ad46-319d526dfd0a', '5e2d8ed2-43f0-5529-b423-1c1399dde5df', 'dd94a27e-2662-562a-9a21-dfd675dc4585', 'f6b76fdc-0f6e-59b8-a94f-d4f7e60a452c', 2, 1),
('77628c63-2d96-557b-aeb9-9e57c7bb0ec9', '5e2d8ed2-43f0-5529-b423-1c1399dde5df', '6f028f35-5362-57c2-8196-d0ceb24978b9', '1b7a8394-a794-5c04-9df6-f4ee049e5a91', 3, 1),
('47ce488f-9121-5841-a376-300a118b80d1', '5e2d8ed2-43f0-5529-b423-1c1399dde5df', '2597e234-622b-557c-8553-b187981d0ea5', '16c40eb0-56cf-5a4b-bf56-05686a43ff65', 4, 1),
('c58a1460-f985-5408-bde2-d63e926f1106', '5e2d8ed2-43f0-5529-b423-1c1399dde5df', 'da4dba26-9511-5712-a310-b2a29596e17a', '2c6eb29a-7a96-5c91-a6b5-a57d629fc08e', 5, 1),
('af9ffebe-0655-5440-99ca-12025a77a2f9', '5e2d8ed2-43f0-5529-b423-1c1399dde5df', '52d4ccb2-d3ea-59b2-86a1-2b5bfd84e9b6', '73d747ad-a053-5c9a-b8c3-6e8236a2556c', 6, 1),
('86194555-3384-5b29-ab3d-a3774664715b', '5e2d8ed2-43f0-5529-b423-1c1399dde5df', 'd8660631-ad48-5049-925b-661c84c15cc3', '2230f6b2-5d14-5be6-8cb3-4a776724d550', 7, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('f9a32647-aa50-5e64-beaf-e8af561b8c06', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '375a87e0-e417-5b1c-8bc5-3852ed089e52', 'Quiz: Pods', 'assessment', 2, 10, '5e2d8ed2-43f0-5529-b423-1c1399dde5df')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Deployments & Workload Controllers
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('c70cffde-a094-57b7-b0b9-8bbbaa0578e0', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Deployments & Workload Controllers', 3)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('66141cf6-373d-5e3a-a4f6-ebaa45838fba', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Deployments: Scaling, Self-Healing and Rolling Updates', 'notes', 0, $md$In the last section you saw that a bare pod is gone for good when it dies. A **Deployment** fixes that. You tell it "run N copies of this pod", and it keeps exactly N running, replaces broken ones, and updates them to new versions without downtime. Most stateless apps (web servers, APIs) run as Deployments.

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
$md$, 50, $json$[{"id":"k8s-deploy-layers-q1","type":"mcq","correct":"b"},{"id":"k8s-deploy-yaml-q1","type":"mcq","correct":"b"},{"id":"k8s-deploy-scale-q1","type":"mcq","correct":"b"},{"id":"k8s-deploy-strategy-q1","type":"mcq","correct":"a"},{"id":"k8s-deploy-strategy-q2","type":"mcq","correct":"b"},{"id":"k8s-deploy-rollout-q1","type":"mcq","correct":"a"},{"id":"k8s-deploy-rollback-q1","type":"mcq","correct":"b"},{"id":"k8s-deploy-rollback-q2","type":"mcq","correct":"b"},{"id":"k8s-deploy-int-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('ca5caa6c-ca1c-5408-8c6d-f0028b82abac', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Lab: Deployments, Scaling and Rollbacks', 'lab', 1, 30)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('8a39f024-139f-52e2-ba2a-2c6c4c5cc370', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'ca5caa6c-ca1c-5408-8c6d-f0028b82abac', 'module', 'Lab: Deployments, Scaling and Rollbacks', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/deployment1.yaml <<'MFEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: firstdeployment
  labels:
    team: development
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80

MFEOF
chmod 666 /home/labuser/work/deployment1.yaml
cat > /home/labuser/work/recreate-deployment.yaml <<'MFEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rcdeployment
  labels:
    team: development
spec:
  replicas: 5
  selector:
    matchLabels:
      app: recreate
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: recreate
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80

MFEOF
chmod 666 /home/labuser/work/recreate-deployment.yaml
cat > /home/labuser/work/rolling-deployment.yaml <<'MFEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolldeployment
  labels:
    team: development
spec:
  replicas: 10
  selector:
    matchLabels:
      app: rolling
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 2
      maxSurge: 2
  template:
    metadata:
      labels:
        app: rolling
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80

MFEOF
chmod 666 /home/labuser/work/rolling-deployment.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 60, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '8d979332-41b9-5f85-9a37-e15f4ff97ee9' AND id NOT IN ('31bb207c-d890-52e3-9140-c64a2ea42c14', '38f9d731-d10a-57d4-9b94-d31797e53457', 'e78da87e-2f38-5bc1-a5e3-ca26aa50eea2', '92369458-3e6b-57b4-ae61-e55cab32afba', '18a007dd-519a-5ea9-a655-c144b8e1d2ee', '82e25035-3b27-57db-a47e-4a088d9c68ec');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '8d979332-41b9-5f85-9a37-e15f4ff97ee9';
DELETE FROM lab_tasks WHERE lab_id = '8a39f024-139f-52e2-ba2a-2c6c4c5cc370' AND id NOT IN ('52cb3ef5-079c-578d-977e-a70de95582f1', '6b7d707d-d3f3-5de0-a2b4-044bac4dd169', '99af70a6-4bb2-5391-8051-f4745a08d4f9', '290cf43b-259f-5243-9df9-82784e361822', 'ca0df642-b6ec-5669-a908-c9c0ad20e66c', 'd6b461f9-2669-58fb-b3bd-b2c9c780f174');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '8a39f024-139f-52e2-ba2a-2c6c4c5cc370';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('52cb3ef5-079c-578d-977e-a70de95582f1', '8a39f024-139f-52e2-ba2a-2c6c4c5cc370', 1, 'Create a Deployment', $md$Apply `deployment1.yaml`. Check that `kubectl get deployments` shows `3/3` ready and look at the ReplicaSet it created with `kubectl get rs`.$md$, $script$#!/bin/bash
test "$(kubectl get deployment firstdeployment -o jsonpath='{.status.readyReplicas}')" = "3"
$script$, '`kubectl apply -f deployment1.yaml`', 'The Deployment created a ReplicaSet, and the ReplicaSet created 3 pods with the `app=frontend` label.', 10, false, true),
('6b7d707d-d3f3-5de0-a2b4-044bac4dd169', '8a39f024-139f-52e2-ba2a-2c6c4c5cc370', 2, 'Watch a Deployment heal itself', $md$Write down the pod names (`kubectl get pods -l app=frontend`), then delete **all** of them with one command:
`kubectl delete pods -l app=frontend`. Run `kubectl get pods -l app=frontend` again and compare the names.
$md$, $script$#!/bin/bash
# every current frontend pod must be younger than the deployment by a few seconds (i.e. replacements)
D=$(date -d "$(kubectl get deployment firstdeployment -o jsonpath='{.metadata.creationTimestamp}')" +%s)
N=$(kubectl get pods -l app=frontend -o jsonpath='{range .items[*]}{.metadata.creationTimestamp}{"\n"}{end}' | while read t; do [ $(( $(date -d "$t" +%s) - D )) -ge 3 ] && echo new; done | wc -l)
test "$N" -ge 3
$script$, 'Deleting by label selector (`-l`) removes every matching pod at once.', 'The ReplicaSet saw 0 of 3 pods and immediately created 3 new ones with new names. This is the reconcile loop at work.', 10, false, true),
('99af70a6-4bb2-5391-8051-f4745a08d4f9', '8a39f024-139f-52e2-ba2a-2c6c4c5cc370', 3, 'Scale up', $md$Scale `firstdeployment` to 5 replicas.$md$, $script$#!/bin/bash
test "$(kubectl get deployment firstdeployment -o jsonpath='{.spec.replicas}/{.status.readyReplicas}')" = "5/5"
$script$, '`kubectl scale deployment <name> --replicas=<n>`', 'Scaling only changes `spec.replicas`. The ReplicaSet then creates the missing pods.', 10, false, true),
('290cf43b-259f-5243-9df9-82784e361822', '8a39f024-139f-52e2-ba2a-2c6c4c5cc370', 4, 'Roll out a new image', $md$Apply `rolling-deployment.yaml` (10 replicas, maxSurge 2, maxUnavailable 2). When it is ready, change the image of its `nginx` container to `httpd:2.4` with `kubectl set image`. Watch it with `kubectl rollout status deployment/rolldeployment` and `kubectl get rs`.
$md$, $script$#!/bin/bash
test "$(kubectl get deployment rolldeployment -o jsonpath='{.spec.template.spec.containers[0].image}')" = "httpd:2.4" || exit 1
test "$(kubectl get rs -l app=rolling --no-headers | wc -l)" -ge 2 || exit 1
test "$(kubectl get deployment rolldeployment -o jsonpath='{.status.updatedReplicas}')" = "10"
$script$, '`kubectl set image deployment/rolldeployment nginx=httpd:2.4`', 'The new image created a second ReplicaSet. The Deployment moved pods over at most 2 at a time. The old ReplicaSet stays at 0 replicas so you can roll back.', 15, false, true),
('ca0df642-b6ec-5669-a908-c9c0ad20e66c', '8a39f024-139f-52e2-ba2a-2c6c4c5cc370', 5, 'Roll back', $md$The new version is "broken". Look at `kubectl rollout history deployment/rolldeployment`, then roll back to the previous revision.$md$, $script$#!/bin/bash
test "$(kubectl get deployment rolldeployment -o jsonpath='{.spec.template.spec.containers[0].image}')" = "nginx:1.27" || exit 1
kubectl rollout history deployment/rolldeployment | grep -q '^3 '
$script$, '`kubectl rollout undo deployment/<name>`', 'The rollback reused the old ReplicaSet''s template. It shows up as a new revision (3) in the history, because a rollback is just another rollout.', 15, false, true),
('d6b461f9-2669-58fb-b3bd-b2c9c780f174', '8a39f024-139f-52e2-ba2a-2c6c4c5cc370', 6, 'Use the Recreate strategy', $md$Apply `recreate-deployment.yaml`, then change its image to `httpd:2.4`. Run `kubectl get pods -l app=recreate -w` right after the change to see all old pods terminate before new ones start (Ctrl+C to stop watching).$md$, $script$#!/bin/bash
kubectl get deployment rcdeployment -o jsonpath='{.spec.strategy.type} {.spec.template.spec.containers[0].image}' | grep -qx 'Recreate httpd:2.4'
$script$, 'Same `kubectl set image` command, but with the deployment `rcdeployment`.', 'With Recreate there is a gap where no pods run. That is why RollingUpdate is the default.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('8d979332-41b9-5f85-9a37-e15f4ff97ee9', '8a39f024-139f-52e2-ba2a-2c6c4c5cc370', 1, $json$[{"id":"52cb3ef5-079c-578d-977e-a70de95582f1","lab_id":"8a39f024-139f-52e2-ba2a-2c6c4c5cc370","position":1,"title":"Create a Deployment","description":"Apply `deployment1.yaml`. Check that `kubectl get deployments` shows `3/3` ready and look at the ReplicaSet it created with `kubectl get rs`.","verification_script":"#!/bin/bash\ntest \"$(kubectl get deployment firstdeployment -o jsonpath='{.status.readyReplicas}')\" = \"3\"\n","hint_context":"`kubectl apply -f deployment1.yaml`","explanation_context":"The Deployment created a ReplicaSet, and the ReplicaSet created 3 pods with the `app=frontend` label.","points":10,"is_optional":false,"is_stateful":true},{"id":"6b7d707d-d3f3-5de0-a2b4-044bac4dd169","lab_id":"8a39f024-139f-52e2-ba2a-2c6c4c5cc370","position":2,"title":"Watch a Deployment heal itself","description":"Write down the pod names (`kubectl get pods -l app=frontend`), then delete **all** of them with one command:\n`kubectl delete pods -l app=frontend`. Run `kubectl get pods -l app=frontend` again and compare the names.\n","verification_script":"#!/bin/bash\n# every current frontend pod must be younger than the deployment by a few seconds (i.e. replacements)\nD=$(date -d \"$(kubectl get deployment firstdeployment -o jsonpath='{.metadata.creationTimestamp}')\" +%s)\nN=$(kubectl get pods -l app=frontend -o jsonpath='{range .items[*]}{.metadata.creationTimestamp}{\"\\n\"}{end}' | while read t; do [ $(( $(date -d \"$t\" +%s) - D )) -ge 3 ] \u0026\u0026 echo new; done | wc -l)\ntest \"$N\" -ge 3\n","hint_context":"Deleting by label selector (`-l`) removes every matching pod at once.","explanation_context":"The ReplicaSet saw 0 of 3 pods and immediately created 3 new ones with new names. This is the reconcile loop at work.","points":10,"is_optional":false,"is_stateful":true},{"id":"99af70a6-4bb2-5391-8051-f4745a08d4f9","lab_id":"8a39f024-139f-52e2-ba2a-2c6c4c5cc370","position":3,"title":"Scale up","description":"Scale `firstdeployment` to 5 replicas.","verification_script":"#!/bin/bash\ntest \"$(kubectl get deployment firstdeployment -o jsonpath='{.spec.replicas}/{.status.readyReplicas}')\" = \"5/5\"\n","hint_context":"`kubectl scale deployment \u003cname\u003e --replicas=\u003cn\u003e`","explanation_context":"Scaling only changes `spec.replicas`. The ReplicaSet then creates the missing pods.","points":10,"is_optional":false,"is_stateful":true},{"id":"290cf43b-259f-5243-9df9-82784e361822","lab_id":"8a39f024-139f-52e2-ba2a-2c6c4c5cc370","position":4,"title":"Roll out a new image","description":"Apply `rolling-deployment.yaml` (10 replicas, maxSurge 2, maxUnavailable 2). When it is ready, change the image of its `nginx` container to `httpd:2.4` with `kubectl set image`. Watch it with `kubectl rollout status deployment/rolldeployment` and `kubectl get rs`.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get deployment rolldeployment -o jsonpath='{.spec.template.spec.containers[0].image}')\" = \"httpd:2.4\" || exit 1\ntest \"$(kubectl get rs -l app=rolling --no-headers | wc -l)\" -ge 2 || exit 1\ntest \"$(kubectl get deployment rolldeployment -o jsonpath='{.status.updatedReplicas}')\" = \"10\"\n","hint_context":"`kubectl set image deployment/rolldeployment nginx=httpd:2.4`","explanation_context":"The new image created a second ReplicaSet. The Deployment moved pods over at most 2 at a time. The old ReplicaSet stays at 0 replicas so you can roll back.","points":15,"is_optional":false,"is_stateful":true},{"id":"ca0df642-b6ec-5669-a908-c9c0ad20e66c","lab_id":"8a39f024-139f-52e2-ba2a-2c6c4c5cc370","position":5,"title":"Roll back","description":"The new version is \"broken\". Look at `kubectl rollout history deployment/rolldeployment`, then roll back to the previous revision.","verification_script":"#!/bin/bash\ntest \"$(kubectl get deployment rolldeployment -o jsonpath='{.spec.template.spec.containers[0].image}')\" = \"nginx:1.27\" || exit 1\nkubectl rollout history deployment/rolldeployment | grep -q '^3 '\n","hint_context":"`kubectl rollout undo deployment/\u003cname\u003e`","explanation_context":"The rollback reused the old ReplicaSet's template. It shows up as a new revision (3) in the history, because a rollback is just another rollout.","points":15,"is_optional":false,"is_stateful":true},{"id":"d6b461f9-2669-58fb-b3bd-b2c9c780f174","lab_id":"8a39f024-139f-52e2-ba2a-2c6c4c5cc370","position":6,"title":"Use the Recreate strategy","description":"Apply `recreate-deployment.yaml`, then change its image to `httpd:2.4`. Run `kubectl get pods -l app=recreate -w` right after the change to see all old pods terminate before new ones start (Ctrl+C to stop watching).","verification_script":"#!/bin/bash\nkubectl get deployment rcdeployment -o jsonpath='{.spec.strategy.type} {.spec.template.spec.containers[0].image}' | grep -qx 'Recreate httpd:2.4'\n","hint_context":"Same `kubectl set image` command, but with the deployment `rcdeployment`.","explanation_context":"With Recreate there is a gap where no pods run. That is why RollingUpdate is the default.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('31bb207c-d890-52e3-9140-c64a2ea42c14', '8d979332-41b9-5f85-9a37-e15f4ff97ee9', '52cb3ef5-079c-578d-977e-a70de95582f1', 1, 'Create a Deployment', $md$Apply `deployment1.yaml`. Check that `kubectl get deployments` shows `3/3` ready and look at the ReplicaSet it created with `kubectl get rs`.$md$, $script$#!/bin/bash
test "$(kubectl get deployment firstdeployment -o jsonpath='{.status.readyReplicas}')" = "3"
$script$, '`kubectl apply -f deployment1.yaml`', 'The Deployment created a ReplicaSet, and the ReplicaSet created 3 pods with the `app=frontend` label.', 10, false, true),
('38f9d731-d10a-57d4-9b94-d31797e53457', '8d979332-41b9-5f85-9a37-e15f4ff97ee9', '6b7d707d-d3f3-5de0-a2b4-044bac4dd169', 2, 'Watch a Deployment heal itself', $md$Write down the pod names (`kubectl get pods -l app=frontend`), then delete **all** of them with one command:
`kubectl delete pods -l app=frontend`. Run `kubectl get pods -l app=frontend` again and compare the names.
$md$, $script$#!/bin/bash
# every current frontend pod must be younger than the deployment by a few seconds (i.e. replacements)
D=$(date -d "$(kubectl get deployment firstdeployment -o jsonpath='{.metadata.creationTimestamp}')" +%s)
N=$(kubectl get pods -l app=frontend -o jsonpath='{range .items[*]}{.metadata.creationTimestamp}{"\n"}{end}' | while read t; do [ $(( $(date -d "$t" +%s) - D )) -ge 3 ] && echo new; done | wc -l)
test "$N" -ge 3
$script$, 'Deleting by label selector (`-l`) removes every matching pod at once.', 'The ReplicaSet saw 0 of 3 pods and immediately created 3 new ones with new names. This is the reconcile loop at work.', 10, false, true),
('e78da87e-2f38-5bc1-a5e3-ca26aa50eea2', '8d979332-41b9-5f85-9a37-e15f4ff97ee9', '99af70a6-4bb2-5391-8051-f4745a08d4f9', 3, 'Scale up', $md$Scale `firstdeployment` to 5 replicas.$md$, $script$#!/bin/bash
test "$(kubectl get deployment firstdeployment -o jsonpath='{.spec.replicas}/{.status.readyReplicas}')" = "5/5"
$script$, '`kubectl scale deployment <name> --replicas=<n>`', 'Scaling only changes `spec.replicas`. The ReplicaSet then creates the missing pods.', 10, false, true),
('92369458-3e6b-57b4-ae61-e55cab32afba', '8d979332-41b9-5f85-9a37-e15f4ff97ee9', '290cf43b-259f-5243-9df9-82784e361822', 4, 'Roll out a new image', $md$Apply `rolling-deployment.yaml` (10 replicas, maxSurge 2, maxUnavailable 2). When it is ready, change the image of its `nginx` container to `httpd:2.4` with `kubectl set image`. Watch it with `kubectl rollout status deployment/rolldeployment` and `kubectl get rs`.
$md$, $script$#!/bin/bash
test "$(kubectl get deployment rolldeployment -o jsonpath='{.spec.template.spec.containers[0].image}')" = "httpd:2.4" || exit 1
test "$(kubectl get rs -l app=rolling --no-headers | wc -l)" -ge 2 || exit 1
test "$(kubectl get deployment rolldeployment -o jsonpath='{.status.updatedReplicas}')" = "10"
$script$, '`kubectl set image deployment/rolldeployment nginx=httpd:2.4`', 'The new image created a second ReplicaSet. The Deployment moved pods over at most 2 at a time. The old ReplicaSet stays at 0 replicas so you can roll back.', 15, false, true),
('18a007dd-519a-5ea9-a655-c144b8e1d2ee', '8d979332-41b9-5f85-9a37-e15f4ff97ee9', 'ca0df642-b6ec-5669-a908-c9c0ad20e66c', 5, 'Roll back', $md$The new version is "broken". Look at `kubectl rollout history deployment/rolldeployment`, then roll back to the previous revision.$md$, $script$#!/bin/bash
test "$(kubectl get deployment rolldeployment -o jsonpath='{.spec.template.spec.containers[0].image}')" = "nginx:1.27" || exit 1
kubectl rollout history deployment/rolldeployment | grep -q '^3 '
$script$, '`kubectl rollout undo deployment/<name>`', 'The rollback reused the old ReplicaSet''s template. It shows up as a new revision (3) in the history, because a rollback is just another rollout.', 15, false, true),
('82e25035-3b27-57db-a47e-4a088d9c68ec', '8d979332-41b9-5f85-9a37-e15f4ff97ee9', 'd6b461f9-2669-58fb-b3bd-b2c9c780f174', 6, 'Use the Recreate strategy', $md$Apply `recreate-deployment.yaml`, then change its image to `httpd:2.4`. Run `kubectl get pods -l app=recreate -w` right after the change to see all old pods terminate before new ones start (Ctrl+C to stop watching).$md$, $script$#!/bin/bash
kubectl get deployment rcdeployment -o jsonpath='{.spec.strategy.type} {.spec.template.spec.containers[0].image}' | grep -qx 'Recreate httpd:2.4'
$script$, 'Same `kubectl set image` command, but with the deployment `rcdeployment`.', 'With Recreate there is a gap where no pods run. That is why RollingUpdate is the default.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '8d979332-41b9-5f85-9a37-e15f4ff97ee9', updated_at = now()
WHERE id = '8a39f024-139f-52e2-ba2a-2c6c4c5cc370' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('fa6ae011-5484-5ad3-961c-b85aad331271', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'DaemonSets, StatefulSets, Jobs and CronJobs', 'notes', 2, $md$A Deployment is right for stateless apps where every copy is the same and can run anywhere. Some workloads need different rules:

| You need... | Use |
|---|---|
| N identical, interchangeable copies (web app, API) | **Deployment** |
| One copy on **every node** (log collector, monitoring agent) | **DaemonSet** |
| Copies with a **stable name and their own disk** (database, Kafka, ZooKeeper) | **StatefulSet** |
| Run a task **to completion** once (batch job, migration) | **Job** |
| Run a task **on a schedule** (nightly backup, hourly report) | **CronJob** |

All of them use the same pod template you already know. Only the controller's behavior changes.

## DaemonSet: one pod per node

Like a housing society that posts exactly one security guard at every gate, not three guards at one gate and none at the others, a **DaemonSet** runs exactly one copy of a pod on every node (or every node that matches a selector). When a node joins the cluster, the DaemonSet adds a pod there automatically. When a node is removed, that pod goes too. There is no `replicas` field: the number of nodes decides the count.

Typical uses are node-level agents: log collectors (Fluentd, Fluent Bit), metrics exporters (node-exporter), network plugins (Calico, Cilium) and storage drivers.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: logdaemonset
  labels:
    app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:                          # also run on control-plane nodes, which are tainted
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
      volumes:
      - name: varlog
        hostPath:                           # a folder on the node itself
          path: /var/log
```

Two things to notice:

- **`hostPath`** mounts a directory from the node's own disk. A log collector needs it to read the logs of every other pod on that node. hostPath is powerful and risky, so only use it for node agents like this one.
- The **toleration** lets the pod run on control-plane nodes, which normally refuse regular pods (taints and tolerations are explained in the scheduling section). Older clusters used the key `node-role.kubernetes.io/master`.

```bash
kubectl apply -f daemonset.yaml
kubectl get daemonset          # DESIRED = number of eligible nodes
kubectl get pods -o wide       # one pod per node
```

Delete one of its pods and the DaemonSet creates a replacement on the same node.

```knowledge-check
{ "questions": [
  { "id": "k8s-ctrl-ds-q1", "type": "mcq",
    "prompt": "A cluster has 4 nodes and a DaemonSet with no node selector. A 5th node joins. What happens?",
    "options": [
      {"id": "a", "text": "Nothing until you raise replicas to 5"},
      {"id": "b", "text": "The DaemonSet automatically starts one pod on the new node"},
      {"id": "c", "text": "One pod moves from an old node to the new one"},
      {"id": "d", "text": "All 4 pods restart"}
    ],
    "correct": "b",
    "explanation": "A DaemonSet has no replicas field. It keeps one pod on every eligible node, including nodes that join later." },
  { "id": "k8s-ctrl-ds-q2", "type": "mcq",
    "prompt": "Which workload is the best fit for a log collector that must read log files from every node?",
    "options": [
      {"id": "a", "text": "Deployment with 3 replicas"},
      {"id": "b", "text": "DaemonSet"},
      {"id": "c", "text": "Job"},
      {"id": "d", "text": "StatefulSet"}
    ],
    "correct": "b",
    "explanation": "A node agent must run once per node, which is exactly what a DaemonSet guarantees." }
] }
```

## StatefulSet: stable names and their own storage

Think of numbered lockers at a gym: locker 7 is always locker 7, and whoever is assigned to it keeps using the same locker with the same contents inside, even if it is a different day. Pods of a Deployment are interchangeable: random names, shared storage (if any), started in any order. A database cluster cannot work that way. Each member needs to be known by name and keep **its own** data. A **StatefulSet** gives each pod:

- **A stable, ordered name**: `web-0`, `web-1`, `web-2`. If `web-1` is deleted, the new pod is again called `web-1`.
- **A stable network name** through a **headless Service**: `web-0.nginx.default.svc.cluster.local`.
- **Its own PersistentVolumeClaim** from `volumeClaimTemplates`. `web-0` always gets back the same disk (`www-web-0`), even when rescheduled to another node.
- **Ordered start and stop**: `web-0` must be ready before `web-1` starts. Scaling down removes the highest number first.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  clusterIP: None            # "headless": no virtual IP, DNS returns the pod IPs directly
  selector:
    app: nginx
  ports:
  - port: 80
    name: web
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: nginx         # the headless Service that gives pods their DNS names
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:      # one PVC per pod: www-web-0, www-web-1, www-web-2
  - metadata:
      name: www
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 512Mi
```

What to remember:

- **Deleting or scaling down a StatefulSet does not delete its PVCs.** Your data is safe by default. Delete the PVCs yourself when you really want the data gone.
- A **headless Service** (`clusterIP: None`) has no load-balanced IP. A DNS lookup of `nginx` returns all pod IPs, and `web-0.nginx` returns exactly that pod's IP. Clients that must talk to one specific member (for example, "write to the primary") use these names.
- A StatefulSet gives you identity and storage. It does **not** set up replication between members. The database itself (or an operator) must do that. For production databases, a managed service or an operator (for example CloudNativePG for PostgreSQL) is usually a better choice than writing one yourself.

```knowledge-check
{ "questions": [
  { "id": "k8s-ctrl-sts-q1", "type": "mcq",
    "prompt": "StatefulSet `db` has 3 replicas. Pod db-1 is deleted. What is the replacement pod called, and which disk does it get?",
    "options": [
      {"id": "a", "text": "A random name and a new empty disk"},
      {"id": "b", "text": "db-1, and it reattaches db-1's existing PVC"},
      {"id": "c", "text": "db-3, and it shares db-0's disk"},
      {"id": "d", "text": "db-1, with a new empty disk"}
    ],
    "correct": "b",
    "explanation": "StatefulSet pods have stable identities. The replacement keeps the name db-1 and binds to the same PVC it used before." },
  { "id": "k8s-ctrl-sts-q2", "type": "mcq",
    "prompt": "You scale a StatefulSet from 3 to 1 replica. What happens to the PVCs of the removed pods?",
    "options": [
      {"id": "a", "text": "They are deleted immediately"},
      {"id": "b", "text": "They are kept, so the data is still there if you scale back up"},
      {"id": "c", "text": "They are merged into the remaining pod's PVC"},
      {"id": "d", "text": "They are converted to emptyDir volumes"}
    ],
    "correct": "b",
    "explanation": "By default, StatefulSet PVCs outlive the pods. Scaling back up reattaches them. You delete them manually when the data is no longer needed." }
] }
```

## Job: run to completion

A **Job** runs pods until a task finishes successfully, and then stops. It does not restart finished work. Use it for batch processing, data imports or database migrations.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  completions: 10              # 10 successful pod runs are needed in total
  parallelism: 2               # run at most 2 pods at the same time
  backoffLimit: 5              # after 5 failed attempts, mark the Job as failed
  activeDeadlineSeconds: 100   # fail the Job if it runs longer than 100 s overall
  ttlSecondsAfterFinished: 600 # delete the Job and its pods 10 minutes after it finishes
  template:
    spec:
      restartPolicy: Never     # Jobs must use Never or OnFailure
      containers:
      - name: pi
        image: perl:5.40
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
```

```bash
kubectl apply -f job.yaml
kubectl get jobs -w            # COMPLETIONS goes 0/10 → 10/10
kubectl get pods               # finished pods show Completed
kubectl logs job/pi            # output of one of its pods
```

Finished pods are kept (in `Completed` state) so you can read their logs. `ttlSecondsAfterFinished` cleans them up automatically.

```knowledge-check
{ "questions": [
  { "id": "k8s-ctrl-job-q1", "type": "mcq",
    "prompt": "A Job has completions: 6 and parallelism: 3. How does it run?",
    "options": [
      {"id": "a", "text": "3 pods run forever"},
      {"id": "b", "text": "Up to 3 pods run at a time until 6 have succeeded"},
      {"id": "c", "text": "6 pods start at once, 3 of them are later killed"},
      {"id": "d", "text": "It runs 3 times, each time with 6 pods"}
    ],
    "correct": "b",
    "explanation": "parallelism caps how many pods run at the same time; completions is the number of successful runs needed." },
  { "id": "k8s-ctrl-job-q2", "type": "mcq",
    "prompt": "Why can a Job's pod template not use restartPolicy: Always?",
    "options": [
      {"id": "a", "text": "Because a Job must be able to finish; Always would restart the container even after success"},
      {"id": "b", "text": "Because Jobs have no containers"},
      {"id": "c", "text": "Because Always is only for DaemonSets"},
      {"id": "d", "text": "It can; Always is the default for Jobs"}
    ],
    "correct": "a",
    "explanation": "Jobs are meant to end. Only Never and OnFailure are allowed, so a successful container is not started again." }
] }
```

## CronJob: run a Job on a schedule

A **CronJob** creates a new Job at times you choose, using the standard cron format:

```
┌───────── minute (0-59)
│ ┌─────── hour (0-23)
│ │ ┌───── day of month (1-31)
│ │ │ ┌─── month (1-12)
│ │ │ │ ┌─ day of week (0-6, Sunday = 0)
│ │ │ │ │
* * * * *
```

Examples: `*/5 * * * *` every 5 minutes, `0 2 * * *` every day at 02:00, `0 9 * * 1` every Monday at 09:00. Schedules use the controller's time zone (usually UTC) unless you set `spec.timeZone`, for example `timeZone: "Asia/Kolkata"`.

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"          # every minute
  concurrencyPolicy: Forbid        # skip a run if the previous one is still running
  successfulJobsHistoryLimit: 3    # keep the last 3 finished Jobs
  failedJobsHistoryLimit: 1
  jobTemplate:                     # a normal Job spec
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: hello
            image: busybox:1.36
            command: ["/bin/sh", "-c", "date; echo Hello from the Kubernetes cluster"]
```

`concurrencyPolicy` decides what happens when a run is due but the previous one has not finished: `Allow` (default, run both), `Forbid` (skip the new run) or `Replace` (stop the old one, start the new one).

```bash
kubectl get cronjobs
kubectl get jobs -w                                   # a new Job appears every minute
kubectl create job manual-run --from=cronjob/hello    # run it right now, without waiting
kubectl patch cronjob hello -p '{"spec":{"suspend":true}}'   # pause the schedule
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ctrl-cron-q1", "type": "mcq",
    "prompt": "Which schedule runs a CronJob every day at 02:30?",
    "options": [
      {"id": "a", "text": "2 30 * * *"},
      {"id": "b", "text": "30 2 * * *"},
      {"id": "c", "text": "*/30 2 * * *"},
      {"id": "d", "text": "30 * 2 * *"}
    ],
    "correct": "b",
    "explanation": "Fields are minute, hour, day of month, month, day of week. Minute 30, hour 2, every day." },
  { "id": "k8s-ctrl-cron-q2", "type": "mcq",
    "prompt": "A backup CronJob sometimes runs longer than its interval, and two backups must never run at once. Which setting prevents that?",
    "options": [
      {"id": "a", "text": "concurrencyPolicy: Forbid"},
      {"id": "b", "text": "parallelism: 1"},
      {"id": "c", "text": "suspend: true"},
      {"id": "d", "text": "successfulJobsHistoryLimit: 1"}
    ],
    "correct": "a",
    "explanation": "Forbid skips a scheduled run while the previous Job is still active." }
] }
```

## Interview questions and real-world scenarios

**Q: When would you choose a StatefulSet over a Deployment?**
When pods need a stable identity, stable network names, their own persistent disk, or ordered startup: databases, Kafka, ZooKeeper, Elasticsearch. Mention that many teams prefer managed databases or operators instead.

**Q: What is a headless Service and why do StatefulSets need one?**
`clusterIP: None`. DNS returns pod IPs directly, and each pod gets a name like `web-0.nginx`. That lets clients address one specific member (for example the primary).

**Q: How is a DaemonSet scheduled on tainted control-plane nodes?**
By adding a toleration for the control-plane taint. DaemonSet pods also automatically tolerate node-condition taints like not-ready, so node agents keep running on unhealthy nodes.

**Q: A Job keeps failing. What limits how often it retries?**
`backoffLimit` (retries, with growing delay) and `activeDeadlineSeconds` (total time). With `restartPolicy: OnFailure` the container restarts in place; with `Never` new pods are created.

**Q: What happens if a CronJob run takes longer than its interval?**
It depends on `concurrencyPolicy`: Allow runs them in parallel, Forbid skips the new run, Replace stops the old run. Also mention `startingDeadlineSeconds` for runs missed during downtime.

**Real-world scenario: a nightly backup CronJob silently stopped running.**
Check `kubectl get cronjob` (SUSPEND?, LAST SCHEDULE), the Jobs it created, and their pod logs. Common causes: suspended, failing pods hidden by a low `failedJobsHistoryLimit`, or overlapping runs blocked by Forbid. Add an alert on "last successful run older than 26 hours".

**Real-world scenario: finished Job pods fill the namespace.**
Set `ttlSecondsAfterFinished` on Jobs, and history limits on CronJobs.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-ctrl-int-q1",
      "type": "mcq",
      "prompt": "Why is a Deployment a poor fit for a 3-node PostgreSQL cluster?",
      "options": [
        {
          "id": "a",
          "text": "Deployments cannot run PostgreSQL images"
        },
        {
          "id": "b",
          "text": "Deployment pods are interchangeable with random names and no per-pod disk, but each database member needs its own stable identity and storage"
        },
        {
          "id": "c",
          "text": "Deployments cannot have more than 2 replicas"
        },
        {
          "id": "d",
          "text": "Deployments do not support environment variables"
        }
      ],
      "correct": "b",
      "explanation": "StatefulSets (or an operator built on them) provide stable names and per-pod PVCs."
    }
  ]
}
```
$md$, 50, $json$[{"id":"k8s-ctrl-ds-q1","type":"mcq","correct":"b"},{"id":"k8s-ctrl-ds-q2","type":"mcq","correct":"b"},{"id":"k8s-ctrl-sts-q1","type":"mcq","correct":"b"},{"id":"k8s-ctrl-sts-q2","type":"mcq","correct":"b"},{"id":"k8s-ctrl-job-q1","type":"mcq","correct":"b"},{"id":"k8s-ctrl-job-q2","type":"mcq","correct":"a"},{"id":"k8s-ctrl-cron-q1","type":"mcq","correct":"b"},{"id":"k8s-ctrl-cron-q2","type":"mcq","correct":"a"},{"id":"k8s-ctrl-int-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('18597e54-2b4f-598f-9f1f-86857c5162e6', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Lab: DaemonSet', 'lab', 3, 20)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('bb0913dc-02d9-580b-95e0-0023ff31b9ea', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '18597e54-2b4f-598f-9f1f-86857c5162e6', 'module', 'Lab: DaemonSet', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/daemonset.yaml <<'MFEOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: logdaemonset
  labels:
    app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers

MFEOF
chmod 666 /home/labuser/work/daemonset.yaml
cat > /home/labuser/work/node2.yaml <<'MFEOF'
# A simulated worker node. In a real cluster a node joins with `kubeadm join`;
# here we register a fake one so you can watch the DaemonSet react.
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

MFEOF
chmod 666 /home/labuser/work/node2.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'e858ff7d-9bf2-5c07-b12b-e0ffb4e9af9f' AND id NOT IN ('27928b62-72dd-50f5-945f-2c8dbc7da8a6', '719d64a9-512e-5a25-ab20-38a9a75ad22c', 'b38c2129-211c-5cbf-9061-32f0fe1696df');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'e858ff7d-9bf2-5c07-b12b-e0ffb4e9af9f';
DELETE FROM lab_tasks WHERE lab_id = 'bb0913dc-02d9-580b-95e0-0023ff31b9ea' AND id NOT IN ('12e46192-0803-53cb-854c-b6e8de646a15', '626905e6-ad51-5ca8-9c63-57348ea490f6', '4a7455b2-4a7f-5783-a0ee-c0891cf83aa9');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'bb0913dc-02d9-580b-95e0-0023ff31b9ea';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('12e46192-0803-53cb-854c-b6e8de646a15', 'bb0913dc-02d9-580b-95e0-0023ff31b9ea', 1, 'Create the DaemonSet', $md$Apply `daemonset.yaml`. Run `kubectl get daemonset` and `kubectl get pods -o wide`. How many pods are there, and on which node?$md$, $script$#!/bin/bash
test "$(kubectl get daemonset logdaemonset -o jsonpath='{.status.numberReady}')" = "1"
$script$, '`kubectl apply -f daemonset.yaml`', 'The cluster has one node, so the DaemonSet runs exactly one pod. There is no replicas field; the number of nodes decides.', 10, false, true),
('626905e6-ad51-5ca8-9c63-57348ea490f6', 'bb0913dc-02d9-580b-95e0-0023ff31b9ea', 2, 'Add a node and watch the DaemonSet follow', $md$Register a second node with `kubectl apply -f node2.yaml`. Wait a few seconds, then check `kubectl get nodes` and `kubectl get pods -o wide` again.$md$, $script$#!/bin/bash
test "$(kubectl get daemonset logdaemonset -o jsonpath='{.status.numberReady}')" = "2" || exit 1
kubectl get pods -l name=fluentd-elasticsearch -o jsonpath='{.items[*].spec.nodeName}' | grep -q node2
$script$, 'Apply the node file, then give the DaemonSet controller a few seconds.', 'As soon as node2 was Ready, the DaemonSet controller created a pod for it. You did not change the DaemonSet at all.', 15, false, true),
('4a7455b2-4a7f-5783-a0ee-c0891cf83aa9', 'bb0913dc-02d9-580b-95e0-0023ff31b9ea', 3, 'Delete a DaemonSet pod', $md$Delete the DaemonSet pod that runs on `node2` and check that a new one is created on the same node.$md$, $script$#!/bin/bash
P=$(kubectl get pods -l name=fluentd-elasticsearch --field-selector spec.nodeName=node2 -o jsonpath='{.items[0].metadata.creationTimestamp}')
N=$(kubectl get node node2 -o jsonpath='{.metadata.creationTimestamp}')
test -n "$P" && [ $(( $(date -d "$P" +%s) - $(date -d "$N" +%s) )) -ge 3 ]
$script$, '`kubectl get pods -o wide` shows the node of each pod; then `kubectl delete pod <name>`.', 'The DaemonSet saw node2 without its pod and created a new one there.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('e858ff7d-9bf2-5c07-b12b-e0ffb4e9af9f', 'bb0913dc-02d9-580b-95e0-0023ff31b9ea', 1, $json$[{"id":"12e46192-0803-53cb-854c-b6e8de646a15","lab_id":"bb0913dc-02d9-580b-95e0-0023ff31b9ea","position":1,"title":"Create the DaemonSet","description":"Apply `daemonset.yaml`. Run `kubectl get daemonset` and `kubectl get pods -o wide`. How many pods are there, and on which node?","verification_script":"#!/bin/bash\ntest \"$(kubectl get daemonset logdaemonset -o jsonpath='{.status.numberReady}')\" = \"1\"\n","hint_context":"`kubectl apply -f daemonset.yaml`","explanation_context":"The cluster has one node, so the DaemonSet runs exactly one pod. There is no replicas field; the number of nodes decides.","points":10,"is_optional":false,"is_stateful":true},{"id":"626905e6-ad51-5ca8-9c63-57348ea490f6","lab_id":"bb0913dc-02d9-580b-95e0-0023ff31b9ea","position":2,"title":"Add a node and watch the DaemonSet follow","description":"Register a second node with `kubectl apply -f node2.yaml`. Wait a few seconds, then check `kubectl get nodes` and `kubectl get pods -o wide` again.","verification_script":"#!/bin/bash\ntest \"$(kubectl get daemonset logdaemonset -o jsonpath='{.status.numberReady}')\" = \"2\" || exit 1\nkubectl get pods -l name=fluentd-elasticsearch -o jsonpath='{.items[*].spec.nodeName}' | grep -q node2\n","hint_context":"Apply the node file, then give the DaemonSet controller a few seconds.","explanation_context":"As soon as node2 was Ready, the DaemonSet controller created a pod for it. You did not change the DaemonSet at all.","points":15,"is_optional":false,"is_stateful":true},{"id":"4a7455b2-4a7f-5783-a0ee-c0891cf83aa9","lab_id":"bb0913dc-02d9-580b-95e0-0023ff31b9ea","position":3,"title":"Delete a DaemonSet pod","description":"Delete the DaemonSet pod that runs on `node2` and check that a new one is created on the same node.","verification_script":"#!/bin/bash\nP=$(kubectl get pods -l name=fluentd-elasticsearch --field-selector spec.nodeName=node2 -o jsonpath='{.items[0].metadata.creationTimestamp}')\nN=$(kubectl get node node2 -o jsonpath='{.metadata.creationTimestamp}')\ntest -n \"$P\" \u0026\u0026 [ $(( $(date -d \"$P\" +%s) - $(date -d \"$N\" +%s) )) -ge 3 ]\n","hint_context":"`kubectl get pods -o wide` shows the node of each pod; then `kubectl delete pod \u003cname\u003e`.","explanation_context":"The DaemonSet saw node2 without its pod and created a new one there.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('27928b62-72dd-50f5-945f-2c8dbc7da8a6', 'e858ff7d-9bf2-5c07-b12b-e0ffb4e9af9f', '12e46192-0803-53cb-854c-b6e8de646a15', 1, 'Create the DaemonSet', $md$Apply `daemonset.yaml`. Run `kubectl get daemonset` and `kubectl get pods -o wide`. How many pods are there, and on which node?$md$, $script$#!/bin/bash
test "$(kubectl get daemonset logdaemonset -o jsonpath='{.status.numberReady}')" = "1"
$script$, '`kubectl apply -f daemonset.yaml`', 'The cluster has one node, so the DaemonSet runs exactly one pod. There is no replicas field; the number of nodes decides.', 10, false, true),
('719d64a9-512e-5a25-ab20-38a9a75ad22c', 'e858ff7d-9bf2-5c07-b12b-e0ffb4e9af9f', '626905e6-ad51-5ca8-9c63-57348ea490f6', 2, 'Add a node and watch the DaemonSet follow', $md$Register a second node with `kubectl apply -f node2.yaml`. Wait a few seconds, then check `kubectl get nodes` and `kubectl get pods -o wide` again.$md$, $script$#!/bin/bash
test "$(kubectl get daemonset logdaemonset -o jsonpath='{.status.numberReady}')" = "2" || exit 1
kubectl get pods -l name=fluentd-elasticsearch -o jsonpath='{.items[*].spec.nodeName}' | grep -q node2
$script$, 'Apply the node file, then give the DaemonSet controller a few seconds.', 'As soon as node2 was Ready, the DaemonSet controller created a pod for it. You did not change the DaemonSet at all.', 15, false, true),
('b38c2129-211c-5cbf-9061-32f0fe1696df', 'e858ff7d-9bf2-5c07-b12b-e0ffb4e9af9f', '4a7455b2-4a7f-5783-a0ee-c0891cf83aa9', 3, 'Delete a DaemonSet pod', $md$Delete the DaemonSet pod that runs on `node2` and check that a new one is created on the same node.$md$, $script$#!/bin/bash
P=$(kubectl get pods -l name=fluentd-elasticsearch --field-selector spec.nodeName=node2 -o jsonpath='{.items[0].metadata.creationTimestamp}')
N=$(kubectl get node node2 -o jsonpath='{.metadata.creationTimestamp}')
test -n "$P" && [ $(( $(date -d "$P" +%s) - $(date -d "$N" +%s) )) -ge 3 ]
$script$, '`kubectl get pods -o wide` shows the node of each pod; then `kubectl delete pod <name>`.', 'The DaemonSet saw node2 without its pod and created a new one there.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'e858ff7d-9bf2-5c07-b12b-e0ffb4e9af9f', updated_at = now()
WHERE id = 'bb0913dc-02d9-580b-95e0-0023ff31b9ea' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('eef498be-cf84-549f-bcc0-9d59d5bc9f8d', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Lab: StatefulSet', 'lab', 4, 25)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('7827e8aa-3e5c-54a0-b5b6-c88138a496d6', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'eef498be-cf84-549f-bcc0-9d59d5bc9f8d', 'module', 'Lab: StatefulSet', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/pvs.yaml <<'MFEOF'
# This sandbox has no storage provisioner, so we create the disks (PersistentVolumes)
# up front. On a cloud cluster a StorageClass creates them on demand.
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-1
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  hostPath:
    path: /data/pv-1
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-2
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  hostPath:
    path: /data/pv-2
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-3
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  hostPath:
    path: /data/pv-3
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-4
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  hostPath:
    path: /data/pv-4

MFEOF
chmod 666 /home/labuser/work/pvs.yaml
cat > /home/labuser/work/statefulset.yaml <<'MFEOF'
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: nginx
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 512Mi

MFEOF
chmod 666 /home/labuser/work/statefulset.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '987d401f-cc6f-50ca-a164-a92877c81d76' AND id NOT IN ('e1cf7846-ff25-5401-a6ca-eb268674579c', '993dfdba-a888-5f5a-a360-9a09f2463cf9', '935083f8-1518-56bf-9c75-4396cc4b3e7b', '03d110fc-06db-5e94-a414-9b3abb9d565a', 'b7d751dc-9888-5e80-9a06-2a786d6bc903');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '987d401f-cc6f-50ca-a164-a92877c81d76';
DELETE FROM lab_tasks WHERE lab_id = '7827e8aa-3e5c-54a0-b5b6-c88138a496d6' AND id NOT IN ('2b493bc6-8bbe-5d12-ab23-3f4f33776d7f', 'e4901865-4f54-58d8-bfc5-f8d6df97a7b7', '9c7bbf21-e831-5f1f-9ae4-729bcb328798', 'f0bb6b3b-9e01-5d40-ade1-a6c9adaf6a15', 'becfbf81-c33b-5530-b209-bdd463a1112b');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '7827e8aa-3e5c-54a0-b5b6-c88138a496d6';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('2b493bc6-8bbe-5d12-ab23-3f4f33776d7f', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 1, 'Create the disks', $md$Apply `pvs.yaml` and check `kubectl get pv`. All four should be `Available`.$md$, $script$#!/bin/bash
test "$(kubectl get pv pv-1 pv-2 pv-3 pv-4 --no-headers 2>/dev/null | wc -l)" = "4"
$script$, '`kubectl apply -f pvs.yaml`', 'A PersistentVolume is a piece of storage in the cluster. The storage section covers them in detail.', 5, false, true),
('e4901865-4f54-58d8-bfc5-f8d6df97a7b7', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 2, 'Create the StatefulSet', $md$Apply `statefulset.yaml`. Look at the pod names (`kubectl get pods`) and the claims (`kubectl get pvc`). Notice the pattern `web-0`, `web-1`, `web-2` and `www-web-0`, `www-web-1`, `www-web-2`.$md$, $script$#!/bin/bash
test "$(kubectl get statefulset web -o jsonpath='{.status.readyReplicas}')" = "3" || exit 1
for i in 0 1 2; do kubectl get pvc www-web-$i -o jsonpath='{.status.phase}' | grep -qx Bound || exit 1; done
kubectl get svc nginx -o jsonpath='{.spec.clusterIP}' | grep -qx None
$script$, '`kubectl apply -f statefulset.yaml`, then `kubectl get pods,pvc`', 'Each pod got a stable numbered name and its own PVC from the volumeClaimTemplate. The headless Service (clusterIP None) gives each pod a DNS name like web-0.nginx.', 15, false, true),
('9c7bbf21-e831-5f1f-9ae4-729bcb328798', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 3, 'Scale up', $md$Scale the StatefulSet `web` to 4 replicas. What is the new pod called?$md$, $script$#!/bin/bash
kubectl get pod web-3 -o jsonpath='{.status.phase}' | grep -qx Running && kubectl get pvc www-web-3 >/dev/null 2>&1
$script$, '`kubectl scale statefulset web --replicas=4`', 'The next number is used (web-3), never a random name, and it gets its own claim www-web-3.', 10, false, true),
('f0bb6b3b-9e01-5d40-ade1-a6c9adaf6a15', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 4, 'Scale down and keep the data', $md$Scale `web` down to 2 replicas. Which pods were removed? Now check `kubectl get pvc`. Were any claims deleted?$md$, $script$#!/bin/bash
! kubectl get pod web-2 >/dev/null 2>&1 || exit 1
! kubectl get pod web-3 >/dev/null 2>&1 || exit 1
kubectl get pvc www-web-2 www-web-3 >/dev/null 2>&1
$script$, 'Scale the same way. Scaling down removes the highest numbers first.', 'web-3 and web-2 were removed (highest first), but their claims still exist. Scale back up and those pods get their old data back.', 15, false, true),
('becfbf81-c33b-5530-b209-bdd463a1112b', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 5, 'Delete a pod and check its identity', $md$Delete pod `web-0`. When it comes back, check its name and which claim it uses with `kubectl get pod web-0 -o yaml | grep claimName`.$md$, $script$#!/bin/bash
S=$(kubectl get statefulset web -o jsonpath='{.metadata.creationTimestamp}')
P=$(kubectl get pod web-0 -o jsonpath='{.metadata.creationTimestamp}')
[ $(( $(date -d "$P" +%s) - $(date -d "$S" +%s) )) -ge 3 ] || exit 1
kubectl get pod web-0 -o jsonpath='{.spec.volumes[?(@.name=="www")].persistentVolumeClaim.claimName}' | grep -qx www-web-0
$script$, '`kubectl delete pod web-0`', 'The new pod has the same name (web-0) and reattached the same claim (www-web-0). This stable identity is what databases need.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('987d401f-cc6f-50ca-a164-a92877c81d76', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 1, $json$[{"id":"2b493bc6-8bbe-5d12-ab23-3f4f33776d7f","lab_id":"7827e8aa-3e5c-54a0-b5b6-c88138a496d6","position":1,"title":"Create the disks","description":"Apply `pvs.yaml` and check `kubectl get pv`. All four should be `Available`.","verification_script":"#!/bin/bash\ntest \"$(kubectl get pv pv-1 pv-2 pv-3 pv-4 --no-headers 2\u003e/dev/null | wc -l)\" = \"4\"\n","hint_context":"`kubectl apply -f pvs.yaml`","explanation_context":"A PersistentVolume is a piece of storage in the cluster. The storage section covers them in detail.","points":5,"is_optional":false,"is_stateful":true},{"id":"e4901865-4f54-58d8-bfc5-f8d6df97a7b7","lab_id":"7827e8aa-3e5c-54a0-b5b6-c88138a496d6","position":2,"title":"Create the StatefulSet","description":"Apply `statefulset.yaml`. Look at the pod names (`kubectl get pods`) and the claims (`kubectl get pvc`). Notice the pattern `web-0`, `web-1`, `web-2` and `www-web-0`, `www-web-1`, `www-web-2`.","verification_script":"#!/bin/bash\ntest \"$(kubectl get statefulset web -o jsonpath='{.status.readyReplicas}')\" = \"3\" || exit 1\nfor i in 0 1 2; do kubectl get pvc www-web-$i -o jsonpath='{.status.phase}' | grep -qx Bound || exit 1; done\nkubectl get svc nginx -o jsonpath='{.spec.clusterIP}' | grep -qx None\n","hint_context":"`kubectl apply -f statefulset.yaml`, then `kubectl get pods,pvc`","explanation_context":"Each pod got a stable numbered name and its own PVC from the volumeClaimTemplate. The headless Service (clusterIP None) gives each pod a DNS name like web-0.nginx.","points":15,"is_optional":false,"is_stateful":true},{"id":"9c7bbf21-e831-5f1f-9ae4-729bcb328798","lab_id":"7827e8aa-3e5c-54a0-b5b6-c88138a496d6","position":3,"title":"Scale up","description":"Scale the StatefulSet `web` to 4 replicas. What is the new pod called?","verification_script":"#!/bin/bash\nkubectl get pod web-3 -o jsonpath='{.status.phase}' | grep -qx Running \u0026\u0026 kubectl get pvc www-web-3 \u003e/dev/null 2\u003e\u00261\n","hint_context":"`kubectl scale statefulset web --replicas=4`","explanation_context":"The next number is used (web-3), never a random name, and it gets its own claim www-web-3.","points":10,"is_optional":false,"is_stateful":true},{"id":"f0bb6b3b-9e01-5d40-ade1-a6c9adaf6a15","lab_id":"7827e8aa-3e5c-54a0-b5b6-c88138a496d6","position":4,"title":"Scale down and keep the data","description":"Scale `web` down to 2 replicas. Which pods were removed? Now check `kubectl get pvc`. Were any claims deleted?","verification_script":"#!/bin/bash\n! kubectl get pod web-2 \u003e/dev/null 2\u003e\u00261 || exit 1\n! kubectl get pod web-3 \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get pvc www-web-2 www-web-3 \u003e/dev/null 2\u003e\u00261\n","hint_context":"Scale the same way. Scaling down removes the highest numbers first.","explanation_context":"web-3 and web-2 were removed (highest first), but their claims still exist. Scale back up and those pods get their old data back.","points":15,"is_optional":false,"is_stateful":true},{"id":"becfbf81-c33b-5530-b209-bdd463a1112b","lab_id":"7827e8aa-3e5c-54a0-b5b6-c88138a496d6","position":5,"title":"Delete a pod and check its identity","description":"Delete pod `web-0`. When it comes back, check its name and which claim it uses with `kubectl get pod web-0 -o yaml | grep claimName`.","verification_script":"#!/bin/bash\nS=$(kubectl get statefulset web -o jsonpath='{.metadata.creationTimestamp}')\nP=$(kubectl get pod web-0 -o jsonpath='{.metadata.creationTimestamp}')\n[ $(( $(date -d \"$P\" +%s) - $(date -d \"$S\" +%s) )) -ge 3 ] || exit 1\nkubectl get pod web-0 -o jsonpath='{.spec.volumes[?(@.name==\"www\")].persistentVolumeClaim.claimName}' | grep -qx www-web-0\n","hint_context":"`kubectl delete pod web-0`","explanation_context":"The new pod has the same name (web-0) and reattached the same claim (www-web-0). This stable identity is what databases need.","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('e1cf7846-ff25-5401-a6ca-eb268674579c', '987d401f-cc6f-50ca-a164-a92877c81d76', '2b493bc6-8bbe-5d12-ab23-3f4f33776d7f', 1, 'Create the disks', $md$Apply `pvs.yaml` and check `kubectl get pv`. All four should be `Available`.$md$, $script$#!/bin/bash
test "$(kubectl get pv pv-1 pv-2 pv-3 pv-4 --no-headers 2>/dev/null | wc -l)" = "4"
$script$, '`kubectl apply -f pvs.yaml`', 'A PersistentVolume is a piece of storage in the cluster. The storage section covers them in detail.', 5, false, true),
('993dfdba-a888-5f5a-a360-9a09f2463cf9', '987d401f-cc6f-50ca-a164-a92877c81d76', 'e4901865-4f54-58d8-bfc5-f8d6df97a7b7', 2, 'Create the StatefulSet', $md$Apply `statefulset.yaml`. Look at the pod names (`kubectl get pods`) and the claims (`kubectl get pvc`). Notice the pattern `web-0`, `web-1`, `web-2` and `www-web-0`, `www-web-1`, `www-web-2`.$md$, $script$#!/bin/bash
test "$(kubectl get statefulset web -o jsonpath='{.status.readyReplicas}')" = "3" || exit 1
for i in 0 1 2; do kubectl get pvc www-web-$i -o jsonpath='{.status.phase}' | grep -qx Bound || exit 1; done
kubectl get svc nginx -o jsonpath='{.spec.clusterIP}' | grep -qx None
$script$, '`kubectl apply -f statefulset.yaml`, then `kubectl get pods,pvc`', 'Each pod got a stable numbered name and its own PVC from the volumeClaimTemplate. The headless Service (clusterIP None) gives each pod a DNS name like web-0.nginx.', 15, false, true),
('935083f8-1518-56bf-9c75-4396cc4b3e7b', '987d401f-cc6f-50ca-a164-a92877c81d76', '9c7bbf21-e831-5f1f-9ae4-729bcb328798', 3, 'Scale up', $md$Scale the StatefulSet `web` to 4 replicas. What is the new pod called?$md$, $script$#!/bin/bash
kubectl get pod web-3 -o jsonpath='{.status.phase}' | grep -qx Running && kubectl get pvc www-web-3 >/dev/null 2>&1
$script$, '`kubectl scale statefulset web --replicas=4`', 'The next number is used (web-3), never a random name, and it gets its own claim www-web-3.', 10, false, true),
('03d110fc-06db-5e94-a414-9b3abb9d565a', '987d401f-cc6f-50ca-a164-a92877c81d76', 'f0bb6b3b-9e01-5d40-ade1-a6c9adaf6a15', 4, 'Scale down and keep the data', $md$Scale `web` down to 2 replicas. Which pods were removed? Now check `kubectl get pvc`. Were any claims deleted?$md$, $script$#!/bin/bash
! kubectl get pod web-2 >/dev/null 2>&1 || exit 1
! kubectl get pod web-3 >/dev/null 2>&1 || exit 1
kubectl get pvc www-web-2 www-web-3 >/dev/null 2>&1
$script$, 'Scale the same way. Scaling down removes the highest numbers first.', 'web-3 and web-2 were removed (highest first), but their claims still exist. Scale back up and those pods get their old data back.', 15, false, true),
('b7d751dc-9888-5e80-9a06-2a786d6bc903', '987d401f-cc6f-50ca-a164-a92877c81d76', 'becfbf81-c33b-5530-b209-bdd463a1112b', 5, 'Delete a pod and check its identity', $md$Delete pod `web-0`. When it comes back, check its name and which claim it uses with `kubectl get pod web-0 -o yaml | grep claimName`.$md$, $script$#!/bin/bash
S=$(kubectl get statefulset web -o jsonpath='{.metadata.creationTimestamp}')
P=$(kubectl get pod web-0 -o jsonpath='{.metadata.creationTimestamp}')
[ $(( $(date -d "$P" +%s) - $(date -d "$S" +%s) )) -ge 3 ] || exit 1
kubectl get pod web-0 -o jsonpath='{.spec.volumes[?(@.name=="www")].persistentVolumeClaim.claimName}' | grep -qx www-web-0
$script$, '`kubectl delete pod web-0`', 'The new pod has the same name (web-0) and reattached the same claim (www-web-0). This stable identity is what databases need.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '987d401f-cc6f-50ca-a164-a92877c81d76', updated_at = now()
WHERE id = '7827e8aa-3e5c-54a0-b5b6-c88138a496d6' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('1ae9f3c3-5b51-5732-a08b-48e8b115298f', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Lab: Job', 'lab', 5, 15)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('d332d18e-88f9-526f-99bb-c69f6206ab46', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '1ae9f3c3-5b51-5732-a08b-48e8b115298f', 'module', 'Lab: Job', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/job.yaml <<'MFEOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  parallelism: 2
  completions: 10
  backoffLimit: 5
  activeDeadlineSeconds: 100
  template:
    spec:
      containers:
      - name: pi
        image: perl:5.40
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never

MFEOF
chmod 666 /home/labuser/work/job.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 30, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'b3f5113a-31a6-5c85-9cda-1dc46de7f15d' AND id NOT IN ('19a2795e-296e-59b5-b4da-bc0d4525db1e', '358b2255-cf96-5a72-8485-66547246c224', 'ae5f6610-3062-57f3-bebc-8a65413a185f');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'b3f5113a-31a6-5c85-9cda-1dc46de7f15d';
DELETE FROM lab_tasks WHERE lab_id = 'd332d18e-88f9-526f-99bb-c69f6206ab46' AND id NOT IN ('f3c090cb-7432-58ca-a1f4-8da72876a15b', '438df35d-d585-534e-82fa-b2b1c6f9e5bc', '19e5c461-1eb1-53e9-9664-b9543a5dc986');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'd332d18e-88f9-526f-99bb-c69f6206ab46';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('f3c090cb-7432-58ca-a1f4-8da72876a15b', 'd332d18e-88f9-526f-99bb-c69f6206ab46', 1, 'Run a Job to completion', $md$Apply `job.yaml`, then watch it with `kubectl get jobs -w` (Ctrl+C to stop) and `kubectl get pods`. Wait until COMPLETIONS shows `10/10`.$md$, $script$#!/bin/bash
test "$(kubectl get job pi -o jsonpath='{.status.succeeded}')" = "10"
$script$, '`kubectl apply -f job.yaml`', 'The Job ran at most 2 pods at a time (parallelism) until 10 had succeeded (completions). Finished pods stay in Completed state so you can read their logs.', 15, false, true),
('438df35d-d585-534e-82fa-b2b1c6f9e5bc', 'd332d18e-88f9-526f-99bb-c69f6206ab46', 2, 'Create a Job with one command', $md$Create a Job called `hello` from `busybox:1.36` that runs `echo hello`, using `kubectl create job`. Check that it completes.$md$, $script$#!/bin/bash
kubectl get job hello -o jsonpath='{.spec.template.spec.containers[0].image} {.status.succeeded}' | grep -qx 'busybox:1.36 1'
$script$, '`kubectl create job <name> --image=<image> -- <command>`. Everything after `--` is the command.', '`kubectl create job hello --image=busybox:1.36 -- echo hello` builds a Job that needs one successful run and uses restartPolicy Never.', 10, false, false),
('19e5c461-1eb1-53e9-9664-b9543a5dc986', 'd332d18e-88f9-526f-99bb-c69f6206ab46', 3, 'Clean up finished Jobs automatically', $md$Write `cleanup-job.yaml` for a Job named `cleanup` (image `busybox:1.36`, command `["sh", "-c", "echo done"]`, restartPolicy `Never`) that deletes itself **300 seconds** after it finishes. Apply it.
$md$, $script$#!/bin/bash
kubectl get job cleanup -o jsonpath='{.spec.ttlSecondsAfterFinished}' 2>/dev/null | grep -qx 300
$script$, 'The field is `ttlSecondsAfterFinished`, directly under the Job''s `spec`.', 'The TTL controller deletes the Job and its pods once the TTL has passed after completion, so finished Jobs do not pile up.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('b3f5113a-31a6-5c85-9cda-1dc46de7f15d', 'd332d18e-88f9-526f-99bb-c69f6206ab46', 1, $json$[{"id":"f3c090cb-7432-58ca-a1f4-8da72876a15b","lab_id":"d332d18e-88f9-526f-99bb-c69f6206ab46","position":1,"title":"Run a Job to completion","description":"Apply `job.yaml`, then watch it with `kubectl get jobs -w` (Ctrl+C to stop) and `kubectl get pods`. Wait until COMPLETIONS shows `10/10`.","verification_script":"#!/bin/bash\ntest \"$(kubectl get job pi -o jsonpath='{.status.succeeded}')\" = \"10\"\n","hint_context":"`kubectl apply -f job.yaml`","explanation_context":"The Job ran at most 2 pods at a time (parallelism) until 10 had succeeded (completions). Finished pods stay in Completed state so you can read their logs.","points":15,"is_optional":false,"is_stateful":true},{"id":"438df35d-d585-534e-82fa-b2b1c6f9e5bc","lab_id":"d332d18e-88f9-526f-99bb-c69f6206ab46","position":2,"title":"Create a Job with one command","description":"Create a Job called `hello` from `busybox:1.36` that runs `echo hello`, using `kubectl create job`. Check that it completes.","verification_script":"#!/bin/bash\nkubectl get job hello -o jsonpath='{.spec.template.spec.containers[0].image} {.status.succeeded}' | grep -qx 'busybox:1.36 1'\n","hint_context":"`kubectl create job \u003cname\u003e --image=\u003cimage\u003e -- \u003ccommand\u003e`. Everything after `--` is the command.","explanation_context":"`kubectl create job hello --image=busybox:1.36 -- echo hello` builds a Job that needs one successful run and uses restartPolicy Never.","points":10,"is_optional":false,"is_stateful":false},{"id":"19e5c461-1eb1-53e9-9664-b9543a5dc986","lab_id":"d332d18e-88f9-526f-99bb-c69f6206ab46","position":3,"title":"Clean up finished Jobs automatically","description":"Write `cleanup-job.yaml` for a Job named `cleanup` (image `busybox:1.36`, command `[\"sh\", \"-c\", \"echo done\"]`, restartPolicy `Never`) that deletes itself **300 seconds** after it finishes. Apply it.\n","verification_script":"#!/bin/bash\nkubectl get job cleanup -o jsonpath='{.spec.ttlSecondsAfterFinished}' 2\u003e/dev/null | grep -qx 300\n","hint_context":"The field is `ttlSecondsAfterFinished`, directly under the Job's `spec`.","explanation_context":"The TTL controller deletes the Job and its pods once the TTL has passed after completion, so finished Jobs do not pile up.","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('19a2795e-296e-59b5-b4da-bc0d4525db1e', 'b3f5113a-31a6-5c85-9cda-1dc46de7f15d', 'f3c090cb-7432-58ca-a1f4-8da72876a15b', 1, 'Run a Job to completion', $md$Apply `job.yaml`, then watch it with `kubectl get jobs -w` (Ctrl+C to stop) and `kubectl get pods`. Wait until COMPLETIONS shows `10/10`.$md$, $script$#!/bin/bash
test "$(kubectl get job pi -o jsonpath='{.status.succeeded}')" = "10"
$script$, '`kubectl apply -f job.yaml`', 'The Job ran at most 2 pods at a time (parallelism) until 10 had succeeded (completions). Finished pods stay in Completed state so you can read their logs.', 15, false, true),
('358b2255-cf96-5a72-8485-66547246c224', 'b3f5113a-31a6-5c85-9cda-1dc46de7f15d', '438df35d-d585-534e-82fa-b2b1c6f9e5bc', 2, 'Create a Job with one command', $md$Create a Job called `hello` from `busybox:1.36` that runs `echo hello`, using `kubectl create job`. Check that it completes.$md$, $script$#!/bin/bash
kubectl get job hello -o jsonpath='{.spec.template.spec.containers[0].image} {.status.succeeded}' | grep -qx 'busybox:1.36 1'
$script$, '`kubectl create job <name> --image=<image> -- <command>`. Everything after `--` is the command.', '`kubectl create job hello --image=busybox:1.36 -- echo hello` builds a Job that needs one successful run and uses restartPolicy Never.', 10, false, false),
('ae5f6610-3062-57f3-bebc-8a65413a185f', 'b3f5113a-31a6-5c85-9cda-1dc46de7f15d', '19e5c461-1eb1-53e9-9664-b9543a5dc986', 3, 'Clean up finished Jobs automatically', $md$Write `cleanup-job.yaml` for a Job named `cleanup` (image `busybox:1.36`, command `["sh", "-c", "echo done"]`, restartPolicy `Never`) that deletes itself **300 seconds** after it finishes. Apply it.
$md$, $script$#!/bin/bash
kubectl get job cleanup -o jsonpath='{.spec.ttlSecondsAfterFinished}' 2>/dev/null | grep -qx 300
$script$, 'The field is `ttlSecondsAfterFinished`, directly under the Job''s `spec`.', 'The TTL controller deletes the Job and its pods once the TTL has passed after completion, so finished Jobs do not pile up.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'b3f5113a-31a6-5c85-9cda-1dc46de7f15d', updated_at = now()
WHERE id = 'd332d18e-88f9-526f-99bb-c69f6206ab46' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('c71cf669-6e2e-5dc6-b600-981dc4f3f7f0', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Lab: CronJob', 'lab', 6, 15)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('18a5fbe4-abd9-5cff-aea3-8f2c6215da35', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c71cf669-6e2e-5dc6-b600-981dc4f3f7f0', 'module', 'Lab: CronJob', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/cronjob.yaml <<'MFEOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox:1.36
            imagePullPolicy: IfNotPresent
            command:
            - /bin/sh
            - -c
            - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure

MFEOF
chmod 666 /home/labuser/work/cronjob.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 30, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '3546b028-3c3a-521c-899a-588034d65714' AND id NOT IN ('f48eda54-748b-56b8-92d6-3f0bdd429567', '1f063cff-11de-50ea-abfe-8a8e7b131527', '246155de-5d8b-53f8-b623-0759586d276a', 'd2e66e37-e4f0-5588-a41d-bb32d78da1a4');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '3546b028-3c3a-521c-899a-588034d65714';
DELETE FROM lab_tasks WHERE lab_id = '18a5fbe4-abd9-5cff-aea3-8f2c6215da35' AND id NOT IN ('1d9fa5df-6a76-51ee-a9d1-3f4307f2ca8b', '2dd482a8-cb5c-51de-950c-60398a6b4087', '02d64332-20e9-5268-93d9-ffae71da44d3', '498b9bb7-6f25-53cd-950b-be341e8bdd16');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '18a5fbe4-abd9-5cff-aea3-8f2c6215da35';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('1d9fa5df-6a76-51ee-a9d1-3f4307f2ca8b', '18a5fbe4-abd9-5cff-aea3-8f2c6215da35', 1, 'Create a CronJob', $md$Apply `cronjob.yaml`, then run `kubectl get cronjobs` and `kubectl get jobs -w`. Within about a minute a Job named `hello-<number>` appears.$md$, $script$#!/bin/bash
test "$(kubectl get cronjob hello -o jsonpath='{.spec.schedule}')" = "*/1 * * * *" || exit 1
kubectl get jobs -o jsonpath='{range .items[*]}{.metadata.ownerReferences[0].name}{"\n"}{end}' | grep -qx hello
$script$, 'Apply the file, then wait up to one minute for the first scheduled run.', 'At each scheduled time the CronJob controller creates a normal Job from jobTemplate. The number in the Job name encodes the scheduled time.', 10, false, true),
('2dd482a8-cb5c-51de-950c-60398a6b4087', '18a5fbe4-abd9-5cff-aea3-8f2c6215da35', 2, 'Trigger a run now', $md$Do not wait for the schedule. Create a Job named `manual` from the CronJob `hello`.$md$, $script$#!/bin/bash
kubectl get job manual -o jsonpath='{.metadata.annotations.cronjob\.kubernetes\.io/instantiate}' | grep -qx manual
$script$, '`kubectl create job <name> --from=cronjob/<cronjob-name>`', '`--from=cronjob/hello` copies the CronJob''s jobTemplate into a new Job. It is handy for testing a schedule without waiting.', 10, false, false),
('02d64332-20e9-5268-93d9-ffae71da44d3', '18a5fbe4-abd9-5cff-aea3-8f2c6215da35', 3, 'Pause the schedule', $md$Suspend the CronJob `hello` so it stops creating new Jobs.$md$, $script$#!/bin/bash
kubectl get cronjob hello -o jsonpath='{.spec.suspend}' | grep -qx true
$script$, 'Set `spec.suspend` to true, for example: `kubectl patch cronjob hello -p ''{"spec":{"suspend":true}}''`', 'A suspended CronJob keeps its definition but creates no new Jobs until suspend is set back to false.', 10, false, false),
('498b9bb7-6f25-53cd-950b-be341e8bdd16', '18a5fbe4-abd9-5cff-aea3-8f2c6215da35', 4, 'Write a nightly backup CronJob', $md$Write and apply a CronJob named `backup` that:
- runs every day at **02:30**
- never runs two copies at the same time
- uses image `busybox:1.36` with command `["sh", "-c", "echo backing up"]` and restartPolicy `OnFailure`
$md$, $script$#!/bin/bash
test "$(kubectl get cronjob backup -o jsonpath='{.spec.schedule}|{.spec.concurrencyPolicy}|{.spec.jobTemplate.spec.template.spec.containers[0].image}')" = "30 2 * * *|Forbid|busybox:1.36"
$script$, 'Cron fields are minute, hour, day of month, month, day of week. The field that prevents overlapping runs is `concurrencyPolicy`.', '`30 2 * * *` means minute 30 of hour 2, every day. `concurrencyPolicy: Forbid` skips a run while the previous Job is still active.', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('3546b028-3c3a-521c-899a-588034d65714', '18a5fbe4-abd9-5cff-aea3-8f2c6215da35', 1, $json$[{"id":"1d9fa5df-6a76-51ee-a9d1-3f4307f2ca8b","lab_id":"18a5fbe4-abd9-5cff-aea3-8f2c6215da35","position":1,"title":"Create a CronJob","description":"Apply `cronjob.yaml`, then run `kubectl get cronjobs` and `kubectl get jobs -w`. Within about a minute a Job named `hello-\u003cnumber\u003e` appears.","verification_script":"#!/bin/bash\ntest \"$(kubectl get cronjob hello -o jsonpath='{.spec.schedule}')\" = \"*/1 * * * *\" || exit 1\nkubectl get jobs -o jsonpath='{range .items[*]}{.metadata.ownerReferences[0].name}{\"\\n\"}{end}' | grep -qx hello\n","hint_context":"Apply the file, then wait up to one minute for the first scheduled run.","explanation_context":"At each scheduled time the CronJob controller creates a normal Job from jobTemplate. The number in the Job name encodes the scheduled time.","points":10,"is_optional":false,"is_stateful":true},{"id":"2dd482a8-cb5c-51de-950c-60398a6b4087","lab_id":"18a5fbe4-abd9-5cff-aea3-8f2c6215da35","position":2,"title":"Trigger a run now","description":"Do not wait for the schedule. Create a Job named `manual` from the CronJob `hello`.","verification_script":"#!/bin/bash\nkubectl get job manual -o jsonpath='{.metadata.annotations.cronjob\\.kubernetes\\.io/instantiate}' | grep -qx manual\n","hint_context":"`kubectl create job \u003cname\u003e --from=cronjob/\u003ccronjob-name\u003e`","explanation_context":"`--from=cronjob/hello` copies the CronJob's jobTemplate into a new Job. It is handy for testing a schedule without waiting.","points":10,"is_optional":false,"is_stateful":false},{"id":"02d64332-20e9-5268-93d9-ffae71da44d3","lab_id":"18a5fbe4-abd9-5cff-aea3-8f2c6215da35","position":3,"title":"Pause the schedule","description":"Suspend the CronJob `hello` so it stops creating new Jobs.","verification_script":"#!/bin/bash\nkubectl get cronjob hello -o jsonpath='{.spec.suspend}' | grep -qx true\n","hint_context":"Set `spec.suspend` to true, for example: `kubectl patch cronjob hello -p '{\"spec\":{\"suspend\":true}}'`","explanation_context":"A suspended CronJob keeps its definition but creates no new Jobs until suspend is set back to false.","points":10,"is_optional":false,"is_stateful":false},{"id":"498b9bb7-6f25-53cd-950b-be341e8bdd16","lab_id":"18a5fbe4-abd9-5cff-aea3-8f2c6215da35","position":4,"title":"Write a nightly backup CronJob","description":"Write and apply a CronJob named `backup` that:\n- runs every day at **02:30**\n- never runs two copies at the same time\n- uses image `busybox:1.36` with command `[\"sh\", \"-c\", \"echo backing up\"]` and restartPolicy `OnFailure`\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get cronjob backup -o jsonpath='{.spec.schedule}|{.spec.concurrencyPolicy}|{.spec.jobTemplate.spec.template.spec.containers[0].image}')\" = \"30 2 * * *|Forbid|busybox:1.36\"\n","hint_context":"Cron fields are minute, hour, day of month, month, day of week. The field that prevents overlapping runs is `concurrencyPolicy`.","explanation_context":"`30 2 * * *` means minute 30 of hour 2, every day. `concurrencyPolicy: Forbid` skips a run while the previous Job is still active.","points":20,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('f48eda54-748b-56b8-92d6-3f0bdd429567', '3546b028-3c3a-521c-899a-588034d65714', '1d9fa5df-6a76-51ee-a9d1-3f4307f2ca8b', 1, 'Create a CronJob', $md$Apply `cronjob.yaml`, then run `kubectl get cronjobs` and `kubectl get jobs -w`. Within about a minute a Job named `hello-<number>` appears.$md$, $script$#!/bin/bash
test "$(kubectl get cronjob hello -o jsonpath='{.spec.schedule}')" = "*/1 * * * *" || exit 1
kubectl get jobs -o jsonpath='{range .items[*]}{.metadata.ownerReferences[0].name}{"\n"}{end}' | grep -qx hello
$script$, 'Apply the file, then wait up to one minute for the first scheduled run.', 'At each scheduled time the CronJob controller creates a normal Job from jobTemplate. The number in the Job name encodes the scheduled time.', 10, false, true),
('1f063cff-11de-50ea-abfe-8a8e7b131527', '3546b028-3c3a-521c-899a-588034d65714', '2dd482a8-cb5c-51de-950c-60398a6b4087', 2, 'Trigger a run now', $md$Do not wait for the schedule. Create a Job named `manual` from the CronJob `hello`.$md$, $script$#!/bin/bash
kubectl get job manual -o jsonpath='{.metadata.annotations.cronjob\.kubernetes\.io/instantiate}' | grep -qx manual
$script$, '`kubectl create job <name> --from=cronjob/<cronjob-name>`', '`--from=cronjob/hello` copies the CronJob''s jobTemplate into a new Job. It is handy for testing a schedule without waiting.', 10, false, false),
('246155de-5d8b-53f8-b623-0759586d276a', '3546b028-3c3a-521c-899a-588034d65714', '02d64332-20e9-5268-93d9-ffae71da44d3', 3, 'Pause the schedule', $md$Suspend the CronJob `hello` so it stops creating new Jobs.$md$, $script$#!/bin/bash
kubectl get cronjob hello -o jsonpath='{.spec.suspend}' | grep -qx true
$script$, 'Set `spec.suspend` to true, for example: `kubectl patch cronjob hello -p ''{"spec":{"suspend":true}}''`', 'A suspended CronJob keeps its definition but creates no new Jobs until suspend is set back to false.', 10, false, false),
('d2e66e37-e4f0-5588-a41d-bb32d78da1a4', '3546b028-3c3a-521c-899a-588034d65714', '498b9bb7-6f25-53cd-950b-be341e8bdd16', 4, 'Write a nightly backup CronJob', $md$Write and apply a CronJob named `backup` that:
- runs every day at **02:30**
- never runs two copies at the same time
- uses image `busybox:1.36` with command `["sh", "-c", "echo backing up"]` and restartPolicy `OnFailure`
$md$, $script$#!/bin/bash
test "$(kubectl get cronjob backup -o jsonpath='{.spec.schedule}|{.spec.concurrencyPolicy}|{.spec.jobTemplate.spec.template.spec.containers[0].image}')" = "30 2 * * *|Forbid|busybox:1.36"
$script$, 'Cron fields are minute, hour, day of month, month, day of week. The field that prevents overlapping runs is `concurrencyPolicy`.', '`30 2 * * *` means minute 30 of hour 2, every day. `concurrencyPolicy: Forbid` skips a run while the previous Job is still active.', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '3546b028-3c3a-521c-899a-588034d65714', updated_at = now()
WHERE id = '18a5fbe4-abd9-5cff-aea3-8f2c6215da35' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('09be7e35-f8da-59d2-a7f4-24dbdcd43335', '00000000-0000-0000-0000-000000000001', 'mcq', 'What object does a Deployment create directly to keep the right number of pod...', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('eaed8dfc-499f-5871-a5c7-ac01c78fe4ad', '09be7e35-f8da-59d2-a7f4-24dbdcd43335', 1, $json${"prompt":"What object does a Deployment create directly to keep the right number of pods running?","multiple":false,"options":[{"id":"a","text":"A StatefulSet","is_correct":false},{"id":"b","text":"A ReplicaSet","is_correct":true},{"id":"c","text":"A DaemonSet","is_correct":false},{"id":"d","text":"A Job","is_correct":false}],"explanation":"Deployment → ReplicaSet → Pods. Each version of the pod template gets its own ReplicaSet."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('53a5f4f4-3355-57f1-b1b4-093b3c6eeea6', '00000000-0000-0000-0000-000000000001', 'mcq', 'A Deployment with 4 replicas uses RollingUpdate with maxSurge 1 and maxUnavai...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('476fa969-ea25-5fac-98a6-63975ea89561', '53a5f4f4-3355-57f1-b1b4-093b3c6eeea6', 1, $json${"prompt":"A Deployment with 4 replicas uses RollingUpdate with maxSurge 1 and maxUnavailable 0. What does that guarantee during an update?","multiple":false,"options":[{"id":"a","text":"All 4 pods are replaced at the same moment","is_correct":false},{"id":"b","text":"There are always at least 4 ready pods; one extra new pod is started and must be ready before an old one is removed","is_correct":true},{"id":"c","text":"Only one pod runs during the update","is_correct":false},{"id":"d","text":"The update is paused until you resume it","is_correct":false}],"explanation":"maxUnavailable 0 keeps capacity at 4 ready pods; maxSurge 1 allows one extra pod at a time. This is the safest, slowest setting."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2893878f-2d3d-564b-ac4b-b57da7b7f42b', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command returns a Deployment to its previous version?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c962e5ca-3d77-5bdc-a8e8-fa38a77b2f22', '2893878f-2d3d-564b-ac4b-b57da7b7f42b', 1, $json${"prompt":"Which command returns a Deployment to its previous version?","multiple":false,"options":[{"id":"a","text":"kubectl rollout undo deployment/web","is_correct":true},{"id":"b","text":"kubectl rollout pause deployment/web","is_correct":false},{"id":"c","text":"kubectl rollback web","is_correct":false},{"id":"d","text":"kubectl apply --previous -f web.yaml","is_correct":false}],"explanation":"rollout undo switches back to the previous ReplicaSet's template (or a specific one with --to-revision)."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('4e139855-4418-53ab-b335-13e415c0afb9', '00000000-0000-0000-0000-000000000001', 'mcq', 'You need a monitoring agent on every node, including nodes added later. Which...', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5249f0e7-3fdc-5478-8878-34b006ab20cf', '4e139855-4418-53ab-b335-13e415c0afb9', 1, $json${"prompt":"You need a monitoring agent on every node, including nodes added later. Which workload do you use?","multiple":false,"options":[{"id":"a","text":"Deployment","is_correct":false},{"id":"b","text":"DaemonSet","is_correct":true},{"id":"c","text":"CronJob","is_correct":false},{"id":"d","text":"StatefulSet","is_correct":false}],"explanation":"A DaemonSet runs one pod per eligible node and follows nodes as they join and leave."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ab44ea45-6f0b-51dc-8046-ed1568fa5aab', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which feature does a StatefulSet provide that a Deployment does not?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('41cc5d98-281a-5daa-b081-afea5eb26e74', 'ab44ea45-6f0b-51dc-8046-ed1568fa5aab', 1, $json${"prompt":"Which feature does a StatefulSet provide that a Deployment does not?","multiple":false,"options":[{"id":"a","text":"Automatic data replication between pods","is_correct":false},{"id":"b","text":"Stable pod names (app-0, app-1) and a separate PersistentVolumeClaim per pod","is_correct":true},{"id":"c","text":"Running one pod on every node","is_correct":false},{"id":"d","text":"Automatic scaling based on CPU","is_correct":false}],"explanation":"StatefulSets give identity and per-pod storage. Replication between members is the application's own job."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('4ea8b71c-7c28-55c0-9cea-515cf6995714', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is a headless Service?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('8528bfe0-b683-5913-8a0d-2dc0775049eb', '4ea8b71c-7c28-55c0-9cea-515cf6995714', 1, $json${"prompt":"What is a headless Service?","multiple":false,"options":[{"id":"a","text":"A Service with clusterIP None, whose DNS name returns the pod IPs directly","is_correct":true},{"id":"b","text":"A Service without a selector","is_correct":false},{"id":"c","text":"A Service that is only reachable from outside the cluster","is_correct":false},{"id":"d","text":"A Service without ports","is_correct":false}],"explanation":"Headless Services skip the virtual IP. StatefulSets use them so each pod gets its own DNS name, like web-0.nginx."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('529b15ab-41f7-51e7-b111-d368be573f44', '00000000-0000-0000-0000-000000000001', 'mcq', 'A Job has completions 5 and parallelism 5. What happens?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('3279eda2-ffef-5abb-81e1-b3686d99a674', '529b15ab-41f7-51e7-b111-d368be573f44', 1, $json${"prompt":"A Job has completions 5 and parallelism 5. What happens?","multiple":false,"options":[{"id":"a","text":"5 pods run at the same time, and the Job is complete when all 5 succeed","is_correct":true},{"id":"b","text":"1 pod runs 5 times in a row","is_correct":false},{"id":"c","text":"25 pods are created","is_correct":false},{"id":"d","text":"The pods run forever","is_correct":false}],"explanation":"parallelism is how many run at once; completions is how many successes are needed."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('8ac55aa8-5c7a-522b-87ae-c79ae090cd7d', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does the cron schedule `0 */6 * * *` mean?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2154e190-50c8-58fb-b94c-63957e5c773f', '8ac55aa8-5c7a-522b-87ae-c79ae090cd7d', 1, $json${"prompt":"What does the cron schedule `0 */6 * * *` mean?","multiple":false,"options":[{"id":"a","text":"Every 6 minutes","is_correct":false},{"id":"b","text":"At minute 0 of every 6th hour (00:00, 06:00, 12:00, 18:00)","is_correct":true},{"id":"c","text":"On the 6th day of every month","is_correct":false},{"id":"d","text":"Every day at 06:00 only","is_correct":false}],"explanation":"The second field is the hour. */6 means every 6 hours; the first field 0 means at minute 0."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5d8ccb6c-19a2-5e6d-87f5-6aa97cd3d35b', '00000000-0000-0000-0000-000000000001', 'mcq', 'You changed a ConfigMap that a Deployment reads as environment variables. How...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('8212512f-fa09-5e39-a309-e9239658d2b2', '5d8ccb6c-19a2-5e6d-87f5-6aa97cd3d35b', 1, $json${"prompt":"You changed a ConfigMap that a Deployment reads as environment variables. How do you make the running pods pick up the new values?","multiple":false,"options":[{"id":"a","text":"They update automatically within seconds","is_correct":false},{"id":"b","text":"Run kubectl rollout restart deployment/\u003cname\u003e to replace the pods","is_correct":true},{"id":"c","text":"Run kubectl rollout undo","is_correct":false},{"id":"d","text":"Delete the ConfigMap","is_correct":false}],"explanation":"Environment variables are read only when a container starts. A rollout restart replaces pods gradually so they read the new values."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('e3a128e6-a878-5c99-8f3d-da4b25e982f7', '00000000-0000-0000-0000-000000000001', 'Quiz: Deployments & Workload Controllers', 'k8s-workloads-quiz', 'Quiz covering Deployments & Workload Controllers.', 'mcq', 'published', 'module', 'bbd43c7b-762f-5386-84d8-19e2c51b38e8', 20, 70, 5, 9, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = 'e3a128e6-a878-5c99-8f3d-da4b25e982f7' AND question_id NOT IN ('09be7e35-f8da-59d2-a7f4-24dbdcd43335', '53a5f4f4-3355-57f1-b1b4-093b3c6eeea6', '2893878f-2d3d-564b-ac4b-b57da7b7f42b', '4e139855-4418-53ab-b335-13e415c0afb9', 'ab44ea45-6f0b-51dc-8046-ed1568fa5aab', '4ea8b71c-7c28-55c0-9cea-515cf6995714', '529b15ab-41f7-51e7-b111-d368be573f44', '8ac55aa8-5c7a-522b-87ae-c79ae090cd7d', '5d8ccb6c-19a2-5e6d-87f5-6aa97cd3d35b');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('f3b66a57-0295-508b-9564-825cfe718ab3', 'e3a128e6-a878-5c99-8f3d-da4b25e982f7', '09be7e35-f8da-59d2-a7f4-24dbdcd43335', 'eaed8dfc-499f-5871-a5c7-ac01c78fe4ad', 0, 1),
('f17f6eb4-081c-50dd-a8cc-948f4884658c', 'e3a128e6-a878-5c99-8f3d-da4b25e982f7', '53a5f4f4-3355-57f1-b1b4-093b3c6eeea6', '476fa969-ea25-5fac-98a6-63975ea89561', 1, 1),
('44446bd8-c192-58f6-a54e-bb93a325f4bc', 'e3a128e6-a878-5c99-8f3d-da4b25e982f7', '2893878f-2d3d-564b-ac4b-b57da7b7f42b', 'c962e5ca-3d77-5bdc-a8e8-fa38a77b2f22', 2, 1),
('d3514c01-6ce9-51e9-9dd7-18bf04fd3856', 'e3a128e6-a878-5c99-8f3d-da4b25e982f7', '4e139855-4418-53ab-b335-13e415c0afb9', '5249f0e7-3fdc-5478-8878-34b006ab20cf', 3, 1),
('ad7ca22f-92c0-5d2a-bb00-58a9ba8c9f9a', 'e3a128e6-a878-5c99-8f3d-da4b25e982f7', 'ab44ea45-6f0b-51dc-8046-ed1568fa5aab', '41cc5d98-281a-5daa-b081-afea5eb26e74', 4, 1),
('58f53b74-9d92-5417-9f17-6f1a215ad846', 'e3a128e6-a878-5c99-8f3d-da4b25e982f7', '4ea8b71c-7c28-55c0-9cea-515cf6995714', '8528bfe0-b683-5913-8a0d-2dc0775049eb', 5, 1),
('872ceecd-f99b-5ae1-ab65-e15b0878dcba', 'e3a128e6-a878-5c99-8f3d-da4b25e982f7', '529b15ab-41f7-51e7-b111-d368be573f44', '3279eda2-ffef-5abb-81e1-b3686d99a674', 6, 1),
('6231f7cc-43dd-5bad-ad08-678bfb2108eb', 'e3a128e6-a878-5c99-8f3d-da4b25e982f7', '8ac55aa8-5c7a-522b-87ae-c79ae090cd7d', '2154e190-50c8-58fb-b94c-63957e5c773f', 7, 1),
('d7268494-0d2a-57ad-a6f6-8af02fddbc26', 'e3a128e6-a878-5c99-8f3d-da4b25e982f7', '5d8ccb6c-19a2-5e6d-87f5-6aa97cd3d35b', '8212512f-fa09-5e39-a309-e9239658d2b2', 8, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('bbd43c7b-762f-5386-84d8-19e2c51b38e8', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Quiz: Deployments & Workload Controllers', 'assessment', 7, 12, 'e3a128e6-a878-5c99-8f3d-da4b25e982f7')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Services & Networking
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('aa6659d6-a9c3-5d97-b61f-bf8f18a918fb', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Services & Networking', 4)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('21b32b81-f51b-5566-9ed3-ed9d5bebaefe', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'aa6659d6-a9c3-5d97-b61f-bf8f18a918fb', 'Services, DNS and Ingress', 'notes', 0, $md$Pods get a new IP address every time they are recreated, and a Deployment may have many of them. So how does a frontend find its backend, and how do users on the internet reach your app? This lesson answers both: **Services** inside the cluster and **Ingress** (or Gateway API) at the edge.

## The Kubernetes network model

A few rules hold in every Kubernetes cluster:

- **Every pod gets its own IP address.**
- **Every pod can reach every other pod** by that IP, on any node, without NAT. (A network plugin, called a CNI plugin, such as Calico, Cilium or Flannel, makes this work.)
- Containers inside one pod share that IP and talk over `localhost`.

The problem is that pod IPs are **not stable**. Scale, update, or crash, and pods come back with new IPs. You need a fixed address in front of a changing group of pods. That fixed address is a **Service**.

```knowledge-check
{ "questions": [
  { "id": "k8s-net-model-q1", "type": "mcq",
    "prompt": "Why shouldn't a frontend call a backend pod by its IP address?",
    "options": [
      {"id": "a", "text": "Pod IPs are not reachable from other pods"},
      {"id": "b", "text": "Pod IPs change whenever pods are recreated, so the address would break"},
      {"id": "c", "text": "Pods do not have IP addresses"},
      {"id": "d", "text": "Only nodes have IPs in Kubernetes"}
    ],
    "correct": "b",
    "explanation": "Pods can reach each other by IP, but those IPs change. A Service gives a stable name and IP in front of them." }
] }
```

## What a Service is

Think of a company's single reception phone number. Callers always dial the same number, but the receptionist forwards each call to whichever employee is free right now. Employees can change desks or go on leave; the number in front of them never changes. A Service is that number for a group of pods.

A **Service** gives a group of pods one stable virtual IP (the **ClusterIP**) and one stable DNS name. It picks its pods with a **label selector** and spreads traffic across the ones that are ready.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  type: ClusterIP          # the default
  selector:
    app: backend           # send traffic to pods labeled app=backend
  ports:
  - protocol: TCP
    port: 5000             # the port clients connect to on the Service
    targetPort: 5000       # the port the container listens on
```

Three port names you must not mix up:

| Field | Meaning |
|---|---|
| `port` | The port of the Service itself. Clients use `backend:5000`. |
| `targetPort` | The port on the pod where traffic is sent. It can differ from `port`, or be a named container port. |
| `nodePort` | Only for NodePort/LoadBalancer: the port opened on every node (range 30000–32767). |

Behind the scenes Kubernetes keeps an **EndpointSlice** (older name: Endpoints) listing the IPs of the matching, *ready* pods. `kube-proxy` on every node turns the Service IP into those pod IPs.

```bash
kubectl get svc backend
kubectl get endpoints backend          # the pod IPs behind the Service
kubectl describe svc backend
```

**If the endpoint list is empty, the Service matches no ready pods.** The cause is almost always a selector that does not match the pod labels, a wrong `targetPort`, or pods that are not ready. This is the first thing to check when "the Service doesn't work".

```knowledge-check
{ "questions": [
  { "id": "k8s-net-svc-q1", "type": "mcq",
    "prompt": "A Service has port: 80 and targetPort: 8080. A client calls the Service on port 80. Which port receives the traffic in the container?",
    "options": [
      {"id": "a", "text": "80"},
      {"id": "b", "text": "8080"},
      {"id": "c", "text": "A random NodePort"},
      {"id": "d", "text": "Both 80 and 8080"}
    ],
    "correct": "b",
    "explanation": "port is what clients use on the Service; targetPort is where the Service sends traffic on the pod." },
  { "id": "k8s-net-svc-q2", "type": "mcq",
    "prompt": "`kubectl get endpoints api` shows `<none>`. What is the most likely problem?",
    "options": [
      {"id": "a", "text": "The cluster DNS is down"},
      {"id": "b", "text": "The Service's selector matches no ready pods"},
      {"id": "c", "text": "The Service type must be LoadBalancer"},
      {"id": "d", "text": "The node has no public IP"}
    ],
    "correct": "b",
    "explanation": "Endpoints list the ready pods that match the selector. Empty means a label mismatch or pods that are not ready." }
] }
```

## Service DNS names

Every cluster runs a DNS server (CoreDNS). Each Service gets a name:

```
<service>.<namespace>.svc.cluster.local
```

- From a pod **in the same namespace**, just use `backend`.
- From **another namespace**, use `backend.prod` (or the full name).

Try it from a throwaway pod:

```bash
kubectl run tmp --rm -it --image=busybox:1.36 -- sh
/ # nslookup backend
/ # wget -qO- http://backend:5000
```

This is why apps in Kubernetes use Service names in their config (`DB_HOST=postgres`) instead of IPs.

```knowledge-check
{ "questions": [
  { "id": "k8s-net-dns-q1", "type": "mcq",
    "prompt": "A pod in namespace `web` needs to reach Service `db` in namespace `data`. Which name works?",
    "options": [
      {"id": "a", "text": "db"},
      {"id": "b", "text": "db.data"},
      {"id": "c", "text": "data.db"},
      {"id": "d", "text": "web.db"}
    ],
    "correct": "b",
    "explanation": "A short name only resolves inside the same namespace. Across namespaces use <service>.<namespace>, or the full db.data.svc.cluster.local." }
] }
```

## Service types

**ClusterIP** (default): reachable only from inside the cluster. Use it for internal parts: backends, databases, caches.

**NodePort**: everything ClusterIP does, plus a port (30000–32767) opened on **every node**. Anyone who can reach a node's IP can use `<NodeIP>:<nodePort>`. Good for testing and on-prem setups, but you must handle node IPs and the odd port range yourself.

```yaml
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080        # optional; Kubernetes picks one if you leave it out
```

On minikube, `minikube service frontend --url` gives you a reachable address.

**LoadBalancer**: everything NodePort does, plus the **cloud provider** creates an external load balancer with a public IP. This is the usual way to expose one service on EKS/GKE/AKS. On a laptop cluster the `EXTERNAL-IP` stays `<pending>` because there is no cloud to create it (MetalLB or `minikube tunnel` can fill that gap).

**ExternalName**: no pods at all. A DNS alias to an outside name, for example `externalName: db.mindforge.test`.

Each type builds on the previous one: LoadBalancer ⊃ NodePort ⊃ ClusterIP.

Creating a Service imperatively:

```bash
kubectl expose deployment frontend --type=NodePort --port=80 --name=frontend
```

`expose` copies the Deployment's selector for you, which avoids label typos.

```knowledge-check
{ "questions": [
  { "id": "k8s-net-types-q1", "type": "mcq",
    "prompt": "An internal Redis cache must be reachable by your API pods but never from outside the cluster. Which Service type fits?",
    "options": [
      {"id": "a", "text": "ClusterIP"},
      {"id": "b", "text": "NodePort"},
      {"id": "c", "text": "LoadBalancer"},
      {"id": "d", "text": "ExternalName"}
    ],
    "correct": "a",
    "explanation": "ClusterIP is only reachable inside the cluster, which is exactly right for internal dependencies." },
  { "id": "k8s-net-types-q2", "type": "mcq",
    "prompt": "On a local minikube cluster, a LoadBalancer Service shows EXTERNAL-IP <pending> forever. Why?",
    "options": [
      {"id": "a", "text": "The YAML is invalid"},
      {"id": "b", "text": "There is no cloud provider to create the external load balancer"},
      {"id": "c", "text": "LoadBalancer only works with StatefulSets"},
      {"id": "d", "text": "The selector is wrong"}
    ],
    "correct": "b",
    "explanation": "A cloud controller creates the external load balancer. Locally, use minikube tunnel, MetalLB, or a NodePort instead." }
] }
```

## Ingress: many apps behind one entry point

One LoadBalancer per service gets expensive and messy. Think of a large office building with one receptionist at the main entrance: every visitor walks in through the same door, and the receptionist looks at who they are asking for and sends them to the right floor. An **Ingress** does the same for HTTP(S) traffic, routing it from **one** entry point to many Services based on the **host name** and **URL path**:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: appingress
spec:
  ingressClassName: nginx          # which ingress controller should handle this
  rules:
  - host: webapp.com
    http:
      paths:
      - path: /blue
        pathType: Prefix
        backend:
          service:
            name: bluesvc
            port:
              number: 80
      - path: /green
        pathType: Prefix
        backend:
          service:
            name: greensvc
            port:
              number: 80
  - host: todoapp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: todosvc
            port:
              number: 80
```

Requests to `webapp.com/blue` go to `bluesvc`, `webapp.com/green` to `greensvc`, and `todoapp.com` to `todosvc`.

Important points:

- **An Ingress object does nothing on its own.** An **ingress controller** (a reverse proxy running in the cluster, for example Traefik, HAProxy, or a cloud load balancer controller) reads Ingress objects and does the actual routing. You install the controller once per cluster (`minikube addons enable ingress` on minikube). `ingressClassName` says which controller is responsible.
- `pathType: Prefix` matches the path and everything under it; `Exact` matches only that exact path.
- The backend Services are normally ClusterIP. Only the controller is exposed to the outside.
- To test host names locally, point them to the cluster IP in your hosts file (`/etc/hosts`, or `C:\Windows\System32\drivers\etc\hosts` on Windows) or use `curl -H "Host: webapp.com" http://<ip>/blue`.

**TLS (HTTPS)**: store the certificate in a Secret of type `kubernetes.io/tls` and reference it:

```yaml
spec:
  tls:
  - hosts: ["webapp.com"]
    secretName: webapp-tls
```

In practice, **cert-manager** requests and renews free certificates (for example from Let's Encrypt) automatically.

Controller-specific features are set with annotations, for example `nginx.ingress.kubernetes.io/rewrite-target`. These annotations only work with that controller.

```knowledge-check
{ "questions": [
  { "id": "k8s-net-ingress-q1", "type": "mcq",
    "prompt": "You applied an Ingress, but no traffic is routed and its ADDRESS stays empty. What is most likely missing?",
    "options": [
      {"id": "a", "text": "A NodePort on every backend Service"},
      {"id": "b", "text": "An ingress controller running in the cluster"},
      {"id": "c", "text": "A StatefulSet"},
      {"id": "d", "text": "A second Ingress with the same host"}
    ],
    "correct": "b",
    "explanation": "Ingress objects are just routing rules. A controller must be installed to read them and do the routing." },
  { "id": "k8s-net-ingress-q2", "type": "mcq",
    "prompt": "What is the main advantage of one Ingress over one LoadBalancer Service per app?",
    "options": [
      {"id": "a", "text": "It gives each pod a public IP"},
      {"id": "b", "text": "Many apps share one entry point and are routed by host name and path"},
      {"id": "c", "text": "It removes the need for Services"},
      {"id": "d", "text": "It works for UDP traffic only"}
    ],
    "correct": "b",
    "explanation": "An Ingress routes HTTP(S) by host and path to many ClusterIP Services behind a single load balancer." }
] }
```

## Gateway API: the successor to Ingress

**Gateway API** is the newer, official Kubernetes API for traffic routing. It splits responsibilities into separate objects:

- **GatewayClass**: which implementation (like `ingressClassName`).
- **Gateway**: the entry point: listeners, ports, TLS. Usually owned by the platform team.
- **HTTPRoute** (also GRPCRoute, TLSRoute...): routing rules, owned by app teams.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: blue-route
spec:
  parentRefs:
  - name: main-gateway           # attach to this Gateway
  hostnames: ["webapp.com"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /blue
    backendRefs:
    - name: bluesvc
      port: 80
```

It supports things Ingress needed vendor annotations for, such as header matching and weighted traffic splitting (useful for canary releases). The popular `ingress-nginx` controller project has been retired, so new clusters increasingly use Gateway API implementations (Envoy Gateway, Traefik, Cilium, Istio, or the cloud providers' own). The Ingress API itself still works and you will see it everywhere, so learn both.

```knowledge-check
{ "questions": [
  { "id": "k8s-net-gateway-q1", "type": "mcq",
    "prompt": "In Gateway API, which object do application teams usually write to route /api to their Service?",
    "options": [
      {"id": "a", "text": "GatewayClass"},
      {"id": "b", "text": "Gateway"},
      {"id": "c", "text": "HTTPRoute"},
      {"id": "d", "text": "EndpointSlice"}
    ],
    "correct": "c",
    "explanation": "HTTPRoute holds the routing rules and attaches to a Gateway. The Gateway (entry point) and GatewayClass (implementation) are usually managed by the platform team." }
] }
```

## NetworkPolicy: controlling who can talk to whom

By default **every pod can reach every other pod** in the cluster, across namespaces. A **NetworkPolicy** restricts that. Once a policy selects a pod, only the traffic the policy allows can reach it:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-frontend
spec:
  podSelector:
    matchLabels:
      app: backend            # this policy protects backend pods
  policyTypes: ["Ingress"]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend       # only frontend pods may connect
    ports:
    - port: 5000
```

NetworkPolicies are enforced by the network plugin. Calico and Cilium support them; some simple plugins (like basic Flannel) silently ignore them.

```knowledge-check
{ "questions": [
  { "id": "k8s-net-netpol-q1", "type": "mcq",
    "prompt": "With no NetworkPolicies in the cluster, which pods can reach a database pod?",
    "options": [
      {"id": "a", "text": "Only pods in the same namespace"},
      {"id": "b", "text": "Only pods on the same node"},
      {"id": "c", "text": "Every pod in the cluster"},
      {"id": "d", "text": "No pods until a Service exists"}
    ],
    "correct": "c",
    "explanation": "Kubernetes networking is open by default. NetworkPolicies are how you restrict it, and they need a network plugin that enforces them." }
] }
```

## Interview questions and real-world scenarios

**Q: Explain how traffic reaches a pod through a Service.**
The client resolves the Service name via CoreDNS to the ClusterIP. kube-proxy's iptables/IPVS rules (or eBPF with Cilium) on the node rewrite the destination to one of the ready pod IPs from the EndpointSlice. The CNI routes it to that pod.

**Q: ClusterIP vs NodePort vs LoadBalancer?**
Internal only; port on every node; cloud load balancer in front of NodePorts. Each builds on the previous one.

**Q: Ingress vs Service of type LoadBalancer?**
LoadBalancer: one external L4 entry per Service. Ingress: HTTP(S) routing by host/path to many Services through one controller, with TLS termination.

**Q: How would you restrict traffic between namespaces?**
NetworkPolicies (default-deny, then allow specific pod/namespace selectors), enforced by a CNI that supports them (Calico, Cilium).

**Q: What is kube-proxy's role, and can a cluster work without it?**
It implements Service virtual IPs on each node. Some CNIs (Cilium) replace it entirely with eBPF.

**Real-world scenario: "Service X can't reach the database."**
Check: DNS name and namespace (`db.data`), endpoints of the DB Service, a NetworkPolicy blocking it, the DB listening on 0.0.0.0, the right port, and credentials. Test from a debug pod in the same namespace as the caller.

**Real-world scenario: the site works by IP but not by domain name over HTTPS.**
DNS record, Ingress host rule and TLS Secret must all match the domain; with cert-manager, check the Certificate and Challenge objects for errors.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-net-int-q1",
      "type": "mcq",
      "prompt": "Pods in namespace web cannot reach Service db in namespace data, but pods inside data can. DNS resolves fine. What is the most likely cause?",
      "options": [
        {
          "id": "a",
          "text": "The Service type is ClusterIP"
        },
        {
          "id": "b",
          "text": "A NetworkPolicy in data only allows traffic from its own namespace"
        },
        {
          "id": "c",
          "text": "CoreDNS is down"
        },
        {
          "id": "d",
          "text": "The pods have no labels"
        }
      ],
      "correct": "b",
      "explanation": "Cross-namespace traffic is allowed by default, so a failure that only affects other namespaces points to a NetworkPolicy."
    }
  ]
}
```
$md$, 55, $json$[{"id":"k8s-net-model-q1","type":"mcq","correct":"b"},{"id":"k8s-net-svc-q1","type":"mcq","correct":"b"},{"id":"k8s-net-svc-q2","type":"mcq","correct":"b"},{"id":"k8s-net-dns-q1","type":"mcq","correct":"b"},{"id":"k8s-net-types-q1","type":"mcq","correct":"a"},{"id":"k8s-net-types-q2","type":"mcq","correct":"b"},{"id":"k8s-net-ingress-q1","type":"mcq","correct":"b"},{"id":"k8s-net-ingress-q2","type":"mcq","correct":"b"},{"id":"k8s-net-gateway-q1","type":"mcq","correct":"c"},{"id":"k8s-net-netpol-q1","type":"mcq","correct":"c"},{"id":"k8s-net-int-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('5956dcae-8351-5454-be0e-c6d05eb582ca', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'aa6659d6-a9c3-5d97-b61f-bf8f18a918fb', 'Lab: Services', 'lab', 1, 30)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('e40fae27-5833-5694-8cfc-f35a4bd4756b', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '5956dcae-8351-5454-be0e-c6d05eb582ca', 'module', 'Lab: Services', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/deploy.yaml <<'MFEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    team: development
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    team: development
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: ozgurozturknet/k8s:backend
        ports:
        - containerPort: 5000

MFEOF
chmod 666 /home/labuser/work/deploy.yaml
cat > /home/labuser/work/backend_clusterip.yaml <<'MFEOF'
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - protocol: TCP
    port: 5000
    targetPort: 5000

MFEOF
chmod 666 /home/labuser/work/backend_clusterip.yaml
cat > /home/labuser/work/frontend_lb.yaml <<'MFEOF'
apiVersion: v1
kind: Service
metadata:
  name: frontendlb
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80

MFEOF
chmod 666 /home/labuser/work/frontend_lb.yaml
cat > /home/labuser/work/broken-svc.yaml <<'MFEOF'
# This Service "doesn't work". Find out why and fix it.
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: backnd
  ports:
  - port: 80
    targetPort: 5000

MFEOF
chmod 666 /home/labuser/work/broken-svc.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 60, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '1986f45e-68ad-5486-9598-8d45ae2ff815' AND id NOT IN ('4b01c601-68e8-5392-8c5c-546ac8365006', '1a1eda22-2bef-5bdc-b7c5-9acc745be576', '47347cd4-7393-528c-ad2d-4ae6eb6ca79d', '4cc8a2a4-c4f8-579b-820a-07153829b0bd', '4883df92-dd35-5626-a57c-fe5c1f472221');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '1986f45e-68ad-5486-9598-8d45ae2ff815';
DELETE FROM lab_tasks WHERE lab_id = 'e40fae27-5833-5694-8cfc-f35a4bd4756b' AND id NOT IN ('bb2dc2ec-5657-55b7-8aa8-fedf9f983ec0', 'a7ab2c3c-e87a-5dc2-aebf-d2d0d66b88e3', '09dbde47-b782-549b-80c8-b82be18330d1', 'e5220fe9-908b-5f3d-a210-44deb59236c1', 'ec48f616-233c-5cda-bea1-6172ed29d300');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'e40fae27-5833-5694-8cfc-f35a4bd4756b';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('bb2dc2ec-5657-55b7-8aa8-fedf9f983ec0', 'e40fae27-5833-5694-8cfc-f35a4bd4756b', 1, 'Create the frontend and backend', $md$Apply `deploy.yaml`. It creates two Deployments with 3 pods each. Run `kubectl get pods -o wide --show-labels` and note that each pod has its own IP.$md$, $script$#!/bin/bash
test "$(kubectl get deployment frontend -o jsonpath='{.status.readyReplicas}')" = "3" || exit 1
test "$(kubectl get deployment backend -o jsonpath='{.status.readyReplicas}')" = "3"
$script$, '`kubectl apply -f deploy.yaml`', 'Six pods, six different IPs. These IPs change whenever pods are replaced, which is why you need Services.', 5, false, true),
('a7ab2c3c-e87a-5dc2-aebf-d2d0d66b88e3', 'e40fae27-5833-5694-8cfc-f35a4bd4756b', 2, 'Put a ClusterIP Service in front of the backend', $md$Apply `backend_clusterip.yaml`. Then run `kubectl get endpoints backend` and compare the IPs with `kubectl get pods -l app=backend -o wide`.$md$, $script$#!/bin/bash
test "$(kubectl get svc backend -o jsonpath='{.spec.type}')" = "ClusterIP" || exit 1
test "$(kubectl get endpoints backend -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)" = "3"
$script$, '`kubectl apply -f backend_clusterip.yaml`, then `kubectl get endpoints backend`.', 'The Service matched the 3 pods labeled app=backend. Their IPs appear as endpoints. Inside the cluster, other pods can now call http://backend:5000.', 15, false, true),
('09dbde47-b782-549b-80c8-b82be18330d1', 'e40fae27-5833-5694-8cfc-f35a4bd4756b', 3, 'Expose the frontend with a NodePort', $md$Create a NodePort Service named `frontend` for the `frontend` Deployment on port 80, using `kubectl expose`. Look at the PORT(S) column of `kubectl get svc frontend` to find the node port it got.$md$, $script$#!/bin/bash
test "$(kubectl get svc frontend -o jsonpath='{.spec.type} {.spec.ports[0].port} {.spec.selector.app}')" = "NodePort 80 frontend" || exit 1
P=$(kubectl get svc frontend -o jsonpath='{.spec.ports[0].nodePort}'); [ "$P" -ge 30000 ] && [ "$P" -le 32767 ]
$script$, '`kubectl expose deployment <name> --type=NodePort --port=<port>`', 'expose copied the Deployment''s selector (app=frontend). The PORT(S) column shows 80:3xxxx, meaning Service port 80 and node port 3xxxx, which is opened on every node.', 15, false, false),
('e5220fe9-908b-5f3d-a210-44deb59236c1', 'e40fae27-5833-5694-8cfc-f35a4bd4756b', 4, 'Create a LoadBalancer Service', $md$Apply `frontend_lb.yaml` and look at `kubectl get svc frontendlb`. Why is EXTERNAL-IP stuck on `<pending>`?$md$, $script$#!/bin/bash
test "$(kubectl get svc frontendlb -o jsonpath='{.spec.type}')" = "LoadBalancer"
$script$, '`kubectl apply -f frontend_lb.yaml`', 'There is no cloud provider in this sandbox (or on a laptop), so nobody creates the external load balancer. On EKS/GKE/AKS a public IP would appear within a minute or two.', 10, false, false),
('ec48f616-233c-5cda-bea1-6172ed29d300', 'e40fae27-5833-5694-8cfc-f35a4bd4756b', 5, 'Debug a broken Service', $md$Apply `broken-svc.yaml`. The `api` Service should send traffic to the backend pods, but `kubectl get endpoints api` is empty. Find the bug, fix the file, and apply it again.
$md$, $script$#!/bin/bash
test "$(kubectl get endpoints api -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)" = "3"
$script$, 'Compare the Service''s selector with the labels on the backend pods (`kubectl get pods --show-labels`).', 'The selector said `app=backnd` (a typo), which matches no pods, so the Service had no endpoints. Label/selector mismatches are the most common reason a Service "does not work".', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('1986f45e-68ad-5486-9598-8d45ae2ff815', 'e40fae27-5833-5694-8cfc-f35a4bd4756b', 1, $json$[{"id":"bb2dc2ec-5657-55b7-8aa8-fedf9f983ec0","lab_id":"e40fae27-5833-5694-8cfc-f35a4bd4756b","position":1,"title":"Create the frontend and backend","description":"Apply `deploy.yaml`. It creates two Deployments with 3 pods each. Run `kubectl get pods -o wide --show-labels` and note that each pod has its own IP.","verification_script":"#!/bin/bash\ntest \"$(kubectl get deployment frontend -o jsonpath='{.status.readyReplicas}')\" = \"3\" || exit 1\ntest \"$(kubectl get deployment backend -o jsonpath='{.status.readyReplicas}')\" = \"3\"\n","hint_context":"`kubectl apply -f deploy.yaml`","explanation_context":"Six pods, six different IPs. These IPs change whenever pods are replaced, which is why you need Services.","points":5,"is_optional":false,"is_stateful":true},{"id":"a7ab2c3c-e87a-5dc2-aebf-d2d0d66b88e3","lab_id":"e40fae27-5833-5694-8cfc-f35a4bd4756b","position":2,"title":"Put a ClusterIP Service in front of the backend","description":"Apply `backend_clusterip.yaml`. Then run `kubectl get endpoints backend` and compare the IPs with `kubectl get pods -l app=backend -o wide`.","verification_script":"#!/bin/bash\ntest \"$(kubectl get svc backend -o jsonpath='{.spec.type}')\" = \"ClusterIP\" || exit 1\ntest \"$(kubectl get endpoints backend -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)\" = \"3\"\n","hint_context":"`kubectl apply -f backend_clusterip.yaml`, then `kubectl get endpoints backend`.","explanation_context":"The Service matched the 3 pods labeled app=backend. Their IPs appear as endpoints. Inside the cluster, other pods can now call http://backend:5000.","points":15,"is_optional":false,"is_stateful":true},{"id":"09dbde47-b782-549b-80c8-b82be18330d1","lab_id":"e40fae27-5833-5694-8cfc-f35a4bd4756b","position":3,"title":"Expose the frontend with a NodePort","description":"Create a NodePort Service named `frontend` for the `frontend` Deployment on port 80, using `kubectl expose`. Look at the PORT(S) column of `kubectl get svc frontend` to find the node port it got.","verification_script":"#!/bin/bash\ntest \"$(kubectl get svc frontend -o jsonpath='{.spec.type} {.spec.ports[0].port} {.spec.selector.app}')\" = \"NodePort 80 frontend\" || exit 1\nP=$(kubectl get svc frontend -o jsonpath='{.spec.ports[0].nodePort}'); [ \"$P\" -ge 30000 ] \u0026\u0026 [ \"$P\" -le 32767 ]\n","hint_context":"`kubectl expose deployment \u003cname\u003e --type=NodePort --port=\u003cport\u003e`","explanation_context":"expose copied the Deployment's selector (app=frontend). The PORT(S) column shows 80:3xxxx, meaning Service port 80 and node port 3xxxx, which is opened on every node.","points":15,"is_optional":false,"is_stateful":false},{"id":"e5220fe9-908b-5f3d-a210-44deb59236c1","lab_id":"e40fae27-5833-5694-8cfc-f35a4bd4756b","position":4,"title":"Create a LoadBalancer Service","description":"Apply `frontend_lb.yaml` and look at `kubectl get svc frontendlb`. Why is EXTERNAL-IP stuck on `\u003cpending\u003e`?","verification_script":"#!/bin/bash\ntest \"$(kubectl get svc frontendlb -o jsonpath='{.spec.type}')\" = \"LoadBalancer\"\n","hint_context":"`kubectl apply -f frontend_lb.yaml`","explanation_context":"There is no cloud provider in this sandbox (or on a laptop), so nobody creates the external load balancer. On EKS/GKE/AKS a public IP would appear within a minute or two.","points":10,"is_optional":false,"is_stateful":false},{"id":"ec48f616-233c-5cda-bea1-6172ed29d300","lab_id":"e40fae27-5833-5694-8cfc-f35a4bd4756b","position":5,"title":"Debug a broken Service","description":"Apply `broken-svc.yaml`. The `api` Service should send traffic to the backend pods, but `kubectl get endpoints api` is empty. Find the bug, fix the file, and apply it again.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get endpoints api -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)\" = \"3\"\n","hint_context":"Compare the Service's selector with the labels on the backend pods (`kubectl get pods --show-labels`).","explanation_context":"The selector said `app=backnd` (a typo), which matches no pods, so the Service had no endpoints. Label/selector mismatches are the most common reason a Service \"does not work\".","points":20,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('4b01c601-68e8-5392-8c5c-546ac8365006', '1986f45e-68ad-5486-9598-8d45ae2ff815', 'bb2dc2ec-5657-55b7-8aa8-fedf9f983ec0', 1, 'Create the frontend and backend', $md$Apply `deploy.yaml`. It creates two Deployments with 3 pods each. Run `kubectl get pods -o wide --show-labels` and note that each pod has its own IP.$md$, $script$#!/bin/bash
test "$(kubectl get deployment frontend -o jsonpath='{.status.readyReplicas}')" = "3" || exit 1
test "$(kubectl get deployment backend -o jsonpath='{.status.readyReplicas}')" = "3"
$script$, '`kubectl apply -f deploy.yaml`', 'Six pods, six different IPs. These IPs change whenever pods are replaced, which is why you need Services.', 5, false, true),
('1a1eda22-2bef-5bdc-b7c5-9acc745be576', '1986f45e-68ad-5486-9598-8d45ae2ff815', 'a7ab2c3c-e87a-5dc2-aebf-d2d0d66b88e3', 2, 'Put a ClusterIP Service in front of the backend', $md$Apply `backend_clusterip.yaml`. Then run `kubectl get endpoints backend` and compare the IPs with `kubectl get pods -l app=backend -o wide`.$md$, $script$#!/bin/bash
test "$(kubectl get svc backend -o jsonpath='{.spec.type}')" = "ClusterIP" || exit 1
test "$(kubectl get endpoints backend -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)" = "3"
$script$, '`kubectl apply -f backend_clusterip.yaml`, then `kubectl get endpoints backend`.', 'The Service matched the 3 pods labeled app=backend. Their IPs appear as endpoints. Inside the cluster, other pods can now call http://backend:5000.', 15, false, true),
('47347cd4-7393-528c-ad2d-4ae6eb6ca79d', '1986f45e-68ad-5486-9598-8d45ae2ff815', '09dbde47-b782-549b-80c8-b82be18330d1', 3, 'Expose the frontend with a NodePort', $md$Create a NodePort Service named `frontend` for the `frontend` Deployment on port 80, using `kubectl expose`. Look at the PORT(S) column of `kubectl get svc frontend` to find the node port it got.$md$, $script$#!/bin/bash
test "$(kubectl get svc frontend -o jsonpath='{.spec.type} {.spec.ports[0].port} {.spec.selector.app}')" = "NodePort 80 frontend" || exit 1
P=$(kubectl get svc frontend -o jsonpath='{.spec.ports[0].nodePort}'); [ "$P" -ge 30000 ] && [ "$P" -le 32767 ]
$script$, '`kubectl expose deployment <name> --type=NodePort --port=<port>`', 'expose copied the Deployment''s selector (app=frontend). The PORT(S) column shows 80:3xxxx, meaning Service port 80 and node port 3xxxx, which is opened on every node.', 15, false, false),
('4cc8a2a4-c4f8-579b-820a-07153829b0bd', '1986f45e-68ad-5486-9598-8d45ae2ff815', 'e5220fe9-908b-5f3d-a210-44deb59236c1', 4, 'Create a LoadBalancer Service', $md$Apply `frontend_lb.yaml` and look at `kubectl get svc frontendlb`. Why is EXTERNAL-IP stuck on `<pending>`?$md$, $script$#!/bin/bash
test "$(kubectl get svc frontendlb -o jsonpath='{.spec.type}')" = "LoadBalancer"
$script$, '`kubectl apply -f frontend_lb.yaml`', 'There is no cloud provider in this sandbox (or on a laptop), so nobody creates the external load balancer. On EKS/GKE/AKS a public IP would appear within a minute or two.', 10, false, false),
('4883df92-dd35-5626-a57c-fe5c1f472221', '1986f45e-68ad-5486-9598-8d45ae2ff815', 'ec48f616-233c-5cda-bea1-6172ed29d300', 5, 'Debug a broken Service', $md$Apply `broken-svc.yaml`. The `api` Service should send traffic to the backend pods, but `kubectl get endpoints api` is empty. Find the bug, fix the file, and apply it again.
$md$, $script$#!/bin/bash
test "$(kubectl get endpoints api -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)" = "3"
$script$, 'Compare the Service''s selector with the labels on the backend pods (`kubectl get pods --show-labels`).', 'The selector said `app=backnd` (a typo), which matches no pods, so the Service had no endpoints. Label/selector mismatches are the most common reason a Service "does not work".', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '1986f45e-68ad-5486-9598-8d45ae2ff815', updated_at = now()
WHERE id = 'e40fae27-5833-5694-8cfc-f35a4bd4756b' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('a3455546-475e-53a2-9b66-2f2582784d4f', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'aa6659d6-a9c3-5d97-b61f-bf8f18a918fb', 'Lab: Ingress', 'lab', 2, 25)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('515305f6-49ab-5164-9365-5d57c0e9654b', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'a3455546-475e-53a2-9b66-2f2582784d4f', 'module', 'Lab: Ingress', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/deploy.yaml <<'MFEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blueapp
  labels:
    app: blue
spec:
  replicas: 2
  selector:
    matchLabels:
      app: blue
  template:
    metadata:
      labels:
        app: blue
    spec:
      containers:
      - name: blueapp
        image: ozgurozturknet/k8s:blue
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: bluesvc
spec:
  selector:
    app: blue
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: greenapp
  labels:
    app: green
spec:
  replicas: 2
  selector:
    matchLabels:
      app: green
  template:
    metadata:
      labels:
        app: green
    spec:
      containers:
      - name: greenapp
        image: ozgurozturknet/k8s:green
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: greensvc
spec:
  selector:
    app: green
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todoapp
  labels:
    app: todo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: todo
  template:
    metadata:
      labels:
        app: todo
    spec:
      containers:
      - name: todoapp
        image: ozgurozturknet/samplewebapp:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: todosvc
spec:
  selector:
    app: todo
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80

MFEOF
chmod 666 /home/labuser/work/deploy.yaml
cat > /home/labuser/work/appingress.yaml <<'MFEOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: appingress
spec:
  ingressClassName: nginx
  rules:
  - host: webapp.com
    http:
      paths:
      - path: /blue
        pathType: Prefix
        backend:
          service:
            name: bluesvc
            port:
              number: 80
      - path: /green
        pathType: Prefix
        backend:
          service:
            name: greensvc
            port:
              number: 80

MFEOF
chmod 666 /home/labuser/work/appingress.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '2b872fd0-5356-53b5-b6d5-5f5b1a03ce39' AND id NOT IN ('74dd584f-3c0c-507a-a7d0-e22587e424c0', '65169414-5093-5d3e-b80f-dd367fe7de59', 'dde498fb-080a-599f-b3ee-e593bf337f79', '81666eed-5018-55c9-be47-d2cf6147c3f6');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '2b872fd0-5356-53b5-b6d5-5f5b1a03ce39';
DELETE FROM lab_tasks WHERE lab_id = '515305f6-49ab-5164-9365-5d57c0e9654b' AND id NOT IN ('4123fc6c-d835-5ee8-8e36-5071a10a1060', '8fc3e7ad-e0b4-55d9-b381-fa35ff035feb', '7bf86478-d659-5582-b3af-ba41b72c80d3', '5de9764e-2013-5118-a1f6-ab63e991317c');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '515305f6-49ab-5164-9365-5d57c0e9654b';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('4123fc6c-d835-5ee8-8e36-5071a10a1060', '515305f6-49ab-5164-9365-5d57c0e9654b', 1, 'Create the apps and their Services', $md$Apply `deploy.yaml`. It creates three apps (blue, green, todo), each with a ClusterIP Service. Check with `kubectl get deploy,svc`.$md$, $script$#!/bin/bash
for s in bluesvc greensvc todosvc; do
  test -n "$(kubectl get endpoints $s -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)" || exit 1
done
$script$, '`kubectl apply -f deploy.yaml`', 'All three Services are ClusterIP, so none of them is reachable from outside yet. The Ingress will be the single way in.', 5, false, true),
('8fc3e7ad-e0b4-55d9-b381-fa35ff035feb', '515305f6-49ab-5164-9365-5d57c0e9654b', 2, 'Route by path', $md$Apply `appingress.yaml` and run `kubectl describe ingress appingress` to read its rules: `webapp.com/blue` goes to `bluesvc` and `webapp.com/green` to `greensvc`.

This sandbox has no ingress controller, so the ADDRESS column stays empty and no traffic flows. The rules are still stored and validated, exactly as on a real cluster.
$md$, $script$#!/bin/bash
test "$(kubectl get ingress appingress -o jsonpath='{.spec.rules[0].host} {.spec.rules[0].http.paths[*].backend.service.name}')" = "webapp.com bluesvc greensvc"
$script$, '`kubectl apply -f appingress.yaml`', 'One host, two paths, two Services. An ingress controller (installed once per cluster) would read these rules and route traffic.', 15, false, true),
('7bf86478-d659-5582-b3af-ba41b72c80d3', '515305f6-49ab-5164-9365-5d57c0e9654b', 3, 'Write a host-based Ingress', $md$Write `todoingress.yaml`: an Ingress named `todoingress` with `ingressClassName: nginx` that sends **all** paths of the host `todoapp.com` to the Service `todosvc` on port 80. Apply it.
$md$, $script$#!/bin/bash
test "$(kubectl get ingress todoingress -o jsonpath='{.spec.rules[0].host} {.spec.rules[0].http.paths[0].path} {.spec.rules[0].http.paths[0].pathType} {.spec.rules[0].http.paths[0].backend.service.name} {.spec.rules[0].http.paths[0].backend.service.port.number}')" = "todoapp.com / Prefix todosvc 80"
$script$, 'Copy the structure of appingress.yaml. Use path `/` with pathType `Prefix` to match everything.', '`path: /` with `pathType: Prefix` matches every URL on that host. Different hosts can share one ingress controller and one public IP.', 20, false, true),
('5de9764e-2013-5118-a1f6-ab63e991317c', '515305f6-49ab-5164-9365-5d57c0e9654b', 4, 'Add HTTPS', $md$Create a self-signed certificate and store it in a TLS Secret named `todo-tls`:
```
openssl req -x509 -nodes -days 30 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=todoapp.com"
kubectl create secret tls todo-tls --cert=tls.crt --key=tls.key
```
Then add a `tls` section to `todoingress` for host `todoapp.com` using that Secret, and apply it again.
$md$, $script$#!/bin/bash
test "$(kubectl get secret todo-tls -o jsonpath='{.type}')" = "kubernetes.io/tls" || exit 1
test "$(kubectl get ingress todoingress -o jsonpath='{.spec.tls[0].secretName} {.spec.tls[0].hosts[0]}')" = "todo-tls todoapp.com"
$script$, 'Under `spec`, add `tls:` with a list item that has `hosts: ["todoapp.com"]` and `secretName: todo-tls`.', 'The ingress controller would serve HTTPS for todoapp.com with that certificate. In real clusters cert-manager creates and renews these Secrets for you.', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('2b872fd0-5356-53b5-b6d5-5f5b1a03ce39', '515305f6-49ab-5164-9365-5d57c0e9654b', 1, $json$[{"id":"4123fc6c-d835-5ee8-8e36-5071a10a1060","lab_id":"515305f6-49ab-5164-9365-5d57c0e9654b","position":1,"title":"Create the apps and their Services","description":"Apply `deploy.yaml`. It creates three apps (blue, green, todo), each with a ClusterIP Service. Check with `kubectl get deploy,svc`.","verification_script":"#!/bin/bash\nfor s in bluesvc greensvc todosvc; do\n  test -n \"$(kubectl get endpoints $s -o jsonpath='{.subsets[0].addresses[0].ip}' 2\u003e/dev/null)\" || exit 1\ndone\n","hint_context":"`kubectl apply -f deploy.yaml`","explanation_context":"All three Services are ClusterIP, so none of them is reachable from outside yet. The Ingress will be the single way in.","points":5,"is_optional":false,"is_stateful":true},{"id":"8fc3e7ad-e0b4-55d9-b381-fa35ff035feb","lab_id":"515305f6-49ab-5164-9365-5d57c0e9654b","position":2,"title":"Route by path","description":"Apply `appingress.yaml` and run `kubectl describe ingress appingress` to read its rules: `webapp.com/blue` goes to `bluesvc` and `webapp.com/green` to `greensvc`.\n\nThis sandbox has no ingress controller, so the ADDRESS column stays empty and no traffic flows. The rules are still stored and validated, exactly as on a real cluster.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get ingress appingress -o jsonpath='{.spec.rules[0].host} {.spec.rules[0].http.paths[*].backend.service.name}')\" = \"webapp.com bluesvc greensvc\"\n","hint_context":"`kubectl apply -f appingress.yaml`","explanation_context":"One host, two paths, two Services. An ingress controller (installed once per cluster) would read these rules and route traffic.","points":15,"is_optional":false,"is_stateful":true},{"id":"7bf86478-d659-5582-b3af-ba41b72c80d3","lab_id":"515305f6-49ab-5164-9365-5d57c0e9654b","position":3,"title":"Write a host-based Ingress","description":"Write `todoingress.yaml`: an Ingress named `todoingress` with `ingressClassName: nginx` that sends **all** paths of the host `todoapp.com` to the Service `todosvc` on port 80. Apply it.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get ingress todoingress -o jsonpath='{.spec.rules[0].host} {.spec.rules[0].http.paths[0].path} {.spec.rules[0].http.paths[0].pathType} {.spec.rules[0].http.paths[0].backend.service.name} {.spec.rules[0].http.paths[0].backend.service.port.number}')\" = \"todoapp.com / Prefix todosvc 80\"\n","hint_context":"Copy the structure of appingress.yaml. Use path `/` with pathType `Prefix` to match everything.","explanation_context":"`path: /` with `pathType: Prefix` matches every URL on that host. Different hosts can share one ingress controller and one public IP.","points":20,"is_optional":false,"is_stateful":true},{"id":"5de9764e-2013-5118-a1f6-ab63e991317c","lab_id":"515305f6-49ab-5164-9365-5d57c0e9654b","position":4,"title":"Add HTTPS","description":"Create a self-signed certificate and store it in a TLS Secret named `todo-tls`:\n```\nopenssl req -x509 -nodes -days 30 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj \"/CN=todoapp.com\"\nkubectl create secret tls todo-tls --cert=tls.crt --key=tls.key\n```\nThen add a `tls` section to `todoingress` for host `todoapp.com` using that Secret, and apply it again.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get secret todo-tls -o jsonpath='{.type}')\" = \"kubernetes.io/tls\" || exit 1\ntest \"$(kubectl get ingress todoingress -o jsonpath='{.spec.tls[0].secretName} {.spec.tls[0].hosts[0]}')\" = \"todo-tls todoapp.com\"\n","hint_context":"Under `spec`, add `tls:` with a list item that has `hosts: [\"todoapp.com\"]` and `secretName: todo-tls`.","explanation_context":"The ingress controller would serve HTTPS for todoapp.com with that certificate. In real clusters cert-manager creates and renews these Secrets for you.","points":20,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('74dd584f-3c0c-507a-a7d0-e22587e424c0', '2b872fd0-5356-53b5-b6d5-5f5b1a03ce39', '4123fc6c-d835-5ee8-8e36-5071a10a1060', 1, 'Create the apps and their Services', $md$Apply `deploy.yaml`. It creates three apps (blue, green, todo), each with a ClusterIP Service. Check with `kubectl get deploy,svc`.$md$, $script$#!/bin/bash
for s in bluesvc greensvc todosvc; do
  test -n "$(kubectl get endpoints $s -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)" || exit 1
done
$script$, '`kubectl apply -f deploy.yaml`', 'All three Services are ClusterIP, so none of them is reachable from outside yet. The Ingress will be the single way in.', 5, false, true),
('65169414-5093-5d3e-b80f-dd367fe7de59', '2b872fd0-5356-53b5-b6d5-5f5b1a03ce39', '8fc3e7ad-e0b4-55d9-b381-fa35ff035feb', 2, 'Route by path', $md$Apply `appingress.yaml` and run `kubectl describe ingress appingress` to read its rules: `webapp.com/blue` goes to `bluesvc` and `webapp.com/green` to `greensvc`.

This sandbox has no ingress controller, so the ADDRESS column stays empty and no traffic flows. The rules are still stored and validated, exactly as on a real cluster.
$md$, $script$#!/bin/bash
test "$(kubectl get ingress appingress -o jsonpath='{.spec.rules[0].host} {.spec.rules[0].http.paths[*].backend.service.name}')" = "webapp.com bluesvc greensvc"
$script$, '`kubectl apply -f appingress.yaml`', 'One host, two paths, two Services. An ingress controller (installed once per cluster) would read these rules and route traffic.', 15, false, true),
('dde498fb-080a-599f-b3ee-e593bf337f79', '2b872fd0-5356-53b5-b6d5-5f5b1a03ce39', '7bf86478-d659-5582-b3af-ba41b72c80d3', 3, 'Write a host-based Ingress', $md$Write `todoingress.yaml`: an Ingress named `todoingress` with `ingressClassName: nginx` that sends **all** paths of the host `todoapp.com` to the Service `todosvc` on port 80. Apply it.
$md$, $script$#!/bin/bash
test "$(kubectl get ingress todoingress -o jsonpath='{.spec.rules[0].host} {.spec.rules[0].http.paths[0].path} {.spec.rules[0].http.paths[0].pathType} {.spec.rules[0].http.paths[0].backend.service.name} {.spec.rules[0].http.paths[0].backend.service.port.number}')" = "todoapp.com / Prefix todosvc 80"
$script$, 'Copy the structure of appingress.yaml. Use path `/` with pathType `Prefix` to match everything.', '`path: /` with `pathType: Prefix` matches every URL on that host. Different hosts can share one ingress controller and one public IP.', 20, false, true),
('81666eed-5018-55c9-be47-d2cf6147c3f6', '2b872fd0-5356-53b5-b6d5-5f5b1a03ce39', '5de9764e-2013-5118-a1f6-ab63e991317c', 4, 'Add HTTPS', $md$Create a self-signed certificate and store it in a TLS Secret named `todo-tls`:
```
openssl req -x509 -nodes -days 30 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=todoapp.com"
kubectl create secret tls todo-tls --cert=tls.crt --key=tls.key
```
Then add a `tls` section to `todoingress` for host `todoapp.com` using that Secret, and apply it again.
$md$, $script$#!/bin/bash
test "$(kubectl get secret todo-tls -o jsonpath='{.type}')" = "kubernetes.io/tls" || exit 1
test "$(kubectl get ingress todoingress -o jsonpath='{.spec.tls[0].secretName} {.spec.tls[0].hosts[0]}')" = "todo-tls todoapp.com"
$script$, 'Under `spec`, add `tls:` with a list item that has `hosts: ["todoapp.com"]` and `secretName: todo-tls`.', 'The ingress controller would serve HTTPS for todoapp.com with that certificate. In real clusters cert-manager creates and renews these Secrets for you.', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '2b872fd0-5356-53b5-b6d5-5f5b1a03ce39', updated_at = now()
WHERE id = '515305f6-49ab-5164-9365-5d57c0e9654b' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('86dec0bf-a9ce-507f-8319-df849b4f01d6', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the main job of a Service?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a3e36abf-bc69-581d-b10b-52565db1e066', '86dec0bf-a9ce-507f-8319-df849b4f01d6', 1, $json${"prompt":"What is the main job of a Service?","multiple":false,"options":[{"id":"a","text":"To build container images","is_correct":false},{"id":"b","text":"To give a changing group of pods one stable IP address and DNS name","is_correct":true},{"id":"c","text":"To store configuration files","is_correct":false},{"id":"d","text":"To schedule pods on nodes","is_correct":false}],"explanation":"Pods come and go with new IPs. A Service selects them by label and gives clients a fixed address."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d7012580-149a-58f3-bd4d-8e982b3b5c72', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which Service type is the default?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5f54da96-9c5b-53bc-aa95-ec867fd8743a', 'd7012580-149a-58f3-bd4d-8e982b3b5c72', 1, $json${"prompt":"Which Service type is the default?","multiple":false,"options":[{"id":"a","text":"NodePort","is_correct":false},{"id":"b","text":"LoadBalancer","is_correct":false},{"id":"c","text":"ClusterIP","is_correct":true},{"id":"d","text":"ExternalName","is_correct":false}],"explanation":"ClusterIP is the default and is only reachable inside the cluster."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2d38036d-37e1-569a-9720-81444f8d4bf3', '00000000-0000-0000-0000-000000000001', 'mcq', 'What port range does Kubernetes use for NodePort by default?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9369c413-692c-5868-8189-f3e0e1fa455b', '2d38036d-37e1-569a-9720-81444f8d4bf3', 1, $json${"prompt":"What port range does Kubernetes use for NodePort by default?","multiple":false,"options":[{"id":"a","text":"1–1024","is_correct":false},{"id":"b","text":"8000–9000","is_correct":false},{"id":"c","text":"30000–32767","is_correct":true},{"id":"d","text":"Any port","is_correct":false}],"explanation":"NodePorts are allocated from 30000–32767 unless the cluster is configured otherwise."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('82155f3a-7b31-5655-a83b-babd5038161a', '00000000-0000-0000-0000-000000000001', 'mcq', 'A pod in namespace `shop` calls `http://payments`. The payments Service is in...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1d1e600a-8545-5d31-8470-b01b98858ed7', '82155f3a-7b31-5655-a83b-babd5038161a', 1, $json${"prompt":"A pod in namespace `shop` calls `http://payments`. The payments Service is in namespace `billing`. What happens?","multiple":false,"options":[{"id":"a","text":"It works, because DNS searches all namespaces","is_correct":false},{"id":"b","text":"It fails to resolve; the pod must use payments.billing (or the full name)","is_correct":true},{"id":"c","text":"It reaches a random Service called payments","is_correct":false},{"id":"d","text":"Kubernetes blocks cross-namespace calls","is_correct":false}],"explanation":"Short names resolve within the caller's own namespace. Use \u003cservice\u003e.\u003cnamespace\u003e across namespaces."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6675ad7d-c359-52ac-9502-2925102489f6', '00000000-0000-0000-0000-000000000001', 'mcq', 'What must be running in the cluster for Ingress rules to route real traffic?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('74a97644-7869-5398-b1b6-5c99bf02567b', '6675ad7d-c359-52ac-9502-2925102489f6', 1, $json${"prompt":"What must be running in the cluster for Ingress rules to route real traffic?","multiple":false,"options":[{"id":"a","text":"An ingress controller","is_correct":true},{"id":"b","text":"A DaemonSet named ingress","is_correct":false},{"id":"c","text":"CoreDNS only","is_correct":false},{"id":"d","text":"A StatefulSet for each backend","is_correct":false}],"explanation":"Ingress objects are only rules. An ingress controller (Traefik, HAProxy, a cloud controller, ...) reads them and routes traffic."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f47618b6-e6ce-547f-a53c-a9146d079048', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which Ingress rule sends every URL of shop.com to the Service shop-svc?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0feb662c-710b-5845-95c0-dc308a166cc3', 'f47618b6-e6ce-547f-a53c-a9146d079048', 1, $json${"prompt":"Which Ingress rule sends every URL of shop.com to the Service shop-svc?","multiple":false,"options":[{"id":"a","text":"host shop.com, path /, pathType Prefix, backend shop-svc","is_correct":true},{"id":"b","text":"host shop.com, path /*, pathType Exact, backend shop-svc","is_correct":false},{"id":"c","text":"host *, path shop.com, backend shop-svc","is_correct":false},{"id":"d","text":"host shop-svc, path /, backend shop.com","is_correct":false}],"explanation":"Prefix / matches every path. Exact would only match the literal path."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('14820f6c-e609-5277-b0ea-2ff9e30ab4e8', '00000000-0000-0000-0000-000000000001', 'mcq', 'In Gateway API, which object defines the routing rules that attach to a Gateway?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('264f642a-ca12-5bf6-9025-57ed44dd39db', '14820f6c-e609-5277-b0ea-2ff9e30ab4e8', 1, $json${"prompt":"In Gateway API, which object defines the routing rules that attach to a Gateway?","multiple":false,"options":[{"id":"a","text":"GatewayClass","is_correct":false},{"id":"b","text":"HTTPRoute","is_correct":true},{"id":"c","text":"IngressClass","is_correct":false},{"id":"d","text":"EndpointSlice","is_correct":false}],"explanation":"GatewayClass picks the implementation, Gateway is the entry point, and HTTPRoute holds the rules."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('421aff99-230f-5255-8f07-c3ef520c74fa', '00000000-0000-0000-0000-000000000001', 'mcq', 'Without any NetworkPolicy, what traffic between pods is allowed?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('167c53b1-ee5b-54a4-bb8f-f4b72d67c190', '421aff99-230f-5255-8f07-c3ef520c74fa', 1, $json${"prompt":"Without any NetworkPolicy, what traffic between pods is allowed?","multiple":false,"options":[{"id":"a","text":"None","is_correct":false},{"id":"b","text":"Only traffic within one namespace","is_correct":false},{"id":"c","text":"All pod-to-pod traffic in the cluster","is_correct":true},{"id":"d","text":"Only traffic through Services","is_correct":false}],"explanation":"Kubernetes networking is open by default. NetworkPolicies (enforced by the network plugin) restrict it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('466e4c8d-1056-5385-bf0c-f1f7cabfdae9', '00000000-0000-0000-0000-000000000001', 'Quiz: Services & Networking', 'k8s-networking-quiz', 'Quiz covering Services & Networking.', 'mcq', 'published', 'module', '7386fddf-29fb-53da-be8b-aa6c29ccd4a3', 15, 70, 5, 8, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '466e4c8d-1056-5385-bf0c-f1f7cabfdae9' AND question_id NOT IN ('86dec0bf-a9ce-507f-8319-df849b4f01d6', 'd7012580-149a-58f3-bd4d-8e982b3b5c72', '2d38036d-37e1-569a-9720-81444f8d4bf3', '82155f3a-7b31-5655-a83b-babd5038161a', '6675ad7d-c359-52ac-9502-2925102489f6', 'f47618b6-e6ce-547f-a53c-a9146d079048', '14820f6c-e609-5277-b0ea-2ff9e30ab4e8', '421aff99-230f-5255-8f07-c3ef520c74fa');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('7dcb58be-cef3-54fe-9ed3-8668705c4274', '466e4c8d-1056-5385-bf0c-f1f7cabfdae9', '86dec0bf-a9ce-507f-8319-df849b4f01d6', 'a3e36abf-bc69-581d-b10b-52565db1e066', 0, 1),
('d0a35a28-a6e7-50e9-8635-c4ad37c18daf', '466e4c8d-1056-5385-bf0c-f1f7cabfdae9', 'd7012580-149a-58f3-bd4d-8e982b3b5c72', '5f54da96-9c5b-53bc-aa95-ec867fd8743a', 1, 1),
('b1fb5cec-c572-50b5-8db6-3b00e3dd08f5', '466e4c8d-1056-5385-bf0c-f1f7cabfdae9', '2d38036d-37e1-569a-9720-81444f8d4bf3', '9369c413-692c-5868-8189-f3e0e1fa455b', 2, 1),
('d4b354df-6c73-5050-8fad-1ae3c3336822', '466e4c8d-1056-5385-bf0c-f1f7cabfdae9', '82155f3a-7b31-5655-a83b-babd5038161a', '1d1e600a-8545-5d31-8470-b01b98858ed7', 3, 1),
('c3d214da-08c2-53b6-a969-eb7353346975', '466e4c8d-1056-5385-bf0c-f1f7cabfdae9', '6675ad7d-c359-52ac-9502-2925102489f6', '74a97644-7869-5398-b1b6-5c99bf02567b', 4, 1),
('b4247c46-a57f-516e-9c05-8cd274adbc63', '466e4c8d-1056-5385-bf0c-f1f7cabfdae9', 'f47618b6-e6ce-547f-a53c-a9146d079048', '0feb662c-710b-5845-95c0-dc308a166cc3', 5, 1),
('5ee6aa00-d095-538b-8980-2ae5562c1b7a', '466e4c8d-1056-5385-bf0c-f1f7cabfdae9', '14820f6c-e609-5277-b0ea-2ff9e30ab4e8', '264f642a-ca12-5bf6-9025-57ed44dd39db', 6, 1),
('09bf1d12-93e4-5a92-b6ff-58c6e345e914', '466e4c8d-1056-5385-bf0c-f1f7cabfdae9', '421aff99-230f-5255-8f07-c3ef520c74fa', '167c53b1-ee5b-54a4-bb8f-f4b72d67c190', 7, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('7386fddf-29fb-53da-be8b-aa6c29ccd4a3', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'aa6659d6-a9c3-5d97-b61f-bf8f18a918fb', 'Quiz: Services & Networking', 'assessment', 3, 10, '466e4c8d-1056-5385-bf0c-f1f7cabfdae9')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: ConfigMaps & Secrets
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('1c403d8b-6f9e-5fe3-9443-b75a9f3759b4', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'ConfigMaps & Secrets', 5)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('146803ef-fe94-5911-83c6-a3d8d609fe6a', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '1c403d8b-6f9e-5fe3-9443-b75a9f3759b4', 'ConfigMaps and Secrets', 'notes', 0, $md$The same image should run in development, staging and production. What changes between them is **configuration**: database hosts, feature settings, API keys, passwords. Kubernetes keeps these outside the image in two kinds of objects: **ConfigMaps** for normal settings and **Secrets** for sensitive values.

## Why configuration lives outside the image

If you bake a database host into the image, you need a new image for each environment, and a password inside an image can be read by anyone who can pull it. The rule (from the "twelve-factor app" guidelines) is: **build one image, inject config at runtime.**

Kubernetes injects config into a pod in two ways:

1. As **environment variables**.
2. As **files** in a mounted volume.

Both ConfigMaps and Secrets support both ways.

```knowledge-check
{ "questions": [
  { "id": "k8s-cfg-why-q1", "type": "mcq",
    "prompt": "Why keep the database hostname out of the container image?",
    "options": [
      {"id": "a", "text": "Images cannot contain text"},
      {"id": "b", "text": "So the same image can run in every environment with different settings injected at runtime"},
      {"id": "c", "text": "Kubernetes deletes environment variables from images"},
      {"id": "d", "text": "It makes the image build faster"}
    ],
    "correct": "b",
    "explanation": "One image, many environments. Config is supplied by ConfigMaps and Secrets when the pod starts." }
] }
```

## Creating a ConfigMap

Think of a notice board in a society lobby versus a locked drawer in the watchman's cabin. Anyone walking past can read the notice board, that is a ConfigMap: plain settings nobody minds being seen. The locked drawer holds things you would rather only a few people saw, that is a Secret, though as you will see below, the lock is weaker than it sounds.

A **ConfigMap** stores key-value pairs. A value can be a short string or the whole content of a file.

From YAML:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myconfigmap
data:
  db_server: "db.mindforge.test"      # simple values
  database: "mydatabase"
  site.settings: |                 # a whole file as one value
    color=blue
    padding:25px
```

From the command line:

```bash
kubectl create configmap myconfigmap2 \
  --from-literal=background=red \
  --from-file=theme.txt              # key = file name, value = file content
kubectl create configmap nginx-conf --from-file=nginx.conf --from-env-file=app.env

kubectl get configmaps
kubectl describe configmap myconfigmap
kubectl get configmap myconfigmap -o yaml
```

`--from-file=theme.txt` creates the key `theme.txt`. Use `--from-file=mykey=theme.txt` to choose the key name. A ConfigMap can hold at most 1 MiB. It is for configuration, not data.

```knowledge-check
{ "questions": [
  { "id": "k8s-cfg-create-q1", "type": "mcq",
    "prompt": "`kubectl create configmap app --from-file=settings.ini` creates which key?",
    "options": [
      {"id": "a", "text": "app"},
      {"id": "b", "text": "settings.ini, with the file content as its value"},
      {"id": "c", "text": "One key per line of the file"},
      {"id": "d", "text": "data"}
    ],
    "correct": "b",
    "explanation": "--from-file uses the file name as the key and the whole file as the value, unless you write --from-file=<key>=<file>." }
] }
```

## Using a ConfigMap in a pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmappod
spec:
  containers:
  - name: app
    image: nginx:1.27
    env:
    - name: DB_SERVER                # one variable from one key
      valueFrom:
        configMapKeyRef:
          name: myconfigmap
          key: db_server
    envFrom:                         # every key becomes a variable
    - configMapRef:
        name: myconfigmap2
    volumeMounts:
    - name: config-vol
      mountPath: /config             # each key becomes a file in /config
      readOnly: true
  volumes:
  - name: config-vol
    configMap:
      name: myconfigmap
```

Inside the container, `echo $DB_SERVER` prints `db.mindforge.test`, and `cat /config/site.settings` prints the settings file.

**What happens when the ConfigMap changes?**

- **Environment variables do not change** in a running container. They are read once at start. Restart the pods (`kubectl rollout restart deployment/<name>`).
- **Mounted files are updated** automatically after a short delay (up to about a minute). The app must re-read the file to notice.
- Files mounted with `subPath` are **not** updated.

If the ConfigMap (or a key) does not exist, the pod will not start (`CreateContainerConfigError`), unless you mark the reference `optional: true`.

```knowledge-check
{ "questions": [
  { "id": "k8s-cfg-use-q1", "type": "mcq",
    "prompt": "You update a ConfigMap that a running pod uses as environment variables. What does the app see?",
    "options": [
      {"id": "a", "text": "The new values immediately"},
      {"id": "b", "text": "The old values, until the container is restarted"},
      {"id": "c", "text": "Empty values"},
      {"id": "d", "text": "The pod crashes"}
    ],
    "correct": "b",
    "explanation": "Environment variables are fixed when the container starts. Mounted files update after a delay; env vars need a restart." },
  { "id": "k8s-cfg-use-q2", "type": "mcq",
    "prompt": "Which field loads every key of a ConfigMap as environment variables at once?",
    "options": [
      {"id": "a", "text": "env[].valueFrom.configMapKeyRef"},
      {"id": "b", "text": "envFrom[].configMapRef"},
      {"id": "c", "text": "volumes[].configMap"},
      {"id": "d", "text": "spec.configMap"}
    ],
    "correct": "b",
    "explanation": "envFrom imports all keys. valueFrom.configMapKeyRef picks one key for one variable." }
] }
```

## Secrets

A **Secret** works like a ConfigMap but is meant for sensitive values: passwords, tokens, keys, certificates.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque                   # generic key-value secret
stringData:                    # plain text here; Kubernetes stores it base64-encoded
  db_server: db.mindforge.test
  db_username: admin
  db_password: P@ssw0rd!
```

- `stringData` accepts plain text (easier to write).
- `data` requires **base64-encoded** values: `echo -n 'admin' | base64` → `YWRtaW4=`. The `-n` matters; without it you encode a newline too.

From the command line:

```bash
kubectl create secret generic mysecret2 \
  --from-literal=db_username=admin \
  --from-literal=db_password='P@ssw0rd!'

# from files, so the password never appears in your shell history
kubectl create secret generic mysecret3 \
  --from-file=db_username=username.txt \
  --from-file=db_password=password.txt

kubectl get secrets
kubectl describe secret mysecret        # shows keys and sizes, not the values
kubectl get secret mysecret -o jsonpath='{.data.db_password}' | base64 -d
```

Other Secret types you will meet:

| Type | Used for |
|---|---|
| `Opaque` | Any key-value data (default) |
| `kubernetes.io/tls` | A TLS certificate and key (`kubectl create secret tls`), used by Ingress |
| `kubernetes.io/dockerconfigjson` | Registry login for pulling private images (`kubectl create secret docker-registry`), used via `imagePullSecrets` |

```knowledge-check
{ "questions": [
  { "id": "k8s-cfg-secret-q1", "type": "mcq",
    "prompt": "What is the difference between `data` and `stringData` in a Secret manifest?",
    "options": [
      {"id": "a", "text": "data is encrypted; stringData is not"},
      {"id": "b", "text": "data takes base64-encoded values; stringData takes plain text that Kubernetes encodes for you"},
      {"id": "c", "text": "stringData is only for TLS secrets"},
      {"id": "d", "text": "There is no difference"}
    ],
    "correct": "b",
    "explanation": "Both end up stored as base64 in data. stringData is just a convenience for writing plain text." }
] }
```

## Using Secrets in a pod

Exactly like ConfigMaps, with `secretKeyRef`, `secretRef` and `secret` volumes:

```yaml
spec:
  containers:
  - name: app
    image: nginx:1.27
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: mysecret
          key: db_password
    envFrom:
    - secretRef:
        name: mysecret             # every key as a variable
    volumeMounts:
    - name: secret-vol
      mountPath: /secret           # each key becomes a file, e.g. /secret/db_password
      readOnly: true
  volumes:
  - name: secret-vol
    secret:
      secretName: mysecret
```

Mounting secrets as **files** is often safer than environment variables. Environment variables are easy to leak: they show up in crash dumps, debug pages, and child processes, and some logging tools print them.

```knowledge-check
{ "questions": [
  { "id": "k8s-cfg-usesecret-q1", "type": "mcq",
    "prompt": "A Secret mysecret with key api_key is mounted as a volume at /etc/creds. Where does the app find the value?",
    "options": [
      {"id": "a", "text": "In the environment variable API_KEY"},
      {"id": "b", "text": "In the file /etc/creds/api_key"},
      {"id": "c", "text": "In /etc/creds/mysecret.json"},
      {"id": "d", "text": "In /var/run/secrets/api_key"}
    ],
    "correct": "b",
    "explanation": "Each key of a mounted Secret (or ConfigMap) becomes a file named after the key inside the mount path." }
] }
```

## Keeping Secrets actually secret

**base64 is encoding, not encryption.** Anyone who can read the Secret object can decode it in one command. By default, Secrets are also stored unencrypted in etcd. Protect them properly:

- **Limit access with RBAC.** Only the people and service accounts that need a Secret should be allowed to `get` or `list` Secrets in that namespace. (RBAC is covered in the cluster operations lesson.)
- **Enable encryption at rest** for Secrets in etcd (managed clouds usually offer this, often with a cloud KMS key).
- **Never commit Secret manifests with real values to Git.** Use **Sealed Secrets** (encrypted files that only the cluster can decrypt), **SOPS**, or the **External Secrets Operator**, which syncs values from a vault such as AWS Secrets Manager, Azure Key Vault or HashiCorp Vault.
- Mark Secrets and ConfigMaps that should never change as `immutable: true`. That protects them from accidental edits and reduces load on the API server.

```knowledge-check
{ "questions": [
  { "id": "k8s-cfg-safe-q1", "type": "mcq",
    "prompt": "A teammate says: 'Our passwords are safe in Git because the Secret YAML is base64-encoded.' What is wrong with that?",
    "options": [
      {"id": "a", "text": "Nothing; base64 is strong encryption"},
      {"id": "b", "text": "base64 is only encoding; anyone can decode it, so real secrets must not be committed in plain Secret manifests"},
      {"id": "c", "text": "Git cannot store base64 text"},
      {"id": "d", "text": "Kubernetes rejects base64 values"}
    ],
    "correct": "b",
    "explanation": "`base64 -d` reverses it instantly. Use Sealed Secrets, SOPS or an external secret manager, and restrict access with RBAC." }
] }
```

## Interview questions and real-world scenarios

**Q: How do you pass configuration to a pod?**
ConfigMaps and Secrets, as env vars (`env`/`envFrom`) or as mounted files. Plus the Downward API for pod metadata (name, namespace, labels, resource limits).

**Q: Are Kubernetes Secrets secure?**
Not by default: base64 only, readable by anyone with `get secrets`, and unencrypted in etcd unless encryption at rest is enabled. Make them secure with RBAC, KMS encryption, external secret stores and file mounts.

**Q: How do pods pick up a changed ConfigMap?**
Mounted files update after a delay (not with subPath); env vars need a restart. A common pattern is to put a hash of the config in a pod-template annotation (Helm's `checksum/config`) so any config change triggers a rollout automatically.

**Q: What is an immutable ConfigMap/Secret?**
`immutable: true` prevents changes, protects against accidental edits, and reduces API server watch load. To change it, create a new one with a new name and point the Deployment at it.

**Q: How do you pull images from a private registry?**
A `kubernetes.io/dockerconfigjson` Secret referenced in `imagePullSecrets` (or attached to the ServiceAccount). On clouds, node IAM roles or workload identity often replace stored credentials.

**Real-world scenario: after rotating a database password, half the pods fail to connect.**
Pods read the password as an env var at startup. Some restarted and got the new one, others still use the old one, which the database no longer accepts. Rotate safely: let the DB accept both passwords briefly, roll out a restart, then remove the old one. Mounted files plus apps that re-read them avoid restarts.

**Real-world scenario: a pod is stuck in CreateContainerConfigError after a deploy.**
The new version references a ConfigMap key or Secret that was not created in that environment. Create it, or ship config and code together (Helm/Kustomize) so they cannot drift.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-cfg-int-q1",
      "type": "mcq",
      "prompt": "How can Helm make a Deployment roll out automatically whenever its ConfigMap changes?",
      "options": [
        {
          "id": "a",
          "text": "It cannot"
        },
        {
          "id": "b",
          "text": "Put a checksum of the rendered ConfigMap in a pod-template annotation, so a config change changes the template"
        },
        {
          "id": "c",
          "text": "Use envFrom instead of env"
        },
        {
          "id": "d",
          "text": "Mark the ConfigMap immutable"
        }
      ],
      "correct": "b",
      "explanation": "Any change to the pod template triggers a rolling update; the checksum annotation ties the template to the config content."
    }
  ]
}
```
$md$, 40, $json$[{"id":"k8s-cfg-why-q1","type":"mcq","correct":"b"},{"id":"k8s-cfg-create-q1","type":"mcq","correct":"b"},{"id":"k8s-cfg-use-q1","type":"mcq","correct":"b"},{"id":"k8s-cfg-use-q2","type":"mcq","correct":"b"},{"id":"k8s-cfg-secret-q1","type":"mcq","correct":"b"},{"id":"k8s-cfg-usesecret-q1","type":"mcq","correct":"b"},{"id":"k8s-cfg-safe-q1","type":"mcq","correct":"b"},{"id":"k8s-cfg-int-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('f97ad7c6-5f3b-5436-a684-62af7d559bf1', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '1c403d8b-6f9e-5fe3-9443-b75a9f3759b4', 'Lab: ConfigMaps', 'lab', 1, 20)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('bb31fffe-f318-5c57-9ae9-962aacef59ab', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'f97ad7c6-5f3b-5436-a684-62af7d559bf1', 'module', 'Lab: ConfigMaps', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/configmap.yaml <<'MFEOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: myconfigmap
data:
  db_server: "db.mindforge.test"
  database: "mydatabase"
  site.settings: |
    color=blue
    padding:25px
---
apiVersion: v1
kind: Pod
metadata:
  name: configmappod
spec:
  containers:
  - name: configmapcontainer
    image: nginx:1.27
    env:
    - name: DB_SERVER
      valueFrom:
        configMapKeyRef:
          name: myconfigmap
          key: db_server
    - name: DATABASE
      valueFrom:
        configMapKeyRef:
          name: myconfigmap
          key: database
    volumeMounts:
    - name: config-vol
      mountPath: "/config"
      readOnly: true
  volumes:
  - name: config-vol
    configMap:
      name: myconfigmap

MFEOF
chmod 666 /home/labuser/work/configmap.yaml
cat > /home/labuser/work/theme.txt <<'MFEOF'
theme=dark

MFEOF
chmod 666 /home/labuser/work/theme.txt
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'fd4caf13-2929-514d-8218-f5e95e207bfc' AND id NOT IN ('10733d0b-1f4b-5b44-925a-92438ad6d182', '683307b0-6ab2-5d63-b926-cb4ed993df35', 'ec1ff47c-c4a9-57ef-8349-b825f872365f', '746d26a8-8f4a-5c1b-a686-55fa7c4ed621');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'fd4caf13-2929-514d-8218-f5e95e207bfc';
DELETE FROM lab_tasks WHERE lab_id = 'bb31fffe-f318-5c57-9ae9-962aacef59ab' AND id NOT IN ('3052f764-ca31-50d7-a6ed-5fc58d80d448', 'cb43fb10-ec1f-5950-a5a0-2481403a1b71', '5709b3e1-d062-53a7-9799-c82458aaf1de', 'ed16f611-e951-5718-aea6-7269dc059f2c');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'bb31fffe-f318-5c57-9ae9-962aacef59ab';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('3052f764-ca31-50d7-a6ed-5fc58d80d448', 'bb31fffe-f318-5c57-9ae9-962aacef59ab', 1, 'Create a ConfigMap and a pod that uses it', $md$Apply `configmap.yaml`. Then run `kubectl describe configmap myconfigmap` and `kubectl describe pod configmappod`. Find where the pod gets `DB_SERVER` from and where `/config` is mounted.$md$, $script$#!/bin/bash
test "$(kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}')" = "db.mindforge.test" || exit 1
test "$(kubectl get pod configmappod -o jsonpath='{.status.phase}')" = "Running"
$script$, '`kubectl apply -f configmap.yaml`', 'On a real cluster, `kubectl exec configmappod -- printenv DB_SERVER` prints db.mindforge.test and `kubectl exec configmappod -- cat /config/site.settings` prints the settings file.', 10, false, true),
('cb43fb10-ec1f-5950-a5a0-2481403a1b71', 'bb31fffe-f318-5c57-9ae9-962aacef59ab', 2, 'Create a ConfigMap from the command line', $md$Create a ConfigMap named `myconfigmap2` with a literal key `background=red` and the file `theme.txt`.$md$, $script$#!/bin/bash
test "$(kubectl get configmap myconfigmap2 -o jsonpath='{.data.background}')" = "red" || exit 1
kubectl get configmap myconfigmap2 -o jsonpath='{.data.theme\.txt}' | grep -qx 'theme=dark'
$script$, '`kubectl create configmap <name> --from-literal=key=value --from-file=<file>`', '--from-literal adds one key directly. --from-file uses the file name (theme.txt) as the key and its content as the value.', 15, false, true),
('5709b3e1-d062-53a7-9799-c82458aaf1de', 'bb31fffe-f318-5c57-9ae9-962aacef59ab', 3, 'Load every key as environment variables', $md$Write and apply a pod named `envpod` (image `nginx:1.27`, container name `app`) that loads **all** keys of `myconfigmap2` as environment variables with `envFrom`.
$md$, $script$#!/bin/bash
test "$(kubectl get pod envpod -o jsonpath='{.spec.containers[0].envFrom[0].configMapRef.name}')" = "myconfigmap2"
$script$, 'Under the container, add `envFrom:` with a list item `- configMapRef:` whose `name:` is myconfigmap2.', 'envFrom imports every key at once. Keys that are not valid variable names (like theme.txt, which contains a dot) are skipped, and an event reports it.', 20, false, false),
('ed16f611-e951-5718-aea6-7269dc059f2c', 'bb31fffe-f318-5c57-9ae9-962aacef59ab', 4, 'Change a value', $md$Change `db_server` in `myconfigmap` to `db2.mindforge.test` (edit the file and re-apply, or use `kubectl edit configmap myconfigmap`).$md$, $script$#!/bin/bash
test "$(kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}')" = "db2.mindforge.test"
$script$, 'Edit configmap.yaml and run `kubectl apply -f configmap.yaml` again.', 'The file mounted at /config/db_server updates within about a minute, but the DB_SERVER environment variable in the running pod keeps the old value until the pod is recreated.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('fd4caf13-2929-514d-8218-f5e95e207bfc', 'bb31fffe-f318-5c57-9ae9-962aacef59ab', 1, $json$[{"id":"3052f764-ca31-50d7-a6ed-5fc58d80d448","lab_id":"bb31fffe-f318-5c57-9ae9-962aacef59ab","position":1,"title":"Create a ConfigMap and a pod that uses it","description":"Apply `configmap.yaml`. Then run `kubectl describe configmap myconfigmap` and `kubectl describe pod configmappod`. Find where the pod gets `DB_SERVER` from and where `/config` is mounted.","verification_script":"#!/bin/bash\ntest \"$(kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}')\" = \"db.mindforge.test\" || exit 1\ntest \"$(kubectl get pod configmappod -o jsonpath='{.status.phase}')\" = \"Running\"\n","hint_context":"`kubectl apply -f configmap.yaml`","explanation_context":"On a real cluster, `kubectl exec configmappod -- printenv DB_SERVER` prints db.mindforge.test and `kubectl exec configmappod -- cat /config/site.settings` prints the settings file.","points":10,"is_optional":false,"is_stateful":true},{"id":"cb43fb10-ec1f-5950-a5a0-2481403a1b71","lab_id":"bb31fffe-f318-5c57-9ae9-962aacef59ab","position":2,"title":"Create a ConfigMap from the command line","description":"Create a ConfigMap named `myconfigmap2` with a literal key `background=red` and the file `theme.txt`.","verification_script":"#!/bin/bash\ntest \"$(kubectl get configmap myconfigmap2 -o jsonpath='{.data.background}')\" = \"red\" || exit 1\nkubectl get configmap myconfigmap2 -o jsonpath='{.data.theme\\.txt}' | grep -qx 'theme=dark'\n","hint_context":"`kubectl create configmap \u003cname\u003e --from-literal=key=value --from-file=\u003cfile\u003e`","explanation_context":"--from-literal adds one key directly. --from-file uses the file name (theme.txt) as the key and its content as the value.","points":15,"is_optional":false,"is_stateful":true},{"id":"5709b3e1-d062-53a7-9799-c82458aaf1de","lab_id":"bb31fffe-f318-5c57-9ae9-962aacef59ab","position":3,"title":"Load every key as environment variables","description":"Write and apply a pod named `envpod` (image `nginx:1.27`, container name `app`) that loads **all** keys of `myconfigmap2` as environment variables with `envFrom`.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get pod envpod -o jsonpath='{.spec.containers[0].envFrom[0].configMapRef.name}')\" = \"myconfigmap2\"\n","hint_context":"Under the container, add `envFrom:` with a list item `- configMapRef:` whose `name:` is myconfigmap2.","explanation_context":"envFrom imports every key at once. Keys that are not valid variable names (like theme.txt, which contains a dot) are skipped, and an event reports it.","points":20,"is_optional":false,"is_stateful":false},{"id":"ed16f611-e951-5718-aea6-7269dc059f2c","lab_id":"bb31fffe-f318-5c57-9ae9-962aacef59ab","position":4,"title":"Change a value","description":"Change `db_server` in `myconfigmap` to `db2.mindforge.test` (edit the file and re-apply, or use `kubectl edit configmap myconfigmap`).","verification_script":"#!/bin/bash\ntest \"$(kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}')\" = \"db2.mindforge.test\"\n","hint_context":"Edit configmap.yaml and run `kubectl apply -f configmap.yaml` again.","explanation_context":"The file mounted at /config/db_server updates within about a minute, but the DB_SERVER environment variable in the running pod keeps the old value until the pod is recreated.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('10733d0b-1f4b-5b44-925a-92438ad6d182', 'fd4caf13-2929-514d-8218-f5e95e207bfc', '3052f764-ca31-50d7-a6ed-5fc58d80d448', 1, 'Create a ConfigMap and a pod that uses it', $md$Apply `configmap.yaml`. Then run `kubectl describe configmap myconfigmap` and `kubectl describe pod configmappod`. Find where the pod gets `DB_SERVER` from and where `/config` is mounted.$md$, $script$#!/bin/bash
test "$(kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}')" = "db.mindforge.test" || exit 1
test "$(kubectl get pod configmappod -o jsonpath='{.status.phase}')" = "Running"
$script$, '`kubectl apply -f configmap.yaml`', 'On a real cluster, `kubectl exec configmappod -- printenv DB_SERVER` prints db.mindforge.test and `kubectl exec configmappod -- cat /config/site.settings` prints the settings file.', 10, false, true),
('683307b0-6ab2-5d63-b926-cb4ed993df35', 'fd4caf13-2929-514d-8218-f5e95e207bfc', 'cb43fb10-ec1f-5950-a5a0-2481403a1b71', 2, 'Create a ConfigMap from the command line', $md$Create a ConfigMap named `myconfigmap2` with a literal key `background=red` and the file `theme.txt`.$md$, $script$#!/bin/bash
test "$(kubectl get configmap myconfigmap2 -o jsonpath='{.data.background}')" = "red" || exit 1
kubectl get configmap myconfigmap2 -o jsonpath='{.data.theme\.txt}' | grep -qx 'theme=dark'
$script$, '`kubectl create configmap <name> --from-literal=key=value --from-file=<file>`', '--from-literal adds one key directly. --from-file uses the file name (theme.txt) as the key and its content as the value.', 15, false, true),
('ec1ff47c-c4a9-57ef-8349-b825f872365f', 'fd4caf13-2929-514d-8218-f5e95e207bfc', '5709b3e1-d062-53a7-9799-c82458aaf1de', 3, 'Load every key as environment variables', $md$Write and apply a pod named `envpod` (image `nginx:1.27`, container name `app`) that loads **all** keys of `myconfigmap2` as environment variables with `envFrom`.
$md$, $script$#!/bin/bash
test "$(kubectl get pod envpod -o jsonpath='{.spec.containers[0].envFrom[0].configMapRef.name}')" = "myconfigmap2"
$script$, 'Under the container, add `envFrom:` with a list item `- configMapRef:` whose `name:` is myconfigmap2.', 'envFrom imports every key at once. Keys that are not valid variable names (like theme.txt, which contains a dot) are skipped, and an event reports it.', 20, false, false),
('746d26a8-8f4a-5c1b-a686-55fa7c4ed621', 'fd4caf13-2929-514d-8218-f5e95e207bfc', 'ed16f611-e951-5718-aea6-7269dc059f2c', 4, 'Change a value', $md$Change `db_server` in `myconfigmap` to `db2.mindforge.test` (edit the file and re-apply, or use `kubectl edit configmap myconfigmap`).$md$, $script$#!/bin/bash
test "$(kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}')" = "db2.mindforge.test"
$script$, 'Edit configmap.yaml and run `kubectl apply -f configmap.yaml` again.', 'The file mounted at /config/db_server updates within about a minute, but the DB_SERVER environment variable in the running pod keeps the old value until the pod is recreated.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'fd4caf13-2929-514d-8218-f5e95e207bfc', updated_at = now()
WHERE id = 'bb31fffe-f318-5c57-9ae9-962aacef59ab' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('f5cb494b-5f41-5bc2-8998-b2f459c08c19', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '1c403d8b-6f9e-5fe3-9443-b75a9f3759b4', 'Lab: Secrets', 'lab', 2, 25)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('c33cca04-5574-5f1d-91e9-6a696002a5a1', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'f5cb494b-5f41-5bc2-8998-b2f459c08c19', 'module', 'Lab: Secrets', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/secret.yaml <<'MFEOF'
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  db_server: db.mindforge.test
  db_username: admin
  db_password: P@ssw0rd!

MFEOF
chmod 666 /home/labuser/work/secret.yaml
cat > /home/labuser/work/secret-pods.yaml <<'MFEOF'
apiVersion: v1
kind: Pod
metadata:
  name: secretvolumepod
spec:
  containers:
  - name: secretcontainer
    image: nginx:1.27
    volumeMounts:
    - name: secret-vol
      mountPath: /secret
  volumes:
  - name: secret-vol
    secret:
      secretName: mysecret
---
apiVersion: v1
kind: Pod
metadata:
  name: secretenvpod
spec:
  containers:
  - name: secretcontainer
    image: nginx:1.27
    env:
    - name: username
      valueFrom:
        secretKeyRef:
          name: mysecret
          key: db_username
    - name: password
      valueFrom:
        secretKeyRef:
          name: mysecret
          key: db_password
    - name: server
      valueFrom:
        secretKeyRef:
          name: mysecret
          key: db_server
---
apiVersion: v1
kind: Pod
metadata:
  name: secretenvallpod
spec:
  containers:
  - name: secretcontainer
    image: nginx:1.27
    envFrom:
    - secretRef:
        name: mysecret

MFEOF
chmod 666 /home/labuser/work/secret-pods.yaml
cat > /home/labuser/work/username.txt <<'MFEOF'
admin
MFEOF
chmod 666 /home/labuser/work/username.txt
cat > /home/labuser/work/password.txt <<'MFEOF'
S3cure-Pa55
MFEOF
chmod 666 /home/labuser/work/password.txt
cat > /home/labuser/work/server.txt <<'MFEOF'
db.mindforge.test
MFEOF
chmod 666 /home/labuser/work/server.txt
cat > /home/labuser/work/config.json <<'MFEOF'
{
  "apiKey": "7ac4108d4b2212f2c30c71dfa279e1f77dd12356"
}

MFEOF
chmod 666 /home/labuser/work/config.json
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = 'fe60a567-cf3d-50b9-b98a-b4c9033ad0a8' AND id NOT IN ('5210a5d5-5bcc-5301-8096-a2f6a9be0154', '3a8548f0-3591-5893-aa47-3cc697a8c5d8', '6031ae16-96a9-56c3-bb7d-e5c387597482', '0bcf1715-3626-5d2b-9598-906a525900cf', '7504af5c-3988-5e75-86d6-15452e825895');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = 'fe60a567-cf3d-50b9-b98a-b4c9033ad0a8';
DELETE FROM lab_tasks WHERE lab_id = 'c33cca04-5574-5f1d-91e9-6a696002a5a1' AND id NOT IN ('9fcedf71-93a8-5fdd-83b0-49f603a7a16c', 'bcf541a2-1286-55ce-8f89-9af6a8e07395', '587f1b83-3f4c-5ab2-afa8-4d3855bcb7c6', '504d8159-4e74-5547-a0ad-f38c0948ed4f', 'c4f64420-31e5-5fd9-992e-3b42afbae065');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'c33cca04-5574-5f1d-91e9-6a696002a5a1';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('9fcedf71-93a8-5fdd-83b0-49f603a7a16c', 'c33cca04-5574-5f1d-91e9-6a696002a5a1', 1, 'Create a Secret and three pods that use it', $md$Apply `secret.yaml`, then `secret-pods.yaml`. The three pods read the same Secret as files, as chosen variables, and as all variables. Run `kubectl describe secret mysecret`. Notice it shows sizes, not values.$md$, $script$#!/bin/bash
kubectl get secret mysecret >/dev/null 2>&1 || exit 1
for p in secretvolumepod secretenvpod secretenvallpod; do
  test "$(kubectl get pod $p -o jsonpath='{.status.phase}')" = "Running" || exit 1
done
$script$, 'Apply both files with `kubectl apply -f`, secret first.', 'On a real cluster, `kubectl exec secretvolumepod -- cat /secret/db_password` and `kubectl exec secretenvpod -- printenv password` both show the password.', 10, false, true),
('bcf541a2-1286-55ce-8f89-9af6a8e07395', 'c33cca04-5574-5f1d-91e9-6a696002a5a1', 2, 'See that base64 is not encryption', $md$Read the stored password with `kubectl get secret mysecret -o jsonpath='{.data.db_password}'` and decode it with `base64 -d`. Save the decoded value to `~/work/decoded.txt`.
$md$, $script$#!/bin/bash
grep -qx 'P@ssw0rd!' /home/labuser/work/decoded.txt
$script$, 'Pipe the jsonpath output into `base64 -d` and redirect it to decoded.txt.', 'Anyone with read access to Secrets can decode them in one line. That is why access to Secrets must be limited with RBAC, and real values must not be stored in Git as plain manifests.', 10, false, false),
('587f1b83-3f4c-5ab2-afa8-4d3855bcb7c6', 'c33cca04-5574-5f1d-91e9-6a696002a5a1', 3, 'Create a Secret from files', $md$Create a Secret named `mysecret3` with the keys `db_server`, `db_username` and `db_password`, taken from `server.txt`, `username.txt` and `password.txt`. This keeps the password out of your shell history.$md$, $script$#!/bin/bash
test "$(kubectl get secret mysecret3 -o jsonpath='{.data.db_password}' | base64 -d)" = "S3cure-Pa55" || exit 1
test "$(kubectl get secret mysecret3 -o jsonpath='{.data.db_username}' | base64 -d)" = "admin"
$script$, '`--from-file=<key>=<file>` sets the key name. Repeat it for each key.', '`kubectl create secret generic mysecret3 --from-file=db_server=server.txt --from-file=db_username=username.txt --from-file=db_password=password.txt`', 15, false, false),
('504d8159-4e74-5547-a0ad-f38c0948ed4f', 'c33cca04-5574-5f1d-91e9-6a696002a5a1', 4, 'Store a whole file as a Secret', $md$Create a Secret named `mysecret4` from `config.json` (the key should be the file name).$md$, $script$#!/bin/bash
kubectl get secret mysecret4 -o jsonpath='{.data.config\.json}' | base64 -d | grep -q apiKey
$script$, '`kubectl create secret generic <name> --from-file=<file>`', 'Mounted as a volume, this becomes a file config.json that the app can read directly.', 10, false, false),
('c4f64420-31e5-5fd9-992e-3b42afbae065', 'c33cca04-5574-5f1d-91e9-6a696002a5a1', 5, 'Create a registry login Secret', $md$Create a `docker-registry` Secret named `regcred` for the server `registry.mindforge.test`, user `ci`, password `token123`. Then create a pod `private-pod` (image `registry.mindforge.test/team/app:1.0`) that uses it through `imagePullSecrets`.
$md$, $script$#!/bin/bash
test "$(kubectl get secret regcred -o jsonpath='{.type}')" = "kubernetes.io/dockerconfigjson" || exit 1
test "$(kubectl get pod private-pod -o jsonpath='{.spec.imagePullSecrets[0].name}')" = "regcred"
$script$, '`kubectl create secret docker-registry regcred --docker-server=... --docker-username=... --docker-password=...`. In the pod spec, `imagePullSecrets:` is a list of `- name:` entries at the same level as `containers`.', 'The kubelet uses the credentials in regcred to pull the private image. Without it the pod would end up in ImagePullBackOff.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('fe60a567-cf3d-50b9-b98a-b4c9033ad0a8', 'c33cca04-5574-5f1d-91e9-6a696002a5a1', 1, $json$[{"id":"9fcedf71-93a8-5fdd-83b0-49f603a7a16c","lab_id":"c33cca04-5574-5f1d-91e9-6a696002a5a1","position":1,"title":"Create a Secret and three pods that use it","description":"Apply `secret.yaml`, then `secret-pods.yaml`. The three pods read the same Secret as files, as chosen variables, and as all variables. Run `kubectl describe secret mysecret`. Notice it shows sizes, not values.","verification_script":"#!/bin/bash\nkubectl get secret mysecret \u003e/dev/null 2\u003e\u00261 || exit 1\nfor p in secretvolumepod secretenvpod secretenvallpod; do\n  test \"$(kubectl get pod $p -o jsonpath='{.status.phase}')\" = \"Running\" || exit 1\ndone\n","hint_context":"Apply both files with `kubectl apply -f`, secret first.","explanation_context":"On a real cluster, `kubectl exec secretvolumepod -- cat /secret/db_password` and `kubectl exec secretenvpod -- printenv password` both show the password.","points":10,"is_optional":false,"is_stateful":true},{"id":"bcf541a2-1286-55ce-8f89-9af6a8e07395","lab_id":"c33cca04-5574-5f1d-91e9-6a696002a5a1","position":2,"title":"See that base64 is not encryption","description":"Read the stored password with `kubectl get secret mysecret -o jsonpath='{.data.db_password}'` and decode it with `base64 -d`. Save the decoded value to `~/work/decoded.txt`.\n","verification_script":"#!/bin/bash\ngrep -qx 'P@ssw0rd!' /home/labuser/work/decoded.txt\n","hint_context":"Pipe the jsonpath output into `base64 -d` and redirect it to decoded.txt.","explanation_context":"Anyone with read access to Secrets can decode them in one line. That is why access to Secrets must be limited with RBAC, and real values must not be stored in Git as plain manifests.","points":10,"is_optional":false,"is_stateful":false},{"id":"587f1b83-3f4c-5ab2-afa8-4d3855bcb7c6","lab_id":"c33cca04-5574-5f1d-91e9-6a696002a5a1","position":3,"title":"Create a Secret from files","description":"Create a Secret named `mysecret3` with the keys `db_server`, `db_username` and `db_password`, taken from `server.txt`, `username.txt` and `password.txt`. This keeps the password out of your shell history.","verification_script":"#!/bin/bash\ntest \"$(kubectl get secret mysecret3 -o jsonpath='{.data.db_password}' | base64 -d)\" = \"S3cure-Pa55\" || exit 1\ntest \"$(kubectl get secret mysecret3 -o jsonpath='{.data.db_username}' | base64 -d)\" = \"admin\"\n","hint_context":"`--from-file=\u003ckey\u003e=\u003cfile\u003e` sets the key name. Repeat it for each key.","explanation_context":"`kubectl create secret generic mysecret3 --from-file=db_server=server.txt --from-file=db_username=username.txt --from-file=db_password=password.txt`","points":15,"is_optional":false,"is_stateful":false},{"id":"504d8159-4e74-5547-a0ad-f38c0948ed4f","lab_id":"c33cca04-5574-5f1d-91e9-6a696002a5a1","position":4,"title":"Store a whole file as a Secret","description":"Create a Secret named `mysecret4` from `config.json` (the key should be the file name).","verification_script":"#!/bin/bash\nkubectl get secret mysecret4 -o jsonpath='{.data.config\\.json}' | base64 -d | grep -q apiKey\n","hint_context":"`kubectl create secret generic \u003cname\u003e --from-file=\u003cfile\u003e`","explanation_context":"Mounted as a volume, this becomes a file config.json that the app can read directly.","points":10,"is_optional":false,"is_stateful":false},{"id":"c4f64420-31e5-5fd9-992e-3b42afbae065","lab_id":"c33cca04-5574-5f1d-91e9-6a696002a5a1","position":5,"title":"Create a registry login Secret","description":"Create a `docker-registry` Secret named `regcred` for the server `registry.mindforge.test`, user `ci`, password `token123`. Then create a pod `private-pod` (image `registry.mindforge.test/team/app:1.0`) that uses it through `imagePullSecrets`.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get secret regcred -o jsonpath='{.type}')\" = \"kubernetes.io/dockerconfigjson\" || exit 1\ntest \"$(kubectl get pod private-pod -o jsonpath='{.spec.imagePullSecrets[0].name}')\" = \"regcred\"\n","hint_context":"`kubectl create secret docker-registry regcred --docker-server=... --docker-username=... --docker-password=...`. In the pod spec, `imagePullSecrets:` is a list of `- name:` entries at the same level as `containers`.","explanation_context":"The kubelet uses the credentials in regcred to pull the private image. Without it the pod would end up in ImagePullBackOff.","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('5210a5d5-5bcc-5301-8096-a2f6a9be0154', 'fe60a567-cf3d-50b9-b98a-b4c9033ad0a8', '9fcedf71-93a8-5fdd-83b0-49f603a7a16c', 1, 'Create a Secret and three pods that use it', $md$Apply `secret.yaml`, then `secret-pods.yaml`. The three pods read the same Secret as files, as chosen variables, and as all variables. Run `kubectl describe secret mysecret`. Notice it shows sizes, not values.$md$, $script$#!/bin/bash
kubectl get secret mysecret >/dev/null 2>&1 || exit 1
for p in secretvolumepod secretenvpod secretenvallpod; do
  test "$(kubectl get pod $p -o jsonpath='{.status.phase}')" = "Running" || exit 1
done
$script$, 'Apply both files with `kubectl apply -f`, secret first.', 'On a real cluster, `kubectl exec secretvolumepod -- cat /secret/db_password` and `kubectl exec secretenvpod -- printenv password` both show the password.', 10, false, true),
('3a8548f0-3591-5893-aa47-3cc697a8c5d8', 'fe60a567-cf3d-50b9-b98a-b4c9033ad0a8', 'bcf541a2-1286-55ce-8f89-9af6a8e07395', 2, 'See that base64 is not encryption', $md$Read the stored password with `kubectl get secret mysecret -o jsonpath='{.data.db_password}'` and decode it with `base64 -d`. Save the decoded value to `~/work/decoded.txt`.
$md$, $script$#!/bin/bash
grep -qx 'P@ssw0rd!' /home/labuser/work/decoded.txt
$script$, 'Pipe the jsonpath output into `base64 -d` and redirect it to decoded.txt.', 'Anyone with read access to Secrets can decode them in one line. That is why access to Secrets must be limited with RBAC, and real values must not be stored in Git as plain manifests.', 10, false, false),
('6031ae16-96a9-56c3-bb7d-e5c387597482', 'fe60a567-cf3d-50b9-b98a-b4c9033ad0a8', '587f1b83-3f4c-5ab2-afa8-4d3855bcb7c6', 3, 'Create a Secret from files', $md$Create a Secret named `mysecret3` with the keys `db_server`, `db_username` and `db_password`, taken from `server.txt`, `username.txt` and `password.txt`. This keeps the password out of your shell history.$md$, $script$#!/bin/bash
test "$(kubectl get secret mysecret3 -o jsonpath='{.data.db_password}' | base64 -d)" = "S3cure-Pa55" || exit 1
test "$(kubectl get secret mysecret3 -o jsonpath='{.data.db_username}' | base64 -d)" = "admin"
$script$, '`--from-file=<key>=<file>` sets the key name. Repeat it for each key.', '`kubectl create secret generic mysecret3 --from-file=db_server=server.txt --from-file=db_username=username.txt --from-file=db_password=password.txt`', 15, false, false),
('0bcf1715-3626-5d2b-9598-906a525900cf', 'fe60a567-cf3d-50b9-b98a-b4c9033ad0a8', '504d8159-4e74-5547-a0ad-f38c0948ed4f', 4, 'Store a whole file as a Secret', $md$Create a Secret named `mysecret4` from `config.json` (the key should be the file name).$md$, $script$#!/bin/bash
kubectl get secret mysecret4 -o jsonpath='{.data.config\.json}' | base64 -d | grep -q apiKey
$script$, '`kubectl create secret generic <name> --from-file=<file>`', 'Mounted as a volume, this becomes a file config.json that the app can read directly.', 10, false, false),
('7504af5c-3988-5e75-86d6-15452e825895', 'fe60a567-cf3d-50b9-b98a-b4c9033ad0a8', 'c4f64420-31e5-5fd9-992e-3b42afbae065', 5, 'Create a registry login Secret', $md$Create a `docker-registry` Secret named `regcred` for the server `registry.mindforge.test`, user `ci`, password `token123`. Then create a pod `private-pod` (image `registry.mindforge.test/team/app:1.0`) that uses it through `imagePullSecrets`.
$md$, $script$#!/bin/bash
test "$(kubectl get secret regcred -o jsonpath='{.type}')" = "kubernetes.io/dockerconfigjson" || exit 1
test "$(kubectl get pod private-pod -o jsonpath='{.spec.imagePullSecrets[0].name}')" = "regcred"
$script$, '`kubectl create secret docker-registry regcred --docker-server=... --docker-username=... --docker-password=...`. In the pod spec, `imagePullSecrets:` is a list of `- name:` entries at the same level as `containers`.', 'The kubelet uses the credentials in regcred to pull the private image. Without it the pod would end up in ImagePullBackOff.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'fe60a567-cf3d-50b9-b98a-b4c9033ad0a8', updated_at = now()
WHERE id = 'c33cca04-5574-5f1d-91e9-6a696002a5a1' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b98911f2-3918-5112-a7a1-d4b569468700', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which object should hold a feature setting like LOG_LEVEL=debug?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9e851561-b24f-51fd-8b67-07327b340f06', 'b98911f2-3918-5112-a7a1-d4b569468700', 1, $json${"prompt":"Which object should hold a feature setting like LOG_LEVEL=debug?","multiple":false,"options":[{"id":"a","text":"Secret","is_correct":false},{"id":"b","text":"ConfigMap","is_correct":true},{"id":"c","text":"PersistentVolume","is_correct":false},{"id":"d","text":"Service","is_correct":false}],"explanation":"Non-sensitive settings belong in a ConfigMap. Secrets are for passwords, tokens and keys."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('bcd94f8c-fe61-591e-a445-b02c500762bb', '00000000-0000-0000-0000-000000000001', 'mcq', 'What are the two ways a pod can consume a ConfigMap or Secret?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('db69d9bb-e1b7-52fa-9419-d5e0cfd67ae1', 'bcd94f8c-fe61-591e-a445-b02c500762bb', 1, $json${"prompt":"What are the two ways a pod can consume a ConfigMap or Secret?","multiple":false,"options":[{"id":"a","text":"As environment variables or as files in a mounted volume","is_correct":true},{"id":"b","text":"As a Service or as an Ingress","is_correct":false},{"id":"c","text":"As a label or as an annotation","is_correct":false},{"id":"d","text":"Only through the Kubernetes API from inside the app","is_correct":false}],"explanation":"env/envFrom for variables, and a configMap/secret volume for files."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e50c0c8b-84f4-5238-b9e6-cc75f834780b', '00000000-0000-0000-0000-000000000001', 'mcq', 'A ConfigMap is mounted as a volume (without subPath). You change one of its v...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('bf5e41cc-9875-5160-8b2e-b2c626bcd1ae', 'e50c0c8b-84f4-5238-b9e6-cc75f834780b', 1, $json${"prompt":"A ConfigMap is mounted as a volume (without subPath). You change one of its values. What happens to the file in the running pod?","multiple":false,"options":[{"id":"a","text":"It never changes","is_correct":false},{"id":"b","text":"It is updated automatically after a short delay","is_correct":true},{"id":"c","text":"The pod is restarted automatically","is_correct":false},{"id":"d","text":"The file is deleted","is_correct":false}],"explanation":"The kubelet refreshes mounted ConfigMap files, usually within a minute. Environment variables and subPath mounts do not update."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('fa329e24-636f-559d-aa32-248e7be615ca', '00000000-0000-0000-0000-000000000001', 'mcq', 'How are values stored in the `data` field of a Secret?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0a204587-e4b2-5ccb-a728-a75251d864fe', 'fa329e24-636f-559d-aa32-248e7be615ca', 1, $json${"prompt":"How are values stored in the `data` field of a Secret?","multiple":false,"options":[{"id":"a","text":"Encrypted with AES","is_correct":false},{"id":"b","text":"Base64-encoded, which anyone with read access can decode","is_correct":true},{"id":"c","text":"Hashed, so they cannot be read back","is_correct":false},{"id":"d","text":"As plain text","is_correct":false}],"explanation":"base64 is just encoding. Protect Secrets with RBAC, encryption at rest, and external secret tools."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('382303a5-6d3c-5106-9d26-cb7434340d97', '00000000-0000-0000-0000-000000000001', 'mcq', 'A pod references a ConfigMap key that does not exist, and the reference is no...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('bf5b476d-b98b-5be6-aee9-36341ac442be', '382303a5-6d3c-5106-9d26-cb7434340d97', 1, $json${"prompt":"A pod references a ConfigMap key that does not exist, and the reference is not optional. What happens?","multiple":false,"options":[{"id":"a","text":"The variable is set to an empty string","is_correct":false},{"id":"b","text":"The container does not start (CreateContainerConfigError)","is_correct":true},{"id":"c","text":"Kubernetes creates the key with a default value","is_correct":false},{"id":"d","text":"The pod runs on a different node","is_correct":false}],"explanation":"Missing required config keeps the container from starting. Mark the reference optional true if it may be absent."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cd8da69a-b630-5456-a30a-0f567d234ede', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which Secret type lets the kubelet pull images from a private registry?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('6546fd4f-9c47-5ba0-acfa-4cc7cc29565c', 'cd8da69a-b630-5456-a30a-0f567d234ede', 1, $json${"prompt":"Which Secret type lets the kubelet pull images from a private registry?","multiple":false,"options":[{"id":"a","text":"kubernetes.io/tls","is_correct":false},{"id":"b","text":"kubernetes.io/dockerconfigjson, referenced in imagePullSecrets","is_correct":true},{"id":"c","text":"Opaque, referenced in envFrom","is_correct":false},{"id":"d","text":"kubernetes.io/service-account-token","is_correct":false}],"explanation":"Create it with kubectl create secret docker-registry and list it under imagePullSecrets in the pod spec."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('9914a896-b5c8-5c84-a70f-47af332fc721', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is a safe way to keep Secret definitions in Git?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e73f8d33-c1af-54df-8547-5f571d1faa7c', '9914a896-b5c8-5c84-a70f-47af332fc721', 1, $json${"prompt":"What is a safe way to keep Secret definitions in Git?","multiple":false,"options":[{"id":"a","text":"Commit the Secret YAML with base64 values","is_correct":false},{"id":"b","text":"Use Sealed Secrets, SOPS, or the External Secrets Operator with a vault","is_correct":true},{"id":"c","text":"Put passwords in a ConfigMap instead","is_correct":false},{"id":"d","text":"Rename the file to .secret.yaml","is_correct":false}],"explanation":"These tools keep only encrypted data or references in Git; the real values are decrypted or fetched inside the cluster."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('fe1bed1e-2b1d-539a-a462-4086d2e16717', '00000000-0000-0000-0000-000000000001', 'Quiz: ConfigMaps & Secrets', 'k8s-config-secrets-quiz', 'Quiz covering ConfigMaps & Secrets.', 'mcq', 'published', 'module', '3dc9739f-6e70-5ded-b51f-d43242453e28', 15, 70, 5, 7, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = 'fe1bed1e-2b1d-539a-a462-4086d2e16717' AND question_id NOT IN ('b98911f2-3918-5112-a7a1-d4b569468700', 'bcd94f8c-fe61-591e-a445-b02c500762bb', 'e50c0c8b-84f4-5238-b9e6-cc75f834780b', 'fa329e24-636f-559d-aa32-248e7be615ca', '382303a5-6d3c-5106-9d26-cb7434340d97', 'cd8da69a-b630-5456-a30a-0f567d234ede', '9914a896-b5c8-5c84-a70f-47af332fc721');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('3c009860-1a7e-5946-82c9-1cbf5dc0218a', 'fe1bed1e-2b1d-539a-a462-4086d2e16717', 'b98911f2-3918-5112-a7a1-d4b569468700', '9e851561-b24f-51fd-8b67-07327b340f06', 0, 1),
('237b8a02-a28c-5879-8cf7-ad0f9071b1d4', 'fe1bed1e-2b1d-539a-a462-4086d2e16717', 'bcd94f8c-fe61-591e-a445-b02c500762bb', 'db69d9bb-e1b7-52fa-9419-d5e0cfd67ae1', 1, 1),
('7e72ef39-7bbc-5eca-82ca-de157d9fc59b', 'fe1bed1e-2b1d-539a-a462-4086d2e16717', 'e50c0c8b-84f4-5238-b9e6-cc75f834780b', 'bf5e41cc-9875-5160-8b2e-b2c626bcd1ae', 2, 1),
('975ceb59-b7ba-5925-8784-3b1e287a5eaa', 'fe1bed1e-2b1d-539a-a462-4086d2e16717', 'fa329e24-636f-559d-aa32-248e7be615ca', '0a204587-e4b2-5ccb-a728-a75251d864fe', 3, 1),
('7babdd3d-91be-5270-8ecf-0cecdd76ef08', 'fe1bed1e-2b1d-539a-a462-4086d2e16717', '382303a5-6d3c-5106-9d26-cb7434340d97', 'bf5b476d-b98b-5be6-aee9-36341ac442be', 4, 1),
('4123ecb2-a741-5432-8c59-1ed5c127d996', 'fe1bed1e-2b1d-539a-a462-4086d2e16717', 'cd8da69a-b630-5456-a30a-0f567d234ede', '6546fd4f-9c47-5ba0-acfa-4cc7cc29565c', 5, 1),
('05243053-f6ec-58ec-a382-55df82bb9fd7', 'fe1bed1e-2b1d-539a-a462-4086d2e16717', '9914a896-b5c8-5c84-a70f-47af332fc721', 'e73f8d33-c1af-54df-8547-5f571d1faa7c', 6, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('3dc9739f-6e70-5ded-b51f-d43242453e28', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '1c403d8b-6f9e-5fe3-9443-b75a9f3759b4', 'Quiz: ConfigMaps & Secrets', 'assessment', 3, 10, 'fe1bed1e-2b1d-539a-a462-4086d2e16717')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Storage
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('45cb3c88-5b2a-5385-98b6-2763f2717d95', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Storage', 6)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('dbe8d427-ccc5-5398-b1f8-26ead5653c4f', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '45cb3c88-5b2a-5385-98b6-2763f2717d95', 'Volumes, PersistentVolumes and PersistentVolumeClaims', 'notes', 0, $md$A container's own filesystem is thrown away when the container is replaced. That is fine for a web server, but a database that loses its files on every restart is useless. This lesson shows how Kubernetes gives pods storage that outlives them.

## Volume types at a glance

A **volume** is a directory that containers in a pod can mount. The volume *type* decides where the data really lives and how long it lasts:

| Type | Lives as long as | Use it for |
|---|---|---|
| `emptyDir` | the pod | Scratch space, sharing files between containers in one pod |
| `configMap` / `secret` | the object | Config files and credentials |
| `hostPath` | the node | Node agents that need node files (log collectors). Risky for apps: data stays on one node |
| `persistentVolumeClaim` | the claim (independent of the pod) | **Real app data**: databases, uploads |

For data you must keep, always use a **PersistentVolumeClaim**.

```knowledge-check
{ "questions": [
  { "id": "k8s-storage-types-q1", "type": "mcq",
    "prompt": "Which volume type should a PostgreSQL pod use for its data directory?",
    "options": [
      {"id": "a", "text": "emptyDir"},
      {"id": "b", "text": "configMap"},
      {"id": "c", "text": "A PersistentVolumeClaim"},
      {"id": "d", "text": "The container's own filesystem"}
    ],
    "correct": "c",
    "explanation": "Only a PVC-backed volume outlives the pod. emptyDir and the container filesystem are lost when the pod is removed." }
] }
```

## PersistentVolume and PersistentVolumeClaim

Kubernetes separates *providing* storage from *using* it:

- A **PersistentVolume (PV)** is a real piece of storage in the cluster: an NFS share, a cloud disk (AWS EBS, Azure Disk, GCE PD), a local disk. It is **cluster-wide** (not in a namespace). Usually the cluster admin or a provisioner creates it.
- A **PersistentVolumeClaim (PVC)** is a **request** for storage by an app: "I need 5 GiB, mounted read-write by one node." It lives in a namespace.
- Kubernetes **binds** each PVC to a matching PV. The pod only refers to the PVC and never needs to know whether it is NFS or a cloud disk.

Think of it like a parking lot: the PV is a parking space, the PVC is your ticket, and the pod just shows the ticket.

A PV backed by an NFS server:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysqlpv
  labels:
    app: mysql
spec:
  capacity:
    storage: 5Gi                       # Gi = 1024³ bytes; G = 1000³ bytes
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /
    server: 10.255.255.10              # IP of the NFS server
```

A PVC that asks for it:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysqlclaim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: ""                  # "" = bind to a pre-created PV, no dynamic provisioning
  selector:
    matchLabels:
      app: mysql                        # only PVs with this label
```

```bash
kubectl get pv                 # STATUS: Available → Bound
kubectl get pvc                # STATUS: Pending → Bound, VOLUME shows the PV name
kubectl describe pvc mysqlclaim
```

A PVC binds only to a PV that has at least the requested size, a matching access mode, a matching storage class, and matching labels (if a selector is set). If none fits, the PVC stays **Pending**, and so does any pod that uses it.

```knowledge-check
{ "questions": [
  { "id": "k8s-storage-pvpvc-q1", "type": "mcq",
    "prompt": "Which statement about PV and PVC is correct?",
    "options": [
      {"id": "a", "text": "A PVC is the actual disk; a PV is a request for it"},
      {"id": "b", "text": "A PV is a piece of storage in the cluster; a PVC is an app's request that gets bound to a PV"},
      {"id": "c", "text": "Pods mount PVs directly by name"},
      {"id": "d", "text": "PVs belong to a namespace, PVCs are cluster-wide"}
    ],
    "correct": "b",
    "explanation": "PV = supply (cluster-wide), PVC = demand (namespaced). Pods reference the PVC." },
  { "id": "k8s-storage-pvpvc-q2", "type": "mcq",
    "prompt": "A PVC asks for 10Gi, but the only PV offers 5Gi. What happens?",
    "options": [
      {"id": "a", "text": "It binds and uses only 5Gi"},
      {"id": "b", "text": "It stays Pending because no PV is large enough"},
      {"id": "c", "text": "The PV grows to 10Gi automatically"},
      {"id": "d", "text": "Two PVCs are created"}
    ],
    "correct": "b",
    "explanation": "A PV must satisfy the requested size, access mode and class. Otherwise the claim waits in Pending." }
] }
```

## Access modes

| Mode | Short | Meaning |
|---|---|---|
| `ReadWriteOnce` | RWO | Read-write by pods on **one node** at a time (most cloud block disks) |
| `ReadOnlyMany` | ROX | Read-only by many nodes |
| `ReadWriteMany` | RWX | Read-write by many nodes (NFS, CephFS, Azure Files, EFS) |
| `ReadWriteOncePod` | RWOP | Read-write by exactly **one pod** |

Access modes describe what the storage backend *can* do. A normal cloud disk is RWO, so you cannot share it across a 3-replica Deployment spread over 3 nodes. If you need shared files across nodes, use an RWX backend like NFS.

A related gotcha: a Deployment that uses an RWO volume should use the **`Recreate`** strategy. With RollingUpdate, the new pod may start on another node while the old pod still holds the disk, and it gets stuck.

```knowledge-check
{ "questions": [
  { "id": "k8s-storage-access-q1", "type": "mcq",
    "prompt": "Three web pods on three different nodes must write to the same upload folder. Which access mode do you need?",
    "options": [
      {"id": "a", "text": "ReadWriteOnce"},
      {"id": "b", "text": "ReadOnlyMany"},
      {"id": "c", "text": "ReadWriteMany"},
      {"id": "d", "text": "ReadWriteOncePod"}
    ],
    "correct": "c",
    "explanation": "Only RWX allows read-write from several nodes at once, and the backend must support it (for example NFS)." }
] }
```

## Reclaim policy: what happens when the claim is deleted

`persistentVolumeReclaimPolicy` decides what happens to the PV (and its data) after its PVC is deleted:

- **`Retain`**: the PV and the data are kept. The PV becomes `Released` and is **not** reused automatically; an admin must clean it up and delete or recreate the PV. Safest for important data.
- **`Delete`**: the PV and the underlying disk are deleted. This is the default for dynamically provisioned volumes, so **deleting a PVC can delete your data**.

```knowledge-check
{ "questions": [
  { "id": "k8s-storage-reclaim-q1", "type": "mcq",
    "prompt": "A dynamically provisioned PV has reclaim policy Delete. Someone deletes its PVC. What happens to the data?",
    "options": [
      {"id": "a", "text": "It is kept until the node restarts"},
      {"id": "b", "text": "The PV and the underlying disk are deleted, and the data is gone"},
      {"id": "c", "text": "It is moved to another PV"},
      {"id": "d", "text": "The PVC is recreated automatically"}
    ],
    "correct": "b",
    "explanation": "Delete removes the storage with the claim. Use Retain (or backups) for data you cannot lose." }
] }
```

## StorageClass and dynamic provisioning

Creating every PV by hand does not scale. A **StorageClass** describes a *kind* of storage (for example "fast SSD"), and a **provisioner** creates a PV automatically whenever a PVC asks for that class:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: ebs.csi.aws.com           # a CSI driver; each cloud or storage system has one
parameters:
  type: gp3
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer   # create the disk in the zone where the pod is scheduled
allowVolumeExpansion: true
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  storageClassName: fast
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 20Gi
```

- One StorageClass can be marked **default**. A PVC without `storageClassName` uses it. (`storageClassName: ""` explicitly means "no class, bind to a pre-created PV".)
- Storage drivers today are **CSI** (Container Storage Interface) plugins.
- With `allowVolumeExpansion: true` you can grow a volume by editing the PVC's requested size. You cannot shrink it.
- minikube, kind and k3s ship a simple default class (`standard` or `local-path`) so PVCs just work locally.

```bash
kubectl get storageclass
```

```knowledge-check
{ "questions": [
  { "id": "k8s-storage-sc-q1", "type": "mcq",
    "prompt": "On a cloud cluster with a default StorageClass, you create a PVC without storageClassName and no PV exists. What happens?",
    "options": [
      {"id": "a", "text": "The PVC stays Pending forever"},
      {"id": "b", "text": "The provisioner of the default StorageClass creates a new disk and PV, and the PVC binds to it"},
      {"id": "c", "text": "The PVC borrows space from another PVC"},
      {"id": "d", "text": "Kubernetes uses the node's root disk"}
    ],
    "correct": "b",
    "explanation": "That is dynamic provisioning: the StorageClass's provisioner creates the PV on demand." }
] }
```

## Using a PVC in a Deployment

Refer to the claim in `volumes`, then mount it:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysqldeployment
spec:
  replicas: 1
  strategy:
    type: Recreate                   # RWO disk: never run old and new pod at the same time
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.4
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysqlsecret
              key: password
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysqlvolume
          mountPath: /var/lib/mysql   # MySQL writes its data here
      volumes:
      - name: mysqlvolume
        persistentVolumeClaim:
          claimName: mysqlclaim
```

Now delete the pod, or drain its node. The new pod mounts the same claim and all data is still there. For more than one database replica, each with its own disk, use a StatefulSet with `volumeClaimTemplates` instead.

Storage is not a backup. A PV protects you from pod restarts, not from someone running `DROP TABLE`, or a disk failure. Use snapshots (`VolumeSnapshot`) or tools such as Velero for backups.

```knowledge-check
{ "questions": [
  { "id": "k8s-storage-deploy-q1", "type": "mcq",
    "prompt": "Why does the MySQL Deployment above use the Recreate strategy?",
    "options": [
      {"id": "a", "text": "MySQL images do not support RollingUpdate"},
      {"id": "b", "text": "The volume is ReadWriteOnce, so the old pod must release it before the new pod can mount it"},
      {"id": "c", "text": "Recreate is faster"},
      {"id": "d", "text": "Secrets only work with Recreate"}
    ],
    "correct": "b",
    "explanation": "With RollingUpdate the new pod could start (possibly on another node) while the old one still holds the RWO disk, and get stuck." }
] }
```

## Interview questions and real-world scenarios

**Q: Explain PV, PVC and StorageClass in one sentence each.**
PV: a piece of storage in the cluster. PVC: a namespaced request for storage that binds to one PV. StorageClass: a template that lets a provisioner create PVs on demand.

**Q: What are the access modes and which one does a cloud block disk support?**
RWO, ROX, RWX, RWOP. Block disks (EBS, Azure Disk, PD) are RWO; shared filesystems (EFS, Azure Files, NFS) give RWX.

**Q: What does `volumeBindingMode: WaitForFirstConsumer` do?**
It delays creating the volume until a pod using the claim is scheduled, so the disk is created in the same availability zone as the pod. Without it, a disk may be created in a zone where the pod can't run.

**Q: Retain vs Delete reclaim policy?**
Delete removes the disk when the PVC is deleted (default for dynamic volumes). Retain keeps the PV and data for manual recovery. Use Retain, or snapshots, for critical data.

**Q: How do you back up persistent data in Kubernetes?**
VolumeSnapshots via the CSI driver, Velero (objects + volumes), or application-level backups (pg_dump, etc.). An etcd backup does not include volume data.

**Real-world scenario: a pod is stuck in ContainerCreating with "Multi-Attach error".**
An RWO disk is still attached to another node, typically after a node failure or a RollingUpdate of a single-replica app. Use the Recreate strategy for such apps; for a dead node, the volume detaches after a timeout (or once the node is removed).

**Real-world scenario: someone deleted a namespace and the database data is gone.**
The PVCs were deleted with the namespace and the StorageClass policy was Delete. Prevention: Retain for important classes, regular backups, and RBAC so few people can delete namespaces.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-storage-int-q1",
      "type": "mcq",
      "prompt": "On a multi-zone cloud cluster, pods using a new PVC sometimes can't start because the disk is in a different zone. Which setting prevents this?",
      "options": [
        {
          "id": "a",
          "text": "accessModes: ReadWriteMany"
        },
        {
          "id": "b",
          "text": "volumeBindingMode: WaitForFirstConsumer on the StorageClass"
        },
        {
          "id": "c",
          "text": "persistentVolumeReclaimPolicy: Retain"
        },
        {
          "id": "d",
          "text": "storageClassName: \"\""
        }
      ],
      "correct": "b",
      "explanation": "WaitForFirstConsumer creates the disk only after the pod is scheduled, in that pod's zone."
    }
  ]
}
```
$md$, 40, $json$[{"id":"k8s-storage-types-q1","type":"mcq","correct":"c"},{"id":"k8s-storage-pvpvc-q1","type":"mcq","correct":"b"},{"id":"k8s-storage-pvpvc-q2","type":"mcq","correct":"b"},{"id":"k8s-storage-access-q1","type":"mcq","correct":"c"},{"id":"k8s-storage-reclaim-q1","type":"mcq","correct":"b"},{"id":"k8s-storage-sc-q1","type":"mcq","correct":"b"},{"id":"k8s-storage-deploy-q1","type":"mcq","correct":"b"},{"id":"k8s-storage-int-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('2c9b8b98-04e3-5f3b-9ad0-d613679763a1', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '45cb3c88-5b2a-5385-98b6-2763f2717d95', 'Lab: PersistentVolumes and Claims', 'lab', 1, 25)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('200053ab-0b4e-5000-8c2b-101de471d95c', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '2c9b8b98-04e3-5f3b-9ad0-d613679763a1', 'module', 'Lab: PersistentVolumes and Claims', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/pv.yaml <<'MFEOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysqlpv
  labels:
    app: mysql
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /
    server: 10.255.255.10

MFEOF
chmod 666 /home/labuser/work/pv.yaml
cat > /home/labuser/work/pvc.yaml <<'MFEOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysqlclaim
spec:
  accessModes:
  - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 5Gi
  storageClassName: ""
  selector:
    matchLabels:
      app: mysql

MFEOF
chmod 666 /home/labuser/work/pvc.yaml
cat > /home/labuser/work/deploy.yaml <<'MFEOF'
apiVersion: v1
kind: Secret
metadata:
  name: mysqlsecret
type: Opaque
stringData:
  password: P@ssw0rd!
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysqldeployment
  labels:
    app: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.4
        ports:
        - containerPort: 3306
        volumeMounts:
        - mountPath: "/var/lib/mysql"
          name: mysqlvolume
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysqlsecret
              key: password
      volumes:
      - name: mysqlvolume
        persistentVolumeClaim:
          claimName: mysqlclaim

MFEOF
chmod 666 /home/labuser/work/deploy.yaml
cat > /home/labuser/work/bigclaim.yaml <<'MFEOF'
# This claim stays Pending. Find out why.
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: bigclaim
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
  storageClassName: ""

MFEOF
chmod 666 /home/labuser/work/bigclaim.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '582e46bf-67ec-589b-aed3-09966b1e8e3a' AND id NOT IN ('9bf5b8fe-3f93-5f11-ab0e-6fa03838c292', '57c68976-6ad6-5b0b-814a-ebe9b8d9ee0a', 'b636ec7c-5ee6-547d-b81a-bf9397612a05', '109b2bc0-561a-5ce3-9e52-cf96ee7f948c', 'd5601179-2015-57c1-8bde-8ef0754fda73', '4623c937-d74b-5b32-b500-b9d82256e6c2');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '582e46bf-67ec-589b-aed3-09966b1e8e3a';
DELETE FROM lab_tasks WHERE lab_id = '200053ab-0b4e-5000-8c2b-101de471d95c' AND id NOT IN ('3dc812fa-ef5f-5f55-a6f5-ba5a593cead8', 'b7d4926f-3e95-5287-9e31-ab128892d724', '74cc3177-d1a9-5d5f-9ef5-3e7ff49f1bb2', 'a391dd55-31e7-5087-94bb-fc4bfbb37fc0', '14b26edf-2c03-5938-b218-eddab2b6f962', '8d9ba1b3-d5a7-51d0-af6c-8b2f7c12803f');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '200053ab-0b4e-5000-8c2b-101de471d95c';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('3dc812fa-ef5f-5f55-a6f5-ba5a593cead8', '200053ab-0b4e-5000-8c2b-101de471d95c', 1, 'Create a PersistentVolume', $md$Apply `pv.yaml` and run `kubectl get pv`. What is its STATUS? Notice that PVs are cluster-wide, so `-n` does not apply to them.$md$, $script$#!/bin/bash
kubectl get pv mysqlpv -o jsonpath='{.spec.capacity.storage} {.spec.persistentVolumeReclaimPolicy}' | grep -qx '5Gi Retain'
$script$, '`kubectl apply -f pv.yaml`', 'The PV is Available, meaning it exists but no claim uses it yet.', 10, false, true),
('b7d4926f-3e95-5287-9e31-ab128892d724', '200053ab-0b4e-5000-8c2b-101de471d95c', 2, 'Claim it', $md$Apply `pvc.yaml`. Check `kubectl get pv,pvc`. Both should now show `Bound`, and the claim's VOLUME column should name `mysqlpv`.$md$, $script$#!/bin/bash
test "$(kubectl get pvc mysqlclaim -o jsonpath='{.status.phase} {.spec.volumeName}')" = "Bound mysqlpv"
$script$, '`kubectl apply -f pvc.yaml`', 'The claim asked for 5Gi, RWO, no storage class, and a PV labeled app=mysql. mysqlpv matched all four, so they were bound one-to-one.', 15, false, true),
('74cc3177-d1a9-5d5f-9ef5-3e7ff49f1bb2', '200053ab-0b4e-5000-8c2b-101de471d95c', 3, 'Run MySQL on the claim', $md$Apply `deploy.yaml` (a Secret plus a MySQL Deployment). Use `kubectl describe pod -l app=mysql` and find the `Volumes:` section. Which claim does it use?$md$, $script$#!/bin/bash
test "$(kubectl get deployment mysqldeployment -o jsonpath='{.status.readyReplicas}')" = "1" || exit 1
kubectl get pods -l app=mysql -o jsonpath='{.items[0].spec.volumes[?(@.name=="mysqlvolume")].persistentVolumeClaim.claimName}' | grep -qx mysqlclaim
$script$, '`kubectl apply -f deploy.yaml`', 'The pod only knows the claim name. Where the data really lives (here an NFS share) is hidden behind the PV.', 15, false, true),
('a391dd55-31e7-5087-94bb-fc4bfbb37fc0', '200053ab-0b4e-5000-8c2b-101de471d95c', 4, 'Replace the pod and keep the storage', $md$Delete the MySQL pod. When the Deployment creates a new one, check that it mounts the same claim and that the PVC is still Bound to the same PV.$md$, $script$#!/bin/bash
D=$(date -d "$(kubectl get deployment mysqldeployment -o jsonpath='{.metadata.creationTimestamp}')" +%s)
P=$(date -d "$(kubectl get pods -l app=mysql -o jsonpath='{.items[0].metadata.creationTimestamp}')" +%s)
[ $((P - D)) -ge 3 ] || exit 1
test "$(kubectl get pvc mysqlclaim -o jsonpath='{.status.phase} {.spec.volumeName}')" = "Bound mysqlpv"
$script$, '`kubectl delete pod -l app=mysql`', 'The new pod mounted the same claim, so on a real cluster MySQL would find all its data again.', 10, false, true),
('14b26edf-2c03-5938-b218-eddab2b6f962', '200053ab-0b4e-5000-8c2b-101de471d95c', 5, 'Debug a Pending claim', $md$Apply `bigclaim.yaml`. It stays `Pending`. Run `kubectl describe pvc bigclaim` to see why. Then create a PV named `bigpv` that it **can** bind to (use `hostPath: {path: /data/big}` as the storage backend) and check that the claim becomes `Bound`.
$md$, $script$#!/bin/bash
test "$(kubectl get pvc bigclaim -o jsonpath='{.status.phase} {.spec.volumeName}')" = "Bound bigpv"
$script$, 'The claim needs at least 50Gi, access mode ReadWriteMany, and no storage class. Your PV must offer all of that.', 'A claim binds only when a PV satisfies size, access mode and storage class. mysqlpv was too small, RWO only, and already bound, so nothing matched until you added a suitable PV.', 20, false, false),
('8d9ba1b3-d5a7-51d0-af6c-8b2f7c12803f', '200053ab-0b4e-5000-8c2b-101de471d95c', 6, 'See what Retain does', $md$Delete the Deployment `mysqldeployment` and then the claim `mysqlclaim`. Check `kubectl get pv mysqlpv`. What is its STATUS now, and does a new claim get it automatically?$md$, $script$#!/bin/bash
! kubectl get pvc mysqlclaim >/dev/null 2>&1 || exit 1
test "$(kubectl get pv mysqlpv -o jsonpath='{.status.phase}')" = "Released"
$script$, '`kubectl delete deployment mysqldeployment`, then `kubectl delete pvc mysqlclaim`.', 'With Retain, the PV and its data are kept but the PV becomes Released and is not reused. An admin decides what to do with the data. With Delete, the disk would have been destroyed.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('582e46bf-67ec-589b-aed3-09966b1e8e3a', '200053ab-0b4e-5000-8c2b-101de471d95c', 1, $json$[{"id":"3dc812fa-ef5f-5f55-a6f5-ba5a593cead8","lab_id":"200053ab-0b4e-5000-8c2b-101de471d95c","position":1,"title":"Create a PersistentVolume","description":"Apply `pv.yaml` and run `kubectl get pv`. What is its STATUS? Notice that PVs are cluster-wide, so `-n` does not apply to them.","verification_script":"#!/bin/bash\nkubectl get pv mysqlpv -o jsonpath='{.spec.capacity.storage} {.spec.persistentVolumeReclaimPolicy}' | grep -qx '5Gi Retain'\n","hint_context":"`kubectl apply -f pv.yaml`","explanation_context":"The PV is Available, meaning it exists but no claim uses it yet.","points":10,"is_optional":false,"is_stateful":true},{"id":"b7d4926f-3e95-5287-9e31-ab128892d724","lab_id":"200053ab-0b4e-5000-8c2b-101de471d95c","position":2,"title":"Claim it","description":"Apply `pvc.yaml`. Check `kubectl get pv,pvc`. Both should now show `Bound`, and the claim's VOLUME column should name `mysqlpv`.","verification_script":"#!/bin/bash\ntest \"$(kubectl get pvc mysqlclaim -o jsonpath='{.status.phase} {.spec.volumeName}')\" = \"Bound mysqlpv\"\n","hint_context":"`kubectl apply -f pvc.yaml`","explanation_context":"The claim asked for 5Gi, RWO, no storage class, and a PV labeled app=mysql. mysqlpv matched all four, so they were bound one-to-one.","points":15,"is_optional":false,"is_stateful":true},{"id":"74cc3177-d1a9-5d5f-9ef5-3e7ff49f1bb2","lab_id":"200053ab-0b4e-5000-8c2b-101de471d95c","position":3,"title":"Run MySQL on the claim","description":"Apply `deploy.yaml` (a Secret plus a MySQL Deployment). Use `kubectl describe pod -l app=mysql` and find the `Volumes:` section. Which claim does it use?","verification_script":"#!/bin/bash\ntest \"$(kubectl get deployment mysqldeployment -o jsonpath='{.status.readyReplicas}')\" = \"1\" || exit 1\nkubectl get pods -l app=mysql -o jsonpath='{.items[0].spec.volumes[?(@.name==\"mysqlvolume\")].persistentVolumeClaim.claimName}' | grep -qx mysqlclaim\n","hint_context":"`kubectl apply -f deploy.yaml`","explanation_context":"The pod only knows the claim name. Where the data really lives (here an NFS share) is hidden behind the PV.","points":15,"is_optional":false,"is_stateful":true},{"id":"a391dd55-31e7-5087-94bb-fc4bfbb37fc0","lab_id":"200053ab-0b4e-5000-8c2b-101de471d95c","position":4,"title":"Replace the pod and keep the storage","description":"Delete the MySQL pod. When the Deployment creates a new one, check that it mounts the same claim and that the PVC is still Bound to the same PV.","verification_script":"#!/bin/bash\nD=$(date -d \"$(kubectl get deployment mysqldeployment -o jsonpath='{.metadata.creationTimestamp}')\" +%s)\nP=$(date -d \"$(kubectl get pods -l app=mysql -o jsonpath='{.items[0].metadata.creationTimestamp}')\" +%s)\n[ $((P - D)) -ge 3 ] || exit 1\ntest \"$(kubectl get pvc mysqlclaim -o jsonpath='{.status.phase} {.spec.volumeName}')\" = \"Bound mysqlpv\"\n","hint_context":"`kubectl delete pod -l app=mysql`","explanation_context":"The new pod mounted the same claim, so on a real cluster MySQL would find all its data again.","points":10,"is_optional":false,"is_stateful":true},{"id":"14b26edf-2c03-5938-b218-eddab2b6f962","lab_id":"200053ab-0b4e-5000-8c2b-101de471d95c","position":5,"title":"Debug a Pending claim","description":"Apply `bigclaim.yaml`. It stays `Pending`. Run `kubectl describe pvc bigclaim` to see why. Then create a PV named `bigpv` that it **can** bind to (use `hostPath: {path: /data/big}` as the storage backend) and check that the claim becomes `Bound`.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get pvc bigclaim -o jsonpath='{.status.phase} {.spec.volumeName}')\" = \"Bound bigpv\"\n","hint_context":"The claim needs at least 50Gi, access mode ReadWriteMany, and no storage class. Your PV must offer all of that.","explanation_context":"A claim binds only when a PV satisfies size, access mode and storage class. mysqlpv was too small, RWO only, and already bound, so nothing matched until you added a suitable PV.","points":20,"is_optional":false,"is_stateful":false},{"id":"8d9ba1b3-d5a7-51d0-af6c-8b2f7c12803f","lab_id":"200053ab-0b4e-5000-8c2b-101de471d95c","position":6,"title":"See what Retain does","description":"Delete the Deployment `mysqldeployment` and then the claim `mysqlclaim`. Check `kubectl get pv mysqlpv`. What is its STATUS now, and does a new claim get it automatically?","verification_script":"#!/bin/bash\n! kubectl get pvc mysqlclaim \u003e/dev/null 2\u003e\u00261 || exit 1\ntest \"$(kubectl get pv mysqlpv -o jsonpath='{.status.phase}')\" = \"Released\"\n","hint_context":"`kubectl delete deployment mysqldeployment`, then `kubectl delete pvc mysqlclaim`.","explanation_context":"With Retain, the PV and its data are kept but the PV becomes Released and is not reused. An admin decides what to do with the data. With Delete, the disk would have been destroyed.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('9bf5b8fe-3f93-5f11-ab0e-6fa03838c292', '582e46bf-67ec-589b-aed3-09966b1e8e3a', '3dc812fa-ef5f-5f55-a6f5-ba5a593cead8', 1, 'Create a PersistentVolume', $md$Apply `pv.yaml` and run `kubectl get pv`. What is its STATUS? Notice that PVs are cluster-wide, so `-n` does not apply to them.$md$, $script$#!/bin/bash
kubectl get pv mysqlpv -o jsonpath='{.spec.capacity.storage} {.spec.persistentVolumeReclaimPolicy}' | grep -qx '5Gi Retain'
$script$, '`kubectl apply -f pv.yaml`', 'The PV is Available, meaning it exists but no claim uses it yet.', 10, false, true),
('57c68976-6ad6-5b0b-814a-ebe9b8d9ee0a', '582e46bf-67ec-589b-aed3-09966b1e8e3a', 'b7d4926f-3e95-5287-9e31-ab128892d724', 2, 'Claim it', $md$Apply `pvc.yaml`. Check `kubectl get pv,pvc`. Both should now show `Bound`, and the claim's VOLUME column should name `mysqlpv`.$md$, $script$#!/bin/bash
test "$(kubectl get pvc mysqlclaim -o jsonpath='{.status.phase} {.spec.volumeName}')" = "Bound mysqlpv"
$script$, '`kubectl apply -f pvc.yaml`', 'The claim asked for 5Gi, RWO, no storage class, and a PV labeled app=mysql. mysqlpv matched all four, so they were bound one-to-one.', 15, false, true),
('b636ec7c-5ee6-547d-b81a-bf9397612a05', '582e46bf-67ec-589b-aed3-09966b1e8e3a', '74cc3177-d1a9-5d5f-9ef5-3e7ff49f1bb2', 3, 'Run MySQL on the claim', $md$Apply `deploy.yaml` (a Secret plus a MySQL Deployment). Use `kubectl describe pod -l app=mysql` and find the `Volumes:` section. Which claim does it use?$md$, $script$#!/bin/bash
test "$(kubectl get deployment mysqldeployment -o jsonpath='{.status.readyReplicas}')" = "1" || exit 1
kubectl get pods -l app=mysql -o jsonpath='{.items[0].spec.volumes[?(@.name=="mysqlvolume")].persistentVolumeClaim.claimName}' | grep -qx mysqlclaim
$script$, '`kubectl apply -f deploy.yaml`', 'The pod only knows the claim name. Where the data really lives (here an NFS share) is hidden behind the PV.', 15, false, true),
('109b2bc0-561a-5ce3-9e52-cf96ee7f948c', '582e46bf-67ec-589b-aed3-09966b1e8e3a', 'a391dd55-31e7-5087-94bb-fc4bfbb37fc0', 4, 'Replace the pod and keep the storage', $md$Delete the MySQL pod. When the Deployment creates a new one, check that it mounts the same claim and that the PVC is still Bound to the same PV.$md$, $script$#!/bin/bash
D=$(date -d "$(kubectl get deployment mysqldeployment -o jsonpath='{.metadata.creationTimestamp}')" +%s)
P=$(date -d "$(kubectl get pods -l app=mysql -o jsonpath='{.items[0].metadata.creationTimestamp}')" +%s)
[ $((P - D)) -ge 3 ] || exit 1
test "$(kubectl get pvc mysqlclaim -o jsonpath='{.status.phase} {.spec.volumeName}')" = "Bound mysqlpv"
$script$, '`kubectl delete pod -l app=mysql`', 'The new pod mounted the same claim, so on a real cluster MySQL would find all its data again.', 10, false, true),
('d5601179-2015-57c1-8bde-8ef0754fda73', '582e46bf-67ec-589b-aed3-09966b1e8e3a', '14b26edf-2c03-5938-b218-eddab2b6f962', 5, 'Debug a Pending claim', $md$Apply `bigclaim.yaml`. It stays `Pending`. Run `kubectl describe pvc bigclaim` to see why. Then create a PV named `bigpv` that it **can** bind to (use `hostPath: {path: /data/big}` as the storage backend) and check that the claim becomes `Bound`.
$md$, $script$#!/bin/bash
test "$(kubectl get pvc bigclaim -o jsonpath='{.status.phase} {.spec.volumeName}')" = "Bound bigpv"
$script$, 'The claim needs at least 50Gi, access mode ReadWriteMany, and no storage class. Your PV must offer all of that.', 'A claim binds only when a PV satisfies size, access mode and storage class. mysqlpv was too small, RWO only, and already bound, so nothing matched until you added a suitable PV.', 20, false, false),
('4623c937-d74b-5b32-b500-b9d82256e6c2', '582e46bf-67ec-589b-aed3-09966b1e8e3a', '8d9ba1b3-d5a7-51d0-af6c-8b2f7c12803f', 6, 'See what Retain does', $md$Delete the Deployment `mysqldeployment` and then the claim `mysqlclaim`. Check `kubectl get pv mysqlpv`. What is its STATUS now, and does a new claim get it automatically?$md$, $script$#!/bin/bash
! kubectl get pvc mysqlclaim >/dev/null 2>&1 || exit 1
test "$(kubectl get pv mysqlpv -o jsonpath='{.status.phase}')" = "Released"
$script$, '`kubectl delete deployment mysqldeployment`, then `kubectl delete pvc mysqlclaim`.', 'With Retain, the PV and its data are kept but the PV becomes Released and is not reused. An admin decides what to do with the data. With Delete, the disk would have been destroyed.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '582e46bf-67ec-589b-aed3-09966b1e8e3a', updated_at = now()
WHERE id = '200053ab-0b4e-5000-8c2b-101de471d95c' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('06227c73-9418-59e7-8361-7ee37e05c62a', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which object does a pod reference to use persistent storage?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b7d6d2d4-6a9f-5109-8003-f05f0f969d5c', '06227c73-9418-59e7-8361-7ee37e05c62a', 1, $json${"prompt":"Which object does a pod reference to use persistent storage?","multiple":false,"options":[{"id":"a","text":"The PersistentVolume, by name","is_correct":false},{"id":"b","text":"The PersistentVolumeClaim, by name","is_correct":true},{"id":"c","text":"The StorageClass","is_correct":false},{"id":"d","text":"The node's disk path","is_correct":false}],"explanation":"Pods reference claims. The claim is bound to a PV, which hides the storage details."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('bfb4ca2f-579f-54ff-bf4b-fb7ae9d08efa', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which of these is namespaced?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1d69e022-4e5b-51f8-87e4-cb5fed1acb13', 'bfb4ca2f-579f-54ff-bf4b-fb7ae9d08efa', 1, $json${"prompt":"Which of these is namespaced?","multiple":false,"options":[{"id":"a","text":"PersistentVolume","is_correct":false},{"id":"b","text":"StorageClass","is_correct":false},{"id":"c","text":"PersistentVolumeClaim","is_correct":true},{"id":"d","text":"Node","is_correct":false}],"explanation":"PVCs live in a namespace next to the pods that use them. PVs and StorageClasses are cluster-wide."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b180b6b4-ded9-5236-98d6-7d0d2824bcf5', '00000000-0000-0000-0000-000000000001', 'mcq', 'A PVC stays Pending and no StorageClass provisioner exists. Which is a likely...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('440877c9-d08c-5990-b21c-c2e925bb1c00', 'b180b6b4-ded9-5236-98d6-7d0d2824bcf5', 1, $json${"prompt":"A PVC stays Pending and no StorageClass provisioner exists. Which is a likely cause?","multiple":false,"options":[{"id":"a","text":"No PV offers enough capacity with a matching access mode and storage class","is_correct":true},{"id":"b","text":"The pod has too many containers","is_correct":false},{"id":"c","text":"The namespace has no Service","is_correct":false},{"id":"d","text":"The PVC name is too long","is_correct":false}],"explanation":"Static binding needs a PV that satisfies size, access mode, class, and any label selector."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('547627d1-cadc-581a-add7-20cd36e743f2', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which access mode lets pods on several nodes write to the same volume?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9f45fff2-7d6c-53c7-863a-cbf933c5de0e', '547627d1-cadc-581a-add7-20cd36e743f2', 1, $json${"prompt":"Which access mode lets pods on several nodes write to the same volume?","multiple":false,"options":[{"id":"a","text":"ReadWriteOnce","is_correct":false},{"id":"b","text":"ReadOnlyMany","is_correct":false},{"id":"c","text":"ReadWriteMany","is_correct":true},{"id":"d","text":"ReadWriteOncePod","is_correct":false}],"explanation":"RWX allows read-write from many nodes; the backend (for example NFS) must support it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c066eff2-6290-5ee0-96a8-dcc11a9c097a', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does the Retain reclaim policy do when the PVC is deleted?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f0204c10-eeaa-51a1-b745-38d7e68d03b2', 'c066eff2-6290-5ee0-96a8-dcc11a9c097a', 1, $json${"prompt":"What does the Retain reclaim policy do when the PVC is deleted?","multiple":false,"options":[{"id":"a","text":"Deletes the disk immediately","is_correct":false},{"id":"b","text":"Keeps the PV and its data; the PV becomes Released and must be handled by an admin","is_correct":true},{"id":"c","text":"Binds the PV to the next PVC automatically","is_correct":false},{"id":"d","text":"Wipes the data but keeps the PV Available","is_correct":false}],"explanation":"Retain protects the data. A Released PV is not reused until an admin cleans it up."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('396d86b7-bd9b-50dd-9a6c-08fba7b4d3ad', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does a StorageClass enable?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e5d3f35b-6dd8-5016-9123-8b7828a62613', '396d86b7-bd9b-50dd-9a6c-08fba7b4d3ad', 1, $json${"prompt":"What does a StorageClass enable?","multiple":false,"options":[{"id":"a","text":"Dynamic provisioning, where a PV is created automatically for each matching PVC","is_correct":true},{"id":"b","text":"Encryption of Secrets","is_correct":false},{"id":"c","text":"Sharing emptyDir between pods","is_correct":false},{"id":"d","text":"Faster container startup","is_correct":false}],"explanation":"The StorageClass's provisioner (a CSI driver) creates volumes on demand."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('68a4ffba-9464-5bdc-8e1e-e93fc68b76c7', '00000000-0000-0000-0000-000000000001', 'mcq', 'Can you shrink a PVC from 20Gi to 10Gi by editing it?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('78dde602-63c2-55af-b45e-f6431ed94eda', '68a4ffba-9464-5bdc-8e1e-e93fc68b76c7', 1, $json${"prompt":"Can you shrink a PVC from 20Gi to 10Gi by editing it?","multiple":false,"options":[{"id":"a","text":"Yes, always","is_correct":false},{"id":"b","text":"No; volumes can only be expanded (if the StorageClass allows it), never shrunk","is_correct":true},{"id":"c","text":"Yes, but only for NFS","is_correct":false},{"id":"d","text":"Only by deleting the StorageClass","is_correct":false}],"explanation":"allowVolumeExpansion lets you grow a claim. Shrinking is not supported; copy the data to a new, smaller volume instead."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('3c9d30f7-da68-5b39-b515-dcb22b6001a8', '00000000-0000-0000-0000-000000000001', 'Quiz: Storage', 'k8s-storage-quiz', 'Quiz covering Storage.', 'mcq', 'published', 'module', '84d409b8-6874-55e2-baad-70c3d9ca0b97', 15, 70, 5, 7, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '3c9d30f7-da68-5b39-b515-dcb22b6001a8' AND question_id NOT IN ('06227c73-9418-59e7-8361-7ee37e05c62a', 'bfb4ca2f-579f-54ff-bf4b-fb7ae9d08efa', 'b180b6b4-ded9-5236-98d6-7d0d2824bcf5', '547627d1-cadc-581a-add7-20cd36e743f2', 'c066eff2-6290-5ee0-96a8-dcc11a9c097a', '396d86b7-bd9b-50dd-9a6c-08fba7b4d3ad', '68a4ffba-9464-5bdc-8e1e-e93fc68b76c7');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('d52130d0-e7ac-5c75-8fbf-5237e7ab0c6c', '3c9d30f7-da68-5b39-b515-dcb22b6001a8', '06227c73-9418-59e7-8361-7ee37e05c62a', 'b7d6d2d4-6a9f-5109-8003-f05f0f969d5c', 0, 1),
('ca2ba92b-a7b6-5f0e-8158-9670951897cd', '3c9d30f7-da68-5b39-b515-dcb22b6001a8', 'bfb4ca2f-579f-54ff-bf4b-fb7ae9d08efa', '1d69e022-4e5b-51f8-87e4-cb5fed1acb13', 1, 1),
('648e4a7a-38be-50d6-a639-78049f6950b7', '3c9d30f7-da68-5b39-b515-dcb22b6001a8', 'b180b6b4-ded9-5236-98d6-7d0d2824bcf5', '440877c9-d08c-5990-b21c-c2e925bb1c00', 2, 1),
('1c4c2709-eb58-5afd-900d-7c4306b7b51c', '3c9d30f7-da68-5b39-b515-dcb22b6001a8', '547627d1-cadc-581a-add7-20cd36e743f2', '9f45fff2-7d6c-53c7-863a-cbf933c5de0e', 3, 1),
('109ff01c-a662-56ae-81ad-df4b1b4a8c5f', '3c9d30f7-da68-5b39-b515-dcb22b6001a8', 'c066eff2-6290-5ee0-96a8-dcc11a9c097a', 'f0204c10-eeaa-51a1-b745-38d7e68d03b2', 4, 1),
('22309358-3545-54b1-8bfc-a1a77431d453', '3c9d30f7-da68-5b39-b515-dcb22b6001a8', '396d86b7-bd9b-50dd-9a6c-08fba7b4d3ad', 'e5d3f35b-6dd8-5016-9123-8b7828a62613', 5, 1),
('e28048d5-7643-55d4-bafa-db2035880fc6', '3c9d30f7-da68-5b39-b515-dcb22b6001a8', '68a4ffba-9464-5bdc-8e1e-e93fc68b76c7', '78dde602-63c2-55af-b45e-f6431ed94eda', 6, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('84d409b8-6874-55e2-baad-70c3d9ca0b97', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '45cb3c88-5b2a-5385-98b6-2763f2717d95', 'Quiz: Storage', 'assessment', 2, 10, '3c9d30f7-da68-5b39-b515-dcb22b6001a8')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Health, Resources & Scheduling
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('52756a52-681c-5932-95e7-9e7f879beff3', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Health, Resources & Scheduling', 7)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('f4456cb5-eba5-5925-9b53-bb8b6b2f4ded', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '52756a52-681c-5932-95e7-9e7f879beff3', 'Health Probes, Resources and Scheduling Rules', 'notes', 0, $md$So far Kubernetes has placed pods wherever it liked and assumed they were healthy as long as the process was running. Real apps need more: detecting a frozen app, not sending traffic to a pod that is still starting, reserving enough CPU and memory, and keeping certain pods on certain machines. This lesson covers all four.

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
$md$, 60, $json$[{"id":"k8s-sched-probes-q1","type":"mcq","correct":"b"},{"id":"k8s-sched-probes-q2","type":"mcq","correct":"b"},{"id":"k8s-sched-writeprobe-q1","type":"mcq","correct":"b"},{"id":"k8s-sched-writeprobe-q2","type":"mcq","correct":"b"},{"id":"k8s-sched-resources-q1","type":"mcq","correct":"b"},{"id":"k8s-sched-resources-q2","type":"mcq","correct":"b"},{"id":"k8s-sched-resources-q3","type":"mcq","correct":"c"},{"id":"k8s-sched-quota-q1","type":"mcq","correct":"b"},{"id":"k8s-sched-quota-q2","type":"mcq","correct":"b"},{"id":"k8s-sched-affinity-q1","type":"mcq","correct":"b"},{"id":"k8s-sched-affinity-q2","type":"mcq","correct":"b"},{"id":"k8s-sched-spread-q1","type":"mcq","correct":"b"},{"id":"k8s-sched-taint-q1","type":"mcq","correct":"b"},{"id":"k8s-sched-taint-q2","type":"mcq","correct":"b"},{"id":"k8s-sched-int-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('3f32decd-a21f-5364-9ff2-51fb58bd6ade', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '52756a52-681c-5932-95e7-9e7f879beff3', 'Lab: Probes and Resources', 'lab', 1, 30)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('7c9b2dc7-980f-5474-b333-061e60f64c3c', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '3f32decd-a21f-5364-9ff2-51fb58bd6ade', 'module', 'Lab: Probes and Resources', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/liveness.yaml <<'MFEOF'
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-http
spec:
  containers:
  - name: liveness
    image: registry.k8s.io/e2e-test-images/agnhost:2.40
    args: ["liveness"]
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
        httpHeaders:
        - name: Custom-Header
          value: Awesome
      initialDelaySeconds: 3
      periodSeconds: 3
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-exec
spec:
  containers:
  - name: liveness
    image: busybox:1.36
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
---
apiVersion: v1
kind: Pod
metadata:
  name: goproxy
  labels:
    app: goproxy
spec:
  containers:
  - name: goproxy
    image: registry.k8s.io/goproxy:0.1
    ports:
    - containerPort: 8080
    livenessProbe:
      tcpSocket:
        port: 8080
      initialDelaySeconds: 15
      periodSeconds: 20

MFEOF
chmod 666 /home/labuser/work/liveness.yaml
cat > /home/labuser/work/web.yaml <<'MFEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80

MFEOF
chmod 666 /home/labuser/work/web.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '0eaedfda-dd2b-59b1-a546-6e2e3c5ac7a2' AND id NOT IN ('0cb87f5b-0be7-5f20-8b8d-c851b98912a5', 'f63f868f-5287-5003-b8fe-74fae6a4f292', '8ce9bb2a-4e04-5caf-a6ae-954ee7db4060', '890511b5-7ff7-571e-b79e-a475e5522767');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '0eaedfda-dd2b-59b1-a546-6e2e3c5ac7a2';
DELETE FROM lab_tasks WHERE lab_id = '7c9b2dc7-980f-5474-b333-061e60f64c3c' AND id NOT IN ('2339060a-3baf-5a6a-adaf-69b537bf8fcf', 'cac9fb1a-68fc-5986-8307-e4ee33390667', '8e441491-4802-58be-92b2-258e120e82c5', '5c18bba2-3f17-55e0-becb-a7a04645523c');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '7c9b2dc7-980f-5474-b333-061e60f64c3c';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('2339060a-3baf-5a6a-adaf-69b537bf8fcf', '7c9b2dc7-980f-5474-b333-061e60f64c3c', 1, 'Create pods with the three probe types', $md$Apply `liveness.yaml`. Use `kubectl describe pod liveness-http`, `liveness-exec` and `goproxy` and find the `Liveness:` line for each: HTTP, exec and TCP.

On a real cluster, `liveness-exec` deletes its health file after 30 seconds, so its RESTARTS counter starts climbing. Simulated nodes do not run probes, so here you only inspect the configuration.
$md$, $script$#!/bin/bash
kubectl get pod liveness-http -o jsonpath='{.spec.containers[0].livenessProbe.httpGet.path}' | grep -qx /healthz || exit 1
kubectl get pod liveness-exec -o jsonpath='{.spec.containers[0].livenessProbe.exec.command[1]}' | grep -qx /tmp/healthy || exit 1
kubectl get pod goproxy -o jsonpath='{.spec.containers[0].livenessProbe.tcpSocket.port}' | grep -qx 8080
$script$, '`kubectl apply -f liveness.yaml`', 'httpGet passes on a 200-399 status, exec passes on exit code 0, and tcpSocket passes when the port accepts a connection.', 10, false, true),
('cac9fb1a-68fc-5986-8307-e4ee33390667', '7c9b2dc7-980f-5474-b333-061e60f64c3c', 2, 'Add readiness and liveness probes to a Deployment', $md$Edit `web.yaml` so the `nginx` container has:
- a **readinessProbe**: `httpGet` on path `/` port `80`, `periodSeconds: 5`
- a **livenessProbe**: `tcpSocket` on port `80`, `initialDelaySeconds: 10`

Apply it.
$md$, $script$#!/bin/bash
C='{.spec.template.spec.containers[0]'
test "$(kubectl get deploy web -o jsonpath="$C.readinessProbe.httpGet.path}|$C.readinessProbe.httpGet.port}|$C.readinessProbe.periodSeconds}")" = "/|80|5" || exit 1
test "$(kubectl get deploy web -o jsonpath="$C.livenessProbe.tcpSocket.port}|$C.livenessProbe.initialDelaySeconds}")" = "80|10"
$script$, 'Both probes go inside the container entry, at the same level as `image` and `ports`.', 'Readiness keeps a pod out of Service endpoints until nginx answers on /. Liveness restarts the container if port 80 stops accepting connections.', 20, false, true),
('8e441491-4802-58be-92b2-258e120e82c5', '7c9b2dc7-980f-5474-b333-061e60f64c3c', 3, 'Give the Deployment the Guaranteed QoS class', $md$Set resources on the `nginx` container of `web` so its pods get the **Guaranteed** QoS class: CPU `250m` and memory `128Mi` for both requests and limits. Check with `kubectl get pods -l app=web -o jsonpath='{.items[*].status.qosClass}'`.
$md$, $script$#!/bin/bash
test "$(kubectl get deploy web -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}|{.spec.template.spec.containers[0].resources.limits.memory}')" = "250m|128Mi" || exit 1
Q=$(kubectl get pods -l app=web -o jsonpath='{range .items[*]}{.status.qosClass}{"\n"}{end}' | sort -u)
test "$Q" = "Guaranteed"
$script$, '`kubectl set resources deployment web -c nginx --requests=cpu=250m,memory=128Mi --limits=cpu=250m,memory=128Mi` works, or edit the YAML.', 'Requests equal to limits for both CPU and memory make the pod Guaranteed. Changing resources changes the pod template, so the Deployment rolled out new pods.', 20, false, true),
('5c18bba2-3f17-55e0-becb-a7a04645523c', '7c9b2dc7-980f-5474-b333-061e60f64c3c', 4, 'Ask for more than any node has', $md$Create a pod `hungry` (image `nginx:1.27`) that requests `cpu: 64`. Nodes here have 32 CPUs. Check its status and read the reason in `kubectl describe pod hungry`.
$md$, $script$#!/bin/bash
test "$(kubectl get pod hungry -o jsonpath='{.status.phase}')" = "Pending" || exit 1
kubectl get pod hungry -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")].message}' | grep -qi 'insufficient cpu'
$script$, '`kubectl run hungry --image=nginx:1.27 --overrides=''{"spec":{"containers":[{"name":"hungry","image":"nginx:1.27","resources":{"requests":{"cpu":"64"}}}]}}''`, or write a small YAML file.', 'The scheduler only places a pod where its requests fit. The Events show "Insufficient cpu", the message you will see on real clusters when nodes are full.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('0eaedfda-dd2b-59b1-a546-6e2e3c5ac7a2', '7c9b2dc7-980f-5474-b333-061e60f64c3c', 1, $json$[{"id":"2339060a-3baf-5a6a-adaf-69b537bf8fcf","lab_id":"7c9b2dc7-980f-5474-b333-061e60f64c3c","position":1,"title":"Create pods with the three probe types","description":"Apply `liveness.yaml`. Use `kubectl describe pod liveness-http`, `liveness-exec` and `goproxy` and find the `Liveness:` line for each: HTTP, exec and TCP.\n\nOn a real cluster, `liveness-exec` deletes its health file after 30 seconds, so its RESTARTS counter starts climbing. Simulated nodes do not run probes, so here you only inspect the configuration.\n","verification_script":"#!/bin/bash\nkubectl get pod liveness-http -o jsonpath='{.spec.containers[0].livenessProbe.httpGet.path}' | grep -qx /healthz || exit 1\nkubectl get pod liveness-exec -o jsonpath='{.spec.containers[0].livenessProbe.exec.command[1]}' | grep -qx /tmp/healthy || exit 1\nkubectl get pod goproxy -o jsonpath='{.spec.containers[0].livenessProbe.tcpSocket.port}' | grep -qx 8080\n","hint_context":"`kubectl apply -f liveness.yaml`","explanation_context":"httpGet passes on a 200-399 status, exec passes on exit code 0, and tcpSocket passes when the port accepts a connection.","points":10,"is_optional":false,"is_stateful":true},{"id":"cac9fb1a-68fc-5986-8307-e4ee33390667","lab_id":"7c9b2dc7-980f-5474-b333-061e60f64c3c","position":2,"title":"Add readiness and liveness probes to a Deployment","description":"Edit `web.yaml` so the `nginx` container has:\n- a **readinessProbe**: `httpGet` on path `/` port `80`, `periodSeconds: 5`\n- a **livenessProbe**: `tcpSocket` on port `80`, `initialDelaySeconds: 10`\n\nApply it.\n","verification_script":"#!/bin/bash\nC='{.spec.template.spec.containers[0]'\ntest \"$(kubectl get deploy web -o jsonpath=\"$C.readinessProbe.httpGet.path}|$C.readinessProbe.httpGet.port}|$C.readinessProbe.periodSeconds}\")\" = \"/|80|5\" || exit 1\ntest \"$(kubectl get deploy web -o jsonpath=\"$C.livenessProbe.tcpSocket.port}|$C.livenessProbe.initialDelaySeconds}\")\" = \"80|10\"\n","hint_context":"Both probes go inside the container entry, at the same level as `image` and `ports`.","explanation_context":"Readiness keeps a pod out of Service endpoints until nginx answers on /. Liveness restarts the container if port 80 stops accepting connections.","points":20,"is_optional":false,"is_stateful":true},{"id":"8e441491-4802-58be-92b2-258e120e82c5","lab_id":"7c9b2dc7-980f-5474-b333-061e60f64c3c","position":3,"title":"Give the Deployment the Guaranteed QoS class","description":"Set resources on the `nginx` container of `web` so its pods get the **Guaranteed** QoS class: CPU `250m` and memory `128Mi` for both requests and limits. Check with `kubectl get pods -l app=web -o jsonpath='{.items[*].status.qosClass}'`.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get deploy web -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}|{.spec.template.spec.containers[0].resources.limits.memory}')\" = \"250m|128Mi\" || exit 1\nQ=$(kubectl get pods -l app=web -o jsonpath='{range .items[*]}{.status.qosClass}{\"\\n\"}{end}' | sort -u)\ntest \"$Q\" = \"Guaranteed\"\n","hint_context":"`kubectl set resources deployment web -c nginx --requests=cpu=250m,memory=128Mi --limits=cpu=250m,memory=128Mi` works, or edit the YAML.","explanation_context":"Requests equal to limits for both CPU and memory make the pod Guaranteed. Changing resources changes the pod template, so the Deployment rolled out new pods.","points":20,"is_optional":false,"is_stateful":true},{"id":"5c18bba2-3f17-55e0-becb-a7a04645523c","lab_id":"7c9b2dc7-980f-5474-b333-061e60f64c3c","position":4,"title":"Ask for more than any node has","description":"Create a pod `hungry` (image `nginx:1.27`) that requests `cpu: 64`. Nodes here have 32 CPUs. Check its status and read the reason in `kubectl describe pod hungry`.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get pod hungry -o jsonpath='{.status.phase}')\" = \"Pending\" || exit 1\nkubectl get pod hungry -o jsonpath='{.status.conditions[?(@.type==\"PodScheduled\")].message}' | grep -qi 'insufficient cpu'\n","hint_context":"`kubectl run hungry --image=nginx:1.27 --overrides='{\"spec\":{\"containers\":[{\"name\":\"hungry\",\"image\":\"nginx:1.27\",\"resources\":{\"requests\":{\"cpu\":\"64\"}}}]}}'`, or write a small YAML file.","explanation_context":"The scheduler only places a pod where its requests fit. The Events show \"Insufficient cpu\", the message you will see on real clusters when nodes are full.","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('0cb87f5b-0be7-5f20-8b8d-c851b98912a5', '0eaedfda-dd2b-59b1-a546-6e2e3c5ac7a2', '2339060a-3baf-5a6a-adaf-69b537bf8fcf', 1, 'Create pods with the three probe types', $md$Apply `liveness.yaml`. Use `kubectl describe pod liveness-http`, `liveness-exec` and `goproxy` and find the `Liveness:` line for each: HTTP, exec and TCP.

On a real cluster, `liveness-exec` deletes its health file after 30 seconds, so its RESTARTS counter starts climbing. Simulated nodes do not run probes, so here you only inspect the configuration.
$md$, $script$#!/bin/bash
kubectl get pod liveness-http -o jsonpath='{.spec.containers[0].livenessProbe.httpGet.path}' | grep -qx /healthz || exit 1
kubectl get pod liveness-exec -o jsonpath='{.spec.containers[0].livenessProbe.exec.command[1]}' | grep -qx /tmp/healthy || exit 1
kubectl get pod goproxy -o jsonpath='{.spec.containers[0].livenessProbe.tcpSocket.port}' | grep -qx 8080
$script$, '`kubectl apply -f liveness.yaml`', 'httpGet passes on a 200-399 status, exec passes on exit code 0, and tcpSocket passes when the port accepts a connection.', 10, false, true),
('f63f868f-5287-5003-b8fe-74fae6a4f292', '0eaedfda-dd2b-59b1-a546-6e2e3c5ac7a2', 'cac9fb1a-68fc-5986-8307-e4ee33390667', 2, 'Add readiness and liveness probes to a Deployment', $md$Edit `web.yaml` so the `nginx` container has:
- a **readinessProbe**: `httpGet` on path `/` port `80`, `periodSeconds: 5`
- a **livenessProbe**: `tcpSocket` on port `80`, `initialDelaySeconds: 10`

Apply it.
$md$, $script$#!/bin/bash
C='{.spec.template.spec.containers[0]'
test "$(kubectl get deploy web -o jsonpath="$C.readinessProbe.httpGet.path}|$C.readinessProbe.httpGet.port}|$C.readinessProbe.periodSeconds}")" = "/|80|5" || exit 1
test "$(kubectl get deploy web -o jsonpath="$C.livenessProbe.tcpSocket.port}|$C.livenessProbe.initialDelaySeconds}")" = "80|10"
$script$, 'Both probes go inside the container entry, at the same level as `image` and `ports`.', 'Readiness keeps a pod out of Service endpoints until nginx answers on /. Liveness restarts the container if port 80 stops accepting connections.', 20, false, true),
('8ce9bb2a-4e04-5caf-a6ae-954ee7db4060', '0eaedfda-dd2b-59b1-a546-6e2e3c5ac7a2', '8e441491-4802-58be-92b2-258e120e82c5', 3, 'Give the Deployment the Guaranteed QoS class', $md$Set resources on the `nginx` container of `web` so its pods get the **Guaranteed** QoS class: CPU `250m` and memory `128Mi` for both requests and limits. Check with `kubectl get pods -l app=web -o jsonpath='{.items[*].status.qosClass}'`.
$md$, $script$#!/bin/bash
test "$(kubectl get deploy web -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}|{.spec.template.spec.containers[0].resources.limits.memory}')" = "250m|128Mi" || exit 1
Q=$(kubectl get pods -l app=web -o jsonpath='{range .items[*]}{.status.qosClass}{"\n"}{end}' | sort -u)
test "$Q" = "Guaranteed"
$script$, '`kubectl set resources deployment web -c nginx --requests=cpu=250m,memory=128Mi --limits=cpu=250m,memory=128Mi` works, or edit the YAML.', 'Requests equal to limits for both CPU and memory make the pod Guaranteed. Changing resources changes the pod template, so the Deployment rolled out new pods.', 20, false, true),
('890511b5-7ff7-571e-b79e-a475e5522767', '0eaedfda-dd2b-59b1-a546-6e2e3c5ac7a2', '5c18bba2-3f17-55e0-becb-a7a04645523c', 4, 'Ask for more than any node has', $md$Create a pod `hungry` (image `nginx:1.27`) that requests `cpu: 64`. Nodes here have 32 CPUs. Check its status and read the reason in `kubectl describe pod hungry`.
$md$, $script$#!/bin/bash
test "$(kubectl get pod hungry -o jsonpath='{.status.phase}')" = "Pending" || exit 1
kubectl get pod hungry -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")].message}' | grep -qi 'insufficient cpu'
$script$, '`kubectl run hungry --image=nginx:1.27 --overrides=''{"spec":{"containers":[{"name":"hungry","image":"nginx:1.27","resources":{"requests":{"cpu":"64"}}}]}}''`, or write a small YAML file.', 'The scheduler only places a pod where its requests fit. The Events show "Insufficient cpu", the message you will see on real clusters when nodes are full.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '0eaedfda-dd2b-59b1-a546-6e2e3c5ac7a2', updated_at = now()
WHERE id = '7c9b2dc7-980f-5474-b333-061e60f64c3c' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('3a44e100-25c4-5b5c-bff7-79071fdc86ae', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '52756a52-681c-5932-95e7-9e7f879beff3', 'Lab: Node Selection and Affinity', 'lab', 2, 25)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('618e6f99-3c6f-59bb-8306-a2af680012b8', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '3a44e100-25c4-5b5c-bff7-79071fdc86ae', 'module', 'Lab: Node Selection and Affinity', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/podnodeaffinity.yaml <<'MFEOF'
apiVersion: v1
kind: Pod
metadata:
  name: nodeaffinitypod1
spec:
  containers:
  - name: nodeaffinity1
    image: nginx:1.27
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: app
            operator: In
            values:
            - production
---
apiVersion: v1
kind: Pod
metadata:
  name: nodeaffinitypod2
spec:
  containers:
  - name: nodeaffinity2
    image: nginx:1.27
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: app
            operator: In
            values:
            - production
      - weight: 2
        preference:
          matchExpressions:
          - key: app
            operator: In
            values:
            - test
---
apiVersion: v1
kind: Pod
metadata:
  name: nodeaffinitypod3
spec:
  containers:
  - name: nodeaffinity3
    image: nginx:1.27
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: app
            operator: Exists

MFEOF
chmod 666 /home/labuser/work/podnodeaffinity.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '1d2949c0-a5df-546e-9d12-fa20bb497bf6' AND id NOT IN ('38845ed4-8c0c-5b5c-998e-c1157870b73e', 'fa677b4b-c95c-56a9-b1f6-3f3ecbcc0d9f', 'f0331ae0-ed8d-5793-b23c-2300cb6e881d', 'fb5cf453-8c11-5814-9092-847db357706e');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '1d2949c0-a5df-546e-9d12-fa20bb497bf6';
DELETE FROM lab_tasks WHERE lab_id = '618e6f99-3c6f-59bb-8306-a2af680012b8' AND id NOT IN ('7bbe5fda-fd0b-5855-9b10-3339ad34d49c', 'df5885a8-4dc5-5eba-a00e-d3e8dab1d0da', '36b5460a-5c0a-5762-93b2-186553173018', 'b5b92658-52d4-597e-a995-8cfbf3b11045');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '618e6f99-3c6f-59bb-8306-a2af680012b8';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('7bbe5fda-fd0b-5855-9b10-3339ad34d49c', '618e6f99-3c6f-59bb-8306-a2af680012b8', 1, 'Create pods with affinity rules', $md$Apply `podnodeaffinity.yaml` and run `kubectl get pods`. Two pods stay `Pending` and one runs. Use `kubectl describe pod nodeaffinitypod1` to read why.
$md$, $script$#!/bin/bash
test "$(kubectl get pod nodeaffinitypod1 -o jsonpath='{.status.phase}')" = "Pending" || exit 1
test "$(kubectl get pod nodeaffinitypod3 -o jsonpath='{.status.phase}')" = "Pending" || exit 1
test "$(kubectl get pod nodeaffinitypod2 -o jsonpath='{.status.phase}')" = "Running"
$script$, '`kubectl apply -f podnodeaffinity.yaml`', 'Pods 1 and 3 have required rules (app=production, and any app label) that no node satisfies yet. Pod 2 only has preferences, so it runs anywhere.', 10, false, true),
('df5885a8-4dc5-5eba-a00e-d3e8dab1d0da', '618e6f99-3c6f-59bb-8306-a2af680012b8', 2, 'Label the node so the pending pods can run', $md$Add the label `app=production` to `kwok-node` and watch the two pending pods get scheduled.$md$, $script$#!/bin/bash
for p in nodeaffinitypod1 nodeaffinitypod3; do
  test "$(kubectl get pod $p -o jsonpath='{.status.phase}')" = "Running" || exit 1
done
$script$, '`kubectl label node kwok-node app=production`', 'Pod 1 needed app In (production) and pod 3 needed the key app to exist. The new label satisfies both, so the scheduler placed them.', 15, false, true),
('36b5460a-5c0a-5762-93b2-186553173018', '618e6f99-3c6f-59bb-8306-a2af680012b8', 3, 'Remove the label again', $md$Remove the `app` label from `kwok-node`. Are the pods evicted?$md$, $script$#!/bin/bash
test -z "$(kubectl get node kwok-node -o jsonpath='{.metadata.labels.app}')" || exit 1
test "$(kubectl get pod nodeaffinitypod1 -o jsonpath='{.status.phase}')" = "Running"
$script$, '`kubectl label node kwok-node app-` (the trailing minus removes a label)', 'The rules end in IgnoredDuringExecution, so they are only checked at scheduling time. Running pods stay where they are.', 10, false, true),
('b5b92658-52d4-597e-a995-8cfbf3b11045', '618e6f99-3c6f-59bb-8306-a2af680012b8', 4, 'Use a nodeSelector', $md$Label `kwok-node` with `disktype=ssd`. Then create a pod `ssd-pod` (image `nginx:1.27`) that may only run on nodes with that label, using `nodeSelector`.
$md$, $script$#!/bin/bash
test "$(kubectl get pod ssd-pod -o jsonpath='{.spec.nodeSelector.disktype} {.spec.nodeName} {.status.phase}')" = "ssd kwok-node Running"
$script$, '`nodeSelector:` goes under the pod''s `spec`, with `disktype: ssd` below it.', 'nodeSelector is the simple form of required node affinity. Every listed label must be present on the node.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('1d2949c0-a5df-546e-9d12-fa20bb497bf6', '618e6f99-3c6f-59bb-8306-a2af680012b8', 1, $json$[{"id":"7bbe5fda-fd0b-5855-9b10-3339ad34d49c","lab_id":"618e6f99-3c6f-59bb-8306-a2af680012b8","position":1,"title":"Create pods with affinity rules","description":"Apply `podnodeaffinity.yaml` and run `kubectl get pods`. Two pods stay `Pending` and one runs. Use `kubectl describe pod nodeaffinitypod1` to read why.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get pod nodeaffinitypod1 -o jsonpath='{.status.phase}')\" = \"Pending\" || exit 1\ntest \"$(kubectl get pod nodeaffinitypod3 -o jsonpath='{.status.phase}')\" = \"Pending\" || exit 1\ntest \"$(kubectl get pod nodeaffinitypod2 -o jsonpath='{.status.phase}')\" = \"Running\"\n","hint_context":"`kubectl apply -f podnodeaffinity.yaml`","explanation_context":"Pods 1 and 3 have required rules (app=production, and any app label) that no node satisfies yet. Pod 2 only has preferences, so it runs anywhere.","points":10,"is_optional":false,"is_stateful":true},{"id":"df5885a8-4dc5-5eba-a00e-d3e8dab1d0da","lab_id":"618e6f99-3c6f-59bb-8306-a2af680012b8","position":2,"title":"Label the node so the pending pods can run","description":"Add the label `app=production` to `kwok-node` and watch the two pending pods get scheduled.","verification_script":"#!/bin/bash\nfor p in nodeaffinitypod1 nodeaffinitypod3; do\n  test \"$(kubectl get pod $p -o jsonpath='{.status.phase}')\" = \"Running\" || exit 1\ndone\n","hint_context":"`kubectl label node kwok-node app=production`","explanation_context":"Pod 1 needed app In (production) and pod 3 needed the key app to exist. The new label satisfies both, so the scheduler placed them.","points":15,"is_optional":false,"is_stateful":true},{"id":"36b5460a-5c0a-5762-93b2-186553173018","lab_id":"618e6f99-3c6f-59bb-8306-a2af680012b8","position":3,"title":"Remove the label again","description":"Remove the `app` label from `kwok-node`. Are the pods evicted?","verification_script":"#!/bin/bash\ntest -z \"$(kubectl get node kwok-node -o jsonpath='{.metadata.labels.app}')\" || exit 1\ntest \"$(kubectl get pod nodeaffinitypod1 -o jsonpath='{.status.phase}')\" = \"Running\"\n","hint_context":"`kubectl label node kwok-node app-` (the trailing minus removes a label)","explanation_context":"The rules end in IgnoredDuringExecution, so they are only checked at scheduling time. Running pods stay where they are.","points":10,"is_optional":false,"is_stateful":true},{"id":"b5b92658-52d4-597e-a995-8cfbf3b11045","lab_id":"618e6f99-3c6f-59bb-8306-a2af680012b8","position":4,"title":"Use a nodeSelector","description":"Label `kwok-node` with `disktype=ssd`. Then create a pod `ssd-pod` (image `nginx:1.27`) that may only run on nodes with that label, using `nodeSelector`.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get pod ssd-pod -o jsonpath='{.spec.nodeSelector.disktype} {.spec.nodeName} {.status.phase}')\" = \"ssd kwok-node Running\"\n","hint_context":"`nodeSelector:` goes under the pod's `spec`, with `disktype: ssd` below it.","explanation_context":"nodeSelector is the simple form of required node affinity. Every listed label must be present on the node.","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('38845ed4-8c0c-5b5c-998e-c1157870b73e', '1d2949c0-a5df-546e-9d12-fa20bb497bf6', '7bbe5fda-fd0b-5855-9b10-3339ad34d49c', 1, 'Create pods with affinity rules', $md$Apply `podnodeaffinity.yaml` and run `kubectl get pods`. Two pods stay `Pending` and one runs. Use `kubectl describe pod nodeaffinitypod1` to read why.
$md$, $script$#!/bin/bash
test "$(kubectl get pod nodeaffinitypod1 -o jsonpath='{.status.phase}')" = "Pending" || exit 1
test "$(kubectl get pod nodeaffinitypod3 -o jsonpath='{.status.phase}')" = "Pending" || exit 1
test "$(kubectl get pod nodeaffinitypod2 -o jsonpath='{.status.phase}')" = "Running"
$script$, '`kubectl apply -f podnodeaffinity.yaml`', 'Pods 1 and 3 have required rules (app=production, and any app label) that no node satisfies yet. Pod 2 only has preferences, so it runs anywhere.', 10, false, true),
('fa677b4b-c95c-56a9-b1f6-3f3ecbcc0d9f', '1d2949c0-a5df-546e-9d12-fa20bb497bf6', 'df5885a8-4dc5-5eba-a00e-d3e8dab1d0da', 2, 'Label the node so the pending pods can run', $md$Add the label `app=production` to `kwok-node` and watch the two pending pods get scheduled.$md$, $script$#!/bin/bash
for p in nodeaffinitypod1 nodeaffinitypod3; do
  test "$(kubectl get pod $p -o jsonpath='{.status.phase}')" = "Running" || exit 1
done
$script$, '`kubectl label node kwok-node app=production`', 'Pod 1 needed app In (production) and pod 3 needed the key app to exist. The new label satisfies both, so the scheduler placed them.', 15, false, true),
('f0331ae0-ed8d-5793-b23c-2300cb6e881d', '1d2949c0-a5df-546e-9d12-fa20bb497bf6', '36b5460a-5c0a-5762-93b2-186553173018', 3, 'Remove the label again', $md$Remove the `app` label from `kwok-node`. Are the pods evicted?$md$, $script$#!/bin/bash
test -z "$(kubectl get node kwok-node -o jsonpath='{.metadata.labels.app}')" || exit 1
test "$(kubectl get pod nodeaffinitypod1 -o jsonpath='{.status.phase}')" = "Running"
$script$, '`kubectl label node kwok-node app-` (the trailing minus removes a label)', 'The rules end in IgnoredDuringExecution, so they are only checked at scheduling time. Running pods stay where they are.', 10, false, true),
('fb5cf453-8c11-5814-9092-847db357706e', '1d2949c0-a5df-546e-9d12-fa20bb497bf6', 'b5b92658-52d4-597e-a995-8cfbf3b11045', 4, 'Use a nodeSelector', $md$Label `kwok-node` with `disktype=ssd`. Then create a pod `ssd-pod` (image `nginx:1.27`) that may only run on nodes with that label, using `nodeSelector`.
$md$, $script$#!/bin/bash
test "$(kubectl get pod ssd-pod -o jsonpath='{.spec.nodeSelector.disktype} {.spec.nodeName} {.status.phase}')" = "ssd kwok-node Running"
$script$, '`nodeSelector:` goes under the pod''s `spec`, with `disktype: ssd` below it.', 'nodeSelector is the simple form of required node affinity. Every listed label must be present on the node.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '1d2949c0-a5df-546e-9d12-fa20bb497bf6', updated_at = now()
WHERE id = '618e6f99-3c6f-59bb-8306-a2af680012b8' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('6dc582d6-8698-52e1-a43f-45df751a2bd2', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '52756a52-681c-5932-95e7-9e7f879beff3', 'Lab: Taints and Tolerations', 'lab', 3, 25)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('adc92324-910d-51f4-8ec4-017096717a93', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '6dc582d6-8698-52e1-a43f-45df751a2bd2', 'module', 'Lab: Taints and Tolerations', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/podtoleration.yaml <<'MFEOF'
apiVersion: v1
kind: Pod
metadata:
  name: toleratedpod1
  labels:
    env: test
spec:
  containers:
  - name: toleratedcontainer1
    image: nginx:1.27
  tolerations:
  - key: "app"
    operator: "Equal"
    value: "production"
    effect: "NoSchedule"
---
apiVersion: v1
kind: Pod
metadata:
  name: toleratedpod2
  labels:
    env: test
spec:
  containers:
  - name: toleratedcontainer2
    image: nginx:1.27
  tolerations:
  - key: "app"
    operator: "Exists"
    effect: "NoSchedule"

MFEOF
chmod 666 /home/labuser/work/podtoleration.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, true, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '18637ca0-9a1d-534a-b3f6-1e2a9243075e' AND id NOT IN ('fd393fdc-e91f-52cc-a607-0a4f1a5fa354', 'f6554354-eb73-5da1-b2ca-1531f0ccbe72', 'bffda884-85c2-55f6-8124-3910f4a6ab51', 'd568b596-ece4-5b5a-bb69-bb2684ae0751', '14b3cc5f-904e-52d5-b6b4-b1e609aeda3d');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '18637ca0-9a1d-534a-b3f6-1e2a9243075e';
DELETE FROM lab_tasks WHERE lab_id = 'adc92324-910d-51f4-8ec4-017096717a93' AND id NOT IN ('033968d9-b8a3-53a1-90b7-302d7b16eb9b', '771b2a68-87ef-54ec-983a-3e523a657304', '616676a7-ae8f-5e99-85ea-91ee0e2835b4', '4a344ad8-0ef8-586d-b84e-5c3a8df0f6ee', 'd2b8c960-6442-5783-83f3-3b38be2b6991');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = 'adc92324-910d-51f4-8ec4-017096717a93';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('033968d9-b8a3-53a1-90b7-302d7b16eb9b', 'adc92324-910d-51f4-8ec4-017096717a93', 1, 'Taint the node', $md$Check the node's taints with `kubectl describe node kwok-node | grep Taints`. Then add the taint `app=production:NoSchedule`.$md$, $script$#!/bin/bash
kubectl get node kwok-node -o jsonpath='{range .spec.taints[*]}{.key}={.value}:{.effect}{"\n"}{end}' | grep -qx 'app=production:NoSchedule'
$script$, '`kubectl taint node <node> key=value:Effect`', 'From now on, new pods without a matching toleration cannot be scheduled on kwok-node.', 10, false, true),
('771b2a68-87ef-54ec-983a-3e523a657304', 'adc92324-910d-51f4-8ec4-017096717a93', 2, 'Watch an untolerated pod wait', $md$Run a plain pod `test` from `nginx:1.27`. It stays `Pending`. Read why in `kubectl describe pod test`.$md$, $script$#!/bin/bash
test "$(kubectl get pod test -o jsonpath='{.status.phase}')" = "Pending" || exit 1
kubectl get pod test -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")].message}' | grep -qi taint
$script$, '`kubectl run test --image=nginx:1.27`', 'The only node has a taint the pod does not tolerate, so the scheduler reports "untolerated taint" and the pod waits.', 10, false, true),
('616676a7-ae8f-5e99-85ea-91ee0e2835b4', 'adc92324-910d-51f4-8ec4-017096717a93', 3, 'Run pods that tolerate the taint', $md$Apply `podtoleration.yaml`. Both pods should run while `test` keeps waiting. Compare the two tolerations. One uses `Equal`, the other `Exists`.$md$, $script$#!/bin/bash
for p in toleratedpod1 toleratedpod2; do
  test "$(kubectl get pod $p -o jsonpath='{.status.phase}')" = "Running" || exit 1
done
test "$(kubectl get pod test -o jsonpath='{.status.phase}')" = "Pending"
$script$, '`kubectl apply -f podtoleration.yaml`', 'toleratedpod1 matches key, value and effect exactly (Equal). toleratedpod2 tolerates any value of the key app (Exists).', 15, false, true),
('4a344ad8-0ef8-586d-b84e-5c3a8df0f6ee', 'adc92324-910d-51f4-8ec4-017096717a93', 4, 'Evict running pods with NoExecute', $md$Add a second taint `version=new:NoExecute` to `kwok-node`. Watch `kubectl get pods`: the running pods do not tolerate this one. What happens to them?
$md$, $script$#!/bin/bash
kubectl get node kwok-node -o jsonpath='{range .spec.taints[*]}{.key}:{.effect}{"\n"}{end}' | grep -qx 'version:NoExecute' || exit 1
! kubectl get pod toleratedpod1 >/dev/null 2>&1 && ! kubectl get pod toleratedpod2 >/dev/null 2>&1
$script$, 'Same `kubectl taint` command with the NoExecute effect. Give it a few seconds.', 'NoExecute evicts running pods that do not tolerate it. NoSchedule never touches pods that are already running. Bare pods are gone after eviction; pods from a Deployment would be recreated on another node.', 20, false, true),
('d2b8c960-6442-5783-83f3-3b38be2b6991', 'adc92324-910d-51f4-8ec4-017096717a93', 5, 'Remove the taints', $md$Remove both taints from `kwok-node`. The `test` pod that was Pending should now be scheduled.$md$, $script$#!/bin/bash
test -z "$(kubectl get node kwok-node -o jsonpath='{.spec.taints}')" || exit 1
test "$(kubectl get pod test -o jsonpath='{.status.phase}')" = "Running"
$script$, '`kubectl taint node kwok-node app-` removes every taint with key app. Do the same for version.', 'With no taints left, the scheduler placed the pending pod. A pending pod is retried automatically; you never have to recreate it.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('18637ca0-9a1d-534a-b3f6-1e2a9243075e', 'adc92324-910d-51f4-8ec4-017096717a93', 1, $json$[{"id":"033968d9-b8a3-53a1-90b7-302d7b16eb9b","lab_id":"adc92324-910d-51f4-8ec4-017096717a93","position":1,"title":"Taint the node","description":"Check the node's taints with `kubectl describe node kwok-node | grep Taints`. Then add the taint `app=production:NoSchedule`.","verification_script":"#!/bin/bash\nkubectl get node kwok-node -o jsonpath='{range .spec.taints[*]}{.key}={.value}:{.effect}{\"\\n\"}{end}' | grep -qx 'app=production:NoSchedule'\n","hint_context":"`kubectl taint node \u003cnode\u003e key=value:Effect`","explanation_context":"From now on, new pods without a matching toleration cannot be scheduled on kwok-node.","points":10,"is_optional":false,"is_stateful":true},{"id":"771b2a68-87ef-54ec-983a-3e523a657304","lab_id":"adc92324-910d-51f4-8ec4-017096717a93","position":2,"title":"Watch an untolerated pod wait","description":"Run a plain pod `test` from `nginx:1.27`. It stays `Pending`. Read why in `kubectl describe pod test`.","verification_script":"#!/bin/bash\ntest \"$(kubectl get pod test -o jsonpath='{.status.phase}')\" = \"Pending\" || exit 1\nkubectl get pod test -o jsonpath='{.status.conditions[?(@.type==\"PodScheduled\")].message}' | grep -qi taint\n","hint_context":"`kubectl run test --image=nginx:1.27`","explanation_context":"The only node has a taint the pod does not tolerate, so the scheduler reports \"untolerated taint\" and the pod waits.","points":10,"is_optional":false,"is_stateful":true},{"id":"616676a7-ae8f-5e99-85ea-91ee0e2835b4","lab_id":"adc92324-910d-51f4-8ec4-017096717a93","position":3,"title":"Run pods that tolerate the taint","description":"Apply `podtoleration.yaml`. Both pods should run while `test` keeps waiting. Compare the two tolerations. One uses `Equal`, the other `Exists`.","verification_script":"#!/bin/bash\nfor p in toleratedpod1 toleratedpod2; do\n  test \"$(kubectl get pod $p -o jsonpath='{.status.phase}')\" = \"Running\" || exit 1\ndone\ntest \"$(kubectl get pod test -o jsonpath='{.status.phase}')\" = \"Pending\"\n","hint_context":"`kubectl apply -f podtoleration.yaml`","explanation_context":"toleratedpod1 matches key, value and effect exactly (Equal). toleratedpod2 tolerates any value of the key app (Exists).","points":15,"is_optional":false,"is_stateful":true},{"id":"4a344ad8-0ef8-586d-b84e-5c3a8df0f6ee","lab_id":"adc92324-910d-51f4-8ec4-017096717a93","position":4,"title":"Evict running pods with NoExecute","description":"Add a second taint `version=new:NoExecute` to `kwok-node`. Watch `kubectl get pods`: the running pods do not tolerate this one. What happens to them?\n","verification_script":"#!/bin/bash\nkubectl get node kwok-node -o jsonpath='{range .spec.taints[*]}{.key}:{.effect}{\"\\n\"}{end}' | grep -qx 'version:NoExecute' || exit 1\n! kubectl get pod toleratedpod1 \u003e/dev/null 2\u003e\u00261 \u0026\u0026 ! kubectl get pod toleratedpod2 \u003e/dev/null 2\u003e\u00261\n","hint_context":"Same `kubectl taint` command with the NoExecute effect. Give it a few seconds.","explanation_context":"NoExecute evicts running pods that do not tolerate it. NoSchedule never touches pods that are already running. Bare pods are gone after eviction; pods from a Deployment would be recreated on another node.","points":20,"is_optional":false,"is_stateful":true},{"id":"d2b8c960-6442-5783-83f3-3b38be2b6991","lab_id":"adc92324-910d-51f4-8ec4-017096717a93","position":5,"title":"Remove the taints","description":"Remove both taints from `kwok-node`. The `test` pod that was Pending should now be scheduled.","verification_script":"#!/bin/bash\ntest -z \"$(kubectl get node kwok-node -o jsonpath='{.spec.taints}')\" || exit 1\ntest \"$(kubectl get pod test -o jsonpath='{.status.phase}')\" = \"Running\"\n","hint_context":"`kubectl taint node kwok-node app-` removes every taint with key app. Do the same for version.","explanation_context":"With no taints left, the scheduler placed the pending pod. A pending pod is retried automatically; you never have to recreate it.","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('fd393fdc-e91f-52cc-a607-0a4f1a5fa354', '18637ca0-9a1d-534a-b3f6-1e2a9243075e', '033968d9-b8a3-53a1-90b7-302d7b16eb9b', 1, 'Taint the node', $md$Check the node's taints with `kubectl describe node kwok-node | grep Taints`. Then add the taint `app=production:NoSchedule`.$md$, $script$#!/bin/bash
kubectl get node kwok-node -o jsonpath='{range .spec.taints[*]}{.key}={.value}:{.effect}{"\n"}{end}' | grep -qx 'app=production:NoSchedule'
$script$, '`kubectl taint node <node> key=value:Effect`', 'From now on, new pods without a matching toleration cannot be scheduled on kwok-node.', 10, false, true),
('f6554354-eb73-5da1-b2ca-1531f0ccbe72', '18637ca0-9a1d-534a-b3f6-1e2a9243075e', '771b2a68-87ef-54ec-983a-3e523a657304', 2, 'Watch an untolerated pod wait', $md$Run a plain pod `test` from `nginx:1.27`. It stays `Pending`. Read why in `kubectl describe pod test`.$md$, $script$#!/bin/bash
test "$(kubectl get pod test -o jsonpath='{.status.phase}')" = "Pending" || exit 1
kubectl get pod test -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")].message}' | grep -qi taint
$script$, '`kubectl run test --image=nginx:1.27`', 'The only node has a taint the pod does not tolerate, so the scheduler reports "untolerated taint" and the pod waits.', 10, false, true),
('bffda884-85c2-55f6-8124-3910f4a6ab51', '18637ca0-9a1d-534a-b3f6-1e2a9243075e', '616676a7-ae8f-5e99-85ea-91ee0e2835b4', 3, 'Run pods that tolerate the taint', $md$Apply `podtoleration.yaml`. Both pods should run while `test` keeps waiting. Compare the two tolerations. One uses `Equal`, the other `Exists`.$md$, $script$#!/bin/bash
for p in toleratedpod1 toleratedpod2; do
  test "$(kubectl get pod $p -o jsonpath='{.status.phase}')" = "Running" || exit 1
done
test "$(kubectl get pod test -o jsonpath='{.status.phase}')" = "Pending"
$script$, '`kubectl apply -f podtoleration.yaml`', 'toleratedpod1 matches key, value and effect exactly (Equal). toleratedpod2 tolerates any value of the key app (Exists).', 15, false, true),
('d568b596-ece4-5b5a-bb69-bb2684ae0751', '18637ca0-9a1d-534a-b3f6-1e2a9243075e', '4a344ad8-0ef8-586d-b84e-5c3a8df0f6ee', 4, 'Evict running pods with NoExecute', $md$Add a second taint `version=new:NoExecute` to `kwok-node`. Watch `kubectl get pods`: the running pods do not tolerate this one. What happens to them?
$md$, $script$#!/bin/bash
kubectl get node kwok-node -o jsonpath='{range .spec.taints[*]}{.key}:{.effect}{"\n"}{end}' | grep -qx 'version:NoExecute' || exit 1
! kubectl get pod toleratedpod1 >/dev/null 2>&1 && ! kubectl get pod toleratedpod2 >/dev/null 2>&1
$script$, 'Same `kubectl taint` command with the NoExecute effect. Give it a few seconds.', 'NoExecute evicts running pods that do not tolerate it. NoSchedule never touches pods that are already running. Bare pods are gone after eviction; pods from a Deployment would be recreated on another node.', 20, false, true),
('14b3cc5f-904e-52d5-b6b4-b1e609aeda3d', '18637ca0-9a1d-534a-b3f6-1e2a9243075e', 'd2b8c960-6442-5783-83f3-3b38be2b6991', 5, 'Remove the taints', $md$Remove both taints from `kwok-node`. The `test` pod that was Pending should now be scheduled.$md$, $script$#!/bin/bash
test -z "$(kubectl get node kwok-node -o jsonpath='{.spec.taints}')" || exit 1
test "$(kubectl get pod test -o jsonpath='{.status.phase}')" = "Running"
$script$, '`kubectl taint node kwok-node app-` removes every taint with key app. Do the same for version.', 'With no taints left, the scheduler placed the pending pod. A pending pod is retried automatically; you never have to recreate it.', 10, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '18637ca0-9a1d-534a-b3f6-1e2a9243075e', updated_at = now()
WHERE id = 'adc92324-910d-51f4-8ec4-017096717a93' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b9747857-d195-5477-aac3-67e7241b0bac', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does Kubernetes do when a liveness probe keeps failing?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9819dea7-a4c6-5546-befd-52076472867f', 'b9747857-d195-5477-aac3-67e7241b0bac', 1, $json${"prompt":"What does Kubernetes do when a liveness probe keeps failing?","multiple":false,"options":[{"id":"a","text":"Removes the pod from Service endpoints","is_correct":false},{"id":"b","text":"Restarts the container","is_correct":true},{"id":"c","text":"Moves the pod to another node","is_correct":false},{"id":"d","text":"Nothing","is_correct":false}],"explanation":"Liveness failures restart the container. Readiness failures only remove the pod from endpoints."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c69b273d-100c-5a0b-8f46-f0ae653b2a97', '00000000-0000-0000-0000-000000000001', 'mcq', 'During a rolling update, why does a readiness probe make the update safer?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('90e0dca9-963f-5044-9bd0-40cedb8e5056', 'c69b273d-100c-5a0b-8f46-f0ae653b2a97', 1, $json${"prompt":"During a rolling update, why does a readiness probe make the update safer?","multiple":false,"options":[{"id":"a","text":"It makes images download faster","is_correct":false},{"id":"b","text":"New pods only receive traffic, and only count as available, once they report ready","is_correct":true},{"id":"c","text":"It prevents old pods from being deleted","is_correct":false},{"id":"d","text":"It increases maxSurge","is_correct":false}],"explanation":"Without readiness, a pod is considered ready as soon as its container starts, even if the app cannot serve yet."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('368ee26f-aec5-56c5-984f-c9a32e9313eb', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does `cpu 500m` mean?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('55e7f6f4-f6bc-5183-850b-ca4521bd4f15', '368ee26f-aec5-56c5-984f-c9a32e9313eb', 1, $json${"prompt":"What does `cpu 500m` mean?","multiple":false,"options":[{"id":"a","text":"500 CPU cores","is_correct":false},{"id":"b","text":"Half of one CPU core","is_correct":true},{"id":"c","text":"500 megabytes","is_correct":false},{"id":"d","text":"500 milliseconds per request","is_correct":false}],"explanation":"m means millicores; 1000m is one core."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('79daaa89-2a3f-5dd9-8d63-067061bb670d', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which setting does the scheduler use to decide whether a pod fits on a node?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1113d12d-f875-50b1-9416-d1a2b4a57576', '79daaa89-2a3f-5dd9-8d63-067061bb670d', 1, $json${"prompt":"Which setting does the scheduler use to decide whether a pod fits on a node?","multiple":false,"options":[{"id":"a","text":"Resource limits","is_correct":false},{"id":"b","text":"Resource requests","is_correct":true},{"id":"c","text":"The image size","is_correct":false},{"id":"d","text":"The number of labels","is_correct":false}],"explanation":"Scheduling is based on requests. Limits are enforced later, at runtime."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('8d19a7d1-da89-551b-8c71-8d6df710f830', '00000000-0000-0000-0000-000000000001', 'mcq', 'A node runs out of memory. Pods of which QoS class are evicted first?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('8b622860-3199-5439-b157-993f01465b48', '8d19a7d1-da89-551b-8c71-8d6df710f830', 1, $json${"prompt":"A node runs out of memory. Pods of which QoS class are evicted first?","multiple":false,"options":[{"id":"a","text":"Guaranteed","is_correct":false},{"id":"b","text":"Burstable","is_correct":false},{"id":"c","text":"BestEffort","is_correct":true},{"id":"d","text":"All at the same time","is_correct":false}],"explanation":"BestEffort pods (no requests or limits) go first, Guaranteed pods last."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('58e70f84-34d5-57ab-be37-bead81eddd50', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the difference between required and preferred node affinity?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('766fa279-0a02-5963-b5e5-9069f7e52dae', '58e70f84-34d5-57ab-be37-bead81eddd50', 1, $json${"prompt":"What is the difference between required and preferred node affinity?","multiple":false,"options":[{"id":"a","text":"Required must be satisfied or the pod stays Pending; preferred is a wish the scheduler tries to honor","is_correct":true},{"id":"b","text":"Required is checked continuously; preferred only once","is_correct":false},{"id":"c","text":"Preferred evicts running pods","is_correct":false},{"id":"d","text":"There is no difference","is_correct":false}],"explanation":"required... is a hard constraint, preferred... is weighted scoring."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5a3ad4ba-d179-5010-b9e5-edb603708cf3', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which taint effect also evicts pods that are already running on the node?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b9cd6781-fc81-5da6-bdc0-9a8e6662c9df', '5a3ad4ba-d179-5010-b9e5-edb603708cf3', 1, $json${"prompt":"Which taint effect also evicts pods that are already running on the node?","multiple":false,"options":[{"id":"a","text":"NoSchedule","is_correct":false},{"id":"b","text":"PreferNoSchedule","is_correct":false},{"id":"c","text":"NoExecute","is_correct":true},{"id":"d","text":"NoRestart","is_correct":false}],"explanation":"NoExecute blocks new pods and evicts running pods without a matching toleration."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2b0e52cf-18c3-5354-87f8-c7b0b6810a57', '00000000-0000-0000-0000-000000000001', 'mcq', 'You want GPU nodes used only by ML pods, and ML pods to run only on GPU nodes...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a0d681a4-3755-5a14-8ab7-76d039edaf0e', '2b0e52cf-18c3-5354-87f8-c7b0b6810a57', 1, $json${"prompt":"You want GPU nodes used only by ML pods, and ML pods to run only on GPU nodes. What do you need?","multiple":false,"options":[{"id":"a","text":"Only a toleration on the ML pods","is_correct":false},{"id":"b","text":"A taint on the GPU nodes plus a toleration and node affinity on the ML pods","is_correct":true},{"id":"c","text":"Only node affinity on the ML pods","is_correct":false},{"id":"d","text":"A DaemonSet for the ML pods","is_correct":false}],"explanation":"The taint keeps other pods off, the toleration lets ML pods on, and node affinity makes ML pods go there."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('32bb1357-1742-5b32-b579-7eaab7d3a64b', '00000000-0000-0000-0000-000000000001', 'Quiz: Health, Resources & Scheduling', 'k8s-scheduling-quiz', 'Quiz covering Health, Resources & Scheduling.', 'mcq', 'published', 'module', '6aaf7df2-aa2a-5abc-99b4-63d92491ceca', 20, 70, 5, 8, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '32bb1357-1742-5b32-b579-7eaab7d3a64b' AND question_id NOT IN ('b9747857-d195-5477-aac3-67e7241b0bac', 'c69b273d-100c-5a0b-8f46-f0ae653b2a97', '368ee26f-aec5-56c5-984f-c9a32e9313eb', '79daaa89-2a3f-5dd9-8d63-067061bb670d', '8d19a7d1-da89-551b-8c71-8d6df710f830', '58e70f84-34d5-57ab-be37-bead81eddd50', '5a3ad4ba-d179-5010-b9e5-edb603708cf3', '2b0e52cf-18c3-5354-87f8-c7b0b6810a57');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('5d4e0e37-1cb6-50cc-9632-325170d78cc0', '32bb1357-1742-5b32-b579-7eaab7d3a64b', 'b9747857-d195-5477-aac3-67e7241b0bac', '9819dea7-a4c6-5546-befd-52076472867f', 0, 1),
('bd45d1f2-57c3-5288-a83e-05ae4a6bfd3d', '32bb1357-1742-5b32-b579-7eaab7d3a64b', 'c69b273d-100c-5a0b-8f46-f0ae653b2a97', '90e0dca9-963f-5044-9bd0-40cedb8e5056', 1, 1),
('49eee541-c9e2-5d11-b72f-a6e1446316cc', '32bb1357-1742-5b32-b579-7eaab7d3a64b', '368ee26f-aec5-56c5-984f-c9a32e9313eb', '55e7f6f4-f6bc-5183-850b-ca4521bd4f15', 2, 1),
('b9efd1b2-bf54-5916-b3ee-394ac258deeb', '32bb1357-1742-5b32-b579-7eaab7d3a64b', '79daaa89-2a3f-5dd9-8d63-067061bb670d', '1113d12d-f875-50b1-9416-d1a2b4a57576', 3, 1),
('d73aa67c-492d-5b48-ba76-5426cddf1291', '32bb1357-1742-5b32-b579-7eaab7d3a64b', '8d19a7d1-da89-551b-8c71-8d6df710f830', '8b622860-3199-5439-b157-993f01465b48', 4, 1),
('9a58588b-79b4-5665-b67b-8d4b6b957e9b', '32bb1357-1742-5b32-b579-7eaab7d3a64b', '58e70f84-34d5-57ab-be37-bead81eddd50', '766fa279-0a02-5963-b5e5-9069f7e52dae', 5, 1),
('e9f63862-21b4-56a3-9d13-f886ba9d56ec', '32bb1357-1742-5b32-b579-7eaab7d3a64b', '5a3ad4ba-d179-5010-b9e5-edb603708cf3', 'b9cd6781-fc81-5da6-bdc0-9a8e6662c9df', 6, 1),
('562f16c4-8e0d-513a-8168-9bb0cfe15cd5', '32bb1357-1742-5b32-b579-7eaab7d3a64b', '2b0e52cf-18c3-5354-87f8-c7b0b6810a57', 'a0d681a4-3755-5a14-8ab7-76d039edaf0e', 7, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('6aaf7df2-aa2a-5abc-99b4-63d92491ceca', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '52756a52-681c-5932-95e7-9e7f879beff3', 'Quiz: Health, Resources & Scheduling', 'assessment', 4, 12, '32bb1357-1742-5b32-b579-7eaab7d3a64b')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Helm: Packaging Applications
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('8c7e60f0-4e81-55a1-b5d2-e985155f8562', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Helm: Packaging Applications', 8)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('4c83f344-4fc6-528b-ad75-f64acb9e916a', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '8c7e60f0-4e81-55a1-b5d2-e985155f8562', 'Helm Charts, Releases and Values', 'notes', 0, $md$Look at a typical app: a Deployment, a Service, a ConfigMap, a Secret, an Ingress, maybe a HorizontalPodAutoscaler. That is six YAML files, and you need slightly different versions for dev, staging and production. Copying and editing them by hand quickly goes wrong. **Helm** is the package manager for Kubernetes that solves this.

## What Helm does

A Helm chart is like a thali menu at a restaurant: the fixed items (rice, dal, sabzi) are the manifests, and the spice-level or portion-size choice at the counter is what you override in `values.yaml`. You get a full, working meal without writing the recipe yourself. Helm bundles all of an app's Kubernetes manifests into one **chart**, with **variables** for everything that differs between installs. It gives you:

- **Templating**: write the YAML once, fill in values (replica count, image tag, host name) per environment.
- **Packaging and sharing**: install someone else's app (PostgreSQL, Prometheus, Jenkins) with one command instead of writing dozens of manifests.
- **Release management**: every install is tracked. You can upgrade, see the history, and roll back.

Three words to know:

| Term | Meaning |
|---|---|
| **Chart** | The package: templates + default values + metadata. |
| **Release** | One installed instance of a chart in a cluster, with a name. You can install the same chart twice as two releases (`blog-dev`, `blog-prod`). |
| **Repository** | A place where charts are published (an HTTP server or an OCI registry). **Artifact Hub** (artifacthub.io) is where you search for public charts. |

Helm 3 is just a client. It talks to the API server with your kubeconfig, like kubectl, and stores release history as Secrets in the release's namespace. (The old server-side component "Tiller" from Helm 2 no longer exists.)

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-what-q1", "type": "mcq",
    "prompt": "You install the same chart twice, once as `shop-dev` and once as `shop-prod`. How many releases exist?",
    "options": [
      {"id": "a", "text": "One; charts can only be installed once"},
      {"id": "b", "text": "Two separate releases, each with its own history and values"},
      {"id": "c", "text": "Zero until you run helm package"},
      {"id": "d", "text": "One release with two revisions"}
    ],
    "correct": "b",
    "explanation": "A chart is the package; each install creates an independent release." }
] }
```

## Installing Helm and using public charts

```bash
# Linux/macOS (official script); or use your package manager: brew install helm, choco install kubernetes-helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

Working with repositories:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami   # add a repo to your local list
helm repo update                                          # refresh the chart index
helm repo list
helm search repo wordpress                                # search your added repos
helm search hub wordpress                                 # search Artifact Hub
helm show values bitnami/wordpress > wp-values.yaml       # see every setting the chart offers
helm pull bitnami/jenkins --untar                         # download a chart to read or modify it
```

Many charts are now published to **OCI registries** and installed without `repo add`:

```bash
helm install my-redis oci://registry-1.docker.io/bitnamicharts/redis
```

Always read the chart's values (`helm show values`) before installing. That is the chart's "settings page". Also check that a chart is actively maintained (recent releases, who publishes it). For example, Bitnami cut back its free chart and image catalog in 2025, so many older tutorials point to charts that are no longer updated. Prefer charts published by the software's own project when they exist.

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-repo-q1", "type": "mcq",
    "prompt": "Before installing a public chart, how do you see all the settings you can change?",
    "options": [
      {"id": "a", "text": "helm show values <chart>"},
      {"id": "b", "text": "helm list"},
      {"id": "c", "text": "helm history <chart>"},
      {"id": "d", "text": "kubectl describe chart <chart>"}
    ],
    "correct": "a",
    "explanation": "helm show values prints the chart's default values.yaml, which documents every configurable option." }
] }
```

## Inside a chart

`helm create webapp` generates this layout:

```
webapp/
├── Chart.yaml          # name, version (of the chart), appVersion (of the app), dependencies
├── values.yaml         # default values
├── charts/             # dependency charts (subcharts)
└── templates/          # Kubernetes manifests with template placeholders
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── hpa.yaml
    ├── _helpers.tpl    # reusable named snippets (names, labels)
    └── NOTES.txt       # message printed after install
```

A template uses Go template syntax. Values from `values.yaml` appear under `.Values`:

```yaml
# templates/deployment.yaml (simplified)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-{{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
```

```yaml
# values.yaml
replicaCount: 1
image:
  repository: nginx
  tag: ""
```

- `.Values` = your values, `.Release.Name` = the release name, `.Chart` = data from Chart.yaml.
- `| default ...` is a template function. There are many (`quote`, `upper`, `toYaml`, `indent`...).
- `{{- if .Values.ingress.enabled }} ... {{- end }}` turns whole objects on or off.
- `Chart.yaml` has two versions: `version` (the chart's own version, bump it on every chart change) and `appVersion` (the version of the app it deploys).

[[lab-task:1]]

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-chart-q1", "type": "mcq",
    "prompt": "In a template, what does `{{ .Values.replicaCount }}` become?",
    "options": [
      {"id": "a", "text": "The number of existing pods"},
      {"id": "b", "text": "The replicaCount value from values.yaml, or from an override given at install/upgrade time"},
      {"id": "c", "text": "The chart version"},
      {"id": "d", "text": "Always 1"}
    ],
    "correct": "b",
    "explanation": ".Values holds the merged values: chart defaults overridden by -f files and --set flags." }
] }
```

## Checking a chart before installing it

Never install blind. These commands render or validate without changing the cluster:

```bash
helm lint ./webapp                                   # find mistakes in the chart
helm template web ./webapp --set replicaCount=2      # print the rendered YAML
helm install web ./webapp --dry-run --debug          # simulate an install against the cluster
helm get manifest web                                # the YAML of an already-installed release
```

`helm template` is the most useful debugging tool: when a release does not look right, render it and read the YAML.

[[lab-task:2]]

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-check-q1", "type": "mcq",
    "prompt": "Which command shows the exact Kubernetes YAML a chart will produce, without touching the cluster?",
    "options": [
      {"id": "a", "text": "helm template <release> <chart>"},
      {"id": "b", "text": "helm install <release> <chart>"},
      {"id": "c", "text": "helm rollback <release>"},
      {"id": "d", "text": "helm repo update"}
    ],
    "correct": "a",
    "explanation": "helm template renders locally and prints the YAML." }
] }
```

## Install, upgrade, rollback, uninstall

```bash
helm install web ./webapp                                  # from a local folder
helm install wp bitnami/wordpress -n blog --create-namespace
helm list -A                                               # releases in all namespaces
helm status web
helm upgrade web ./webapp -f prod-values.yaml              # apply new values or a new chart version
helm upgrade --install web ./webapp -f prod-values.yaml    # install if missing, else upgrade (great for CI)
helm history web                                           # revisions
helm rollback web 1                                        # back to revision 1
helm uninstall web                                         # delete all objects of the release
```

Useful flags for real deployments:

- `--atomic`: if the upgrade fails, roll back automatically.
- `--wait --timeout 5m`: wait until pods are ready before calling it a success.
- `--version 1.2.3`: pin the chart version (do this in production).

Note: `helm uninstall` usually does **not** delete PVCs created by StatefulSets, so database data survives. Delete them yourself when you mean it.

[[lab-task:3]]

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-lifecycle-q1", "type": "mcq",
    "prompt": "A CI pipeline should create the release the first time and upgrade it on every later run. Which command fits?",
    "options": [
      {"id": "a", "text": "helm install"},
      {"id": "b", "text": "helm upgrade --install"},
      {"id": "c", "text": "helm template | kubectl apply"},
      {"id": "d", "text": "helm rollback"}
    ],
    "correct": "b",
    "explanation": "upgrade --install is idempotent: it installs if the release does not exist and upgrades otherwise." }
] }
```

## Overriding values

Values are merged in this order (later wins):

1. The chart's `values.yaml`
2. Files passed with `-f` / `--values` (in the order given)
3. `--set key=value` flags

```bash
helm install web ./webapp -f values-common.yaml -f values-prod.yaml --set image.tag=1.27
helm get values web            # the values you supplied for this release
helm get values web --all      # every value, including defaults
```

Keep one values file per environment in Git (`values-dev.yaml`, `values-prod.yaml`). Use `--set` only for small things like an image tag from CI. **Never put real passwords in values files in Git**; reference an existing Secret or use a secrets tool.

[[lab-task:4]]

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-values-q1", "type": "mcq",
    "prompt": "values.yaml says replicaCount: 1, prod.yaml says replicaCount: 3, and you run `helm install app ./chart -f prod.yaml --set replicaCount=5`. How many replicas?",
    "options": [
      {"id": "a", "text": "1"},
      {"id": "b", "text": "3"},
      {"id": "c", "text": "5"},
      {"id": "d", "text": "9"}
    ],
    "correct": "c",
    "explanation": "--set has the highest priority, then -f files, then the chart defaults." }
] }
```

## Real example: Jenkins with Helm

Installing a CI server shows why Helm is popular. Without Helm you would write a StatefulSet, Service, PVC, ServiceAccount, RBAC rules and a ConfigMap. With Helm:

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm show values jenkins/jenkins > jenkins-values.yaml    # e.g. set controller.serviceType: NodePort
helm install jenkins jenkins/jenkins -n jenkins --create-namespace -f jenkins-values.yaml

# the admin password is stored in a Secret created by the chart
kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 -d
kubectl port-forward -n jenkins svc/jenkins 8080:8080     # then open http://localhost:8080
```

The same pattern (repo add → show values → install with your values file) works for Prometheus, Grafana, PostgreSQL, Redis and most other software.

**Helm vs Kustomize**: Kustomize (built into `kubectl apply -k`) customizes plain YAML with overlays instead of templates. Teams often use Helm for third-party software and either Helm or Kustomize for their own apps. GitOps tools such as Argo CD and Flux can deploy both.

[[lab-task:5]]

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-real-q1", "type": "mcq",
    "prompt": "A Helm upgrade made the app crash. What is the fastest way back to the last working version?",
    "options": [
      {"id": "a", "text": "helm uninstall and reinstall"},
      {"id": "b", "text": "helm rollback <release> <last-good-revision>"},
      {"id": "c", "text": "kubectl delete pods"},
      {"id": "d", "text": "helm repo update"}
    ],
    "correct": "b",
    "explanation": "helm history shows the revisions; helm rollback re-applies the chosen one. --atomic on upgrades does this automatically on failure." }
] }
```

## Extending Kubernetes: CRDs and operators

Kubernetes ships with built-in kinds: Pod, Deployment, Service, and so on. A **CustomResourceDefinition (CRD)** lets you add a brand new kind of your own, so the API server can store and serve objects that Kubernetes itself never shipped with. Once a CRD is installed, `kubectl get <your-new-kind>` works exactly like it does for a Pod.

A new kind by itself does nothing, it is just a place to store desired state. An **operator** is a controller (the same reconcile-loop idea from the basics lesson) written to watch objects of that custom kind and do the real work: create the underlying Deployments, Secrets, backups, or whatever the custom object describes.

Examples you will run into in real clusters:

- **cert-manager** adds a `Certificate` kind. You create a `Certificate` object saying "I want a TLS cert for shop.mindforge.test", and its operator requests, renews and stores the certificate for you.
- **Prometheus Operator** adds a `ServiceMonitor` kind. You create one pointing at your Service, and the operator wires Prometheus to scrape it, no manual Prometheus config editing.
- **CloudNativePG** adds a `Cluster` kind for PostgreSQL. You describe the Postgres cluster you want (replicas, storage size), and the operator creates the pods, handles failover and backups.

This is exactly why so many Helm charts install more than your app: a chart for cert-manager or a database often installs the CRDs **and** the operator together, so that after `helm install` you can just write a small custom-kind YAML file and the operator handles the rest. If `helm install` finishes but `kubectl get <customkind>` says `the server doesn't have a resource type`, the CRD did not get installed, usually because CRDs must be applied before the objects that use them, and some charts require a separate step for this (check the chart's README).

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-crd-q1", "type": "mcq",
    "prompt": "What does a CustomResourceDefinition (CRD) add to a cluster?",
    "options": [
      {"id": "a", "text": "A new namespace"},
      {"id": "b", "text": "A brand new kind of object that the API server can store and serve, beyond the built-in kinds"},
      {"id": "c", "text": "A faster scheduler"},
      {"id": "d", "text": "A new node"}
    ],
    "correct": "b",
    "explanation": "A CRD registers a new kind with the API server. By itself it only defines the shape of the data; an operator does the actual work." },
  { "id": "k8s-helm-crd-q2", "type": "mcq",
    "prompt": "You create a CloudNativePG `Cluster` object describing a 3-node Postgres cluster. What actually creates the pods and manages failover?",
    "options": [
      {"id": "a", "text": "The kube-scheduler, automatically"},
      {"id": "b", "text": "The CloudNativePG operator, a controller watching Cluster objects and reconciling them"},
      {"id": "c", "text": "Helm, at install time only, with no further involvement"},
      {"id": "d", "text": "etcd, by reading the CRD schema"}
    ],
    "correct": "b",
    "explanation": "The CRD only defines the shape of the Cluster object. An operator is the controller that watches these objects and creates the real Deployments, Services, and backup jobs to match." }
] }
```

## Interview questions and real-world scenarios

**Q: What problems does Helm solve?**
Templating (one chart, many environments), packaging and sharing apps, and release management with history and rollback.

**Q: Chart vs release vs repository?**
Package, installed instance, and distribution location (HTTP repo or OCI registry).

**Q: How do you manage different values per environment?**
Base `values.yaml` in the chart, plus `values-dev.yaml` / `values-prod.yaml` in Git passed with `-f`; secrets from a secret manager, not values files.

**Q: Helm vs Kustomize?**
Helm uses templates and has release tracking; Kustomize patches plain YAML with overlays and is built into kubectl. Helm is dominant for third-party software; both are common for in-house apps, often driven by Argo CD or Flux.

**Q: How do you debug a chart that renders wrong YAML?**
`helm template` or `helm install --dry-run --debug`, `helm lint`, and `helm get manifest` / `helm get values` for installed releases.

**Real-world scenario: `helm upgrade` fails with "another operation (install/upgrade/rollback) is in progress".**
A previous upgrade was interrupted and the release is stuck in pending-upgrade. Check `helm history`, then `helm rollback` to the last deployed revision. Using `--atomic --timeout` in CI prevents half-finished releases.

**Real-world scenario: an upgrade removed a PVC and data was lost.**
The chart's PVC template was renamed or removed. Review `helm diff upgrade` (helm-diff plugin) before upgrading, use `helm.sh/resource-policy: keep` on critical resources, and back up first.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-helm-int-q1",
      "type": "mcq",
      "prompt": "A Helm release is stuck in 'pending-upgrade' after a CI job was cancelled. What is the usual fix?",
      "options": [
        {
          "id": "a",
          "text": "Delete the cluster"
        },
        {
          "id": "b",
          "text": "Check helm history and helm rollback to the last deployed revision"
        },
        {
          "id": "c",
          "text": "Run helm repo update"
        },
        {
          "id": "d",
          "text": "Delete all Secrets in the namespace"
        }
      ],
      "correct": "b",
      "explanation": "Rolling back clears the pending state; --atomic on future upgrades prevents it."
    }
  ]
}
```
$md$, 50, $json$[{"id":"k8s-helm-what-q1","type":"mcq","correct":"b"},{"id":"k8s-helm-repo-q1","type":"mcq","correct":"a"},{"id":"k8s-helm-chart-q1","type":"mcq","correct":"b"},{"id":"k8s-helm-check-q1","type":"mcq","correct":"a"},{"id":"k8s-helm-lifecycle-q1","type":"mcq","correct":"b"},{"id":"k8s-helm-values-q1","type":"mcq","correct":"c"},{"id":"k8s-helm-real-q1","type":"mcq","correct":"b"},{"id":"k8s-helm-crd-q1","type":"mcq","correct":"b"},{"id":"k8s-helm-crd-q2","type":"mcq","correct":"b"},{"id":"k8s-helm-int-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('4d838c97-594e-5ea9-b6a8-e8158aac778f', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '4c83f344-4fc6-528b-ad75-f64acb9e916a', 'module', 'Helm Charts, Releases and Values', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '36c1653f-b6ba-56fb-9006-33e6b1a058d8' AND id NOT IN ('a8ac2932-aeda-5050-b642-6651bed02751', '00d627b6-5e85-5a3b-a8e8-8729e9a92faf', '3e1fa05e-49d3-525b-aaf7-c94dca498a66', '5f7bd32a-246c-5d9f-af82-e16b2e0be61f', 'a9902fe8-fdf2-51b0-9241-02b4e9681004');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '36c1653f-b6ba-56fb-9006-33e6b1a058d8';
DELETE FROM lab_tasks WHERE lab_id = '4d838c97-594e-5ea9-b6a8-e8158aac778f' AND id NOT IN ('646795ba-a1f9-576d-8fd9-c5e3bcbf2c96', 'ee1bc760-4762-5093-b974-df32cdf55b30', 'bdad8da1-34cb-5ef5-aa31-28d1038d8232', '7da960e4-0f72-5577-bcf3-27cf75801c45', '68683a06-e857-5efd-b1e8-3481c17d3b07');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '4d838c97-594e-5ea9-b6a8-e8158aac778f';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('646795ba-a1f9-576d-8fd9-c5e3bcbf2c96', '4d838c97-594e-5ea9-b6a8-e8158aac778f', 1, 'Create a chart', $md$In your work folder, create a new chart called `webapp` with `helm create`. Look around with `ls -R webapp` and open `webapp/values.yaml` and `webapp/templates/deployment.yaml`.$md$, $script$#!/bin/bash
test -f /home/labuser/work/webapp/Chart.yaml && test -f /home/labuser/work/webapp/values.yaml && test -f /home/labuser/work/webapp/templates/deployment.yaml
$script$, '`helm create <name>`', 'helm create writes a complete working chart (a Deployment, Service, optional Ingress and HPA) that you can adapt. Most real charts start like this.', 10, false, true),
('ee1bc760-4762-5093-b974-df32cdf55b30', '4d838c97-594e-5ea9-b6a8-e8158aac778f', 2, 'Render the templates without installing', $md$Render the chart with the release name `web` and `replicaCount=2`, and save the output to `~/work/rendered.yaml`. Open it and find the Deployment's `replicas:` line.$md$, $script$#!/bin/bash
f=/home/labuser/work/rendered.yaml
grep -q 'kind: Deployment' "$f" && grep -q 'replicas: 2' "$f" && grep -q 'name: web-webapp' "$f"
$script$, '`helm template <release> <chart-dir> --set key=value > file`', 'helm template shows exactly the YAML Helm would send to the cluster. It is the first thing to run when a chart does not do what you expect.', 10, false, false),
('bdad8da1-34cb-5ef5-aa31-28d1038d8232', '4d838c97-594e-5ea9-b6a8-e8158aac778f', 3, 'Install a release', $md$Install the chart as a release named `web` with 2 replicas. Then run `helm list`, `helm status web` and `kubectl get deploy,svc`.$md$, $script$#!/bin/bash
helm status web -o json 2>/dev/null | grep -q '"status":"deployed"' || exit 1
test "$(kubectl get deployment web-webapp -o jsonpath='{.spec.replicas}')" = "2"
$script$, '`helm install <release> <chart-dir> --set replicaCount=2`', 'Helm rendered the templates, applied them, and stored the release (revision 1) as a Secret in the namespace. Every object is named after the release, here web-webapp.', 15, false, true),
('7da960e4-0f72-5577-bcf3-27cf75801c45', '4d838c97-594e-5ea9-b6a8-e8158aac778f', 4, 'Upgrade with a values file', $md$Create `~/work/prod-values.yaml` that sets `replicaCount` to `3` and `image.tag` to `"1.27"`. Upgrade the `web` release with it (keep the chart the same). Check `helm history web`.
$md$, $script$#!/bin/bash
test "$(kubectl get deployment web-webapp -o jsonpath='{.spec.replicas} {.spec.template.spec.containers[0].image}')" = "3 nginx:1.27" || exit 1
helm history web | awk 'NR>1{print $1}' | grep -qx 2
$script$, '`image.tag` means a nested key: `image:` then `  tag: "1.27"` on the next line. Then `helm upgrade web ./webapp -f prod-values.yaml`.', 'Values from -f override the chart''s values.yaml. The upgrade created revision 2 and rolled the Deployment to the new image.', 20, false, true),
('68683a06-e857-5efd-b1e8-3481c17d3b07', '4d838c97-594e-5ea9-b6a8-e8158aac778f', 5, 'Roll back the release', $md$Roll the `web` release back to revision 1. Check `helm history web` again and the Deployment's replicas and image.$md$, $script$#!/bin/bash
test "$(kubectl get deployment web-webapp -o jsonpath='{.spec.replicas}')" = "2" || exit 1
helm history web | awk 'NR>1{print $1}' | grep -qx 3
$script$, '`helm rollback <release> <revision>`', 'A rollback re-applies revision 1''s rendered manifests and records them as a new revision (3). History is never rewritten.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('36c1653f-b6ba-56fb-9006-33e6b1a058d8', '4d838c97-594e-5ea9-b6a8-e8158aac778f', 1, $json$[{"id":"646795ba-a1f9-576d-8fd9-c5e3bcbf2c96","lab_id":"4d838c97-594e-5ea9-b6a8-e8158aac778f","position":1,"title":"Create a chart","description":"In your work folder, create a new chart called `webapp` with `helm create`. Look around with `ls -R webapp` and open `webapp/values.yaml` and `webapp/templates/deployment.yaml`.","verification_script":"#!/bin/bash\ntest -f /home/labuser/work/webapp/Chart.yaml \u0026\u0026 test -f /home/labuser/work/webapp/values.yaml \u0026\u0026 test -f /home/labuser/work/webapp/templates/deployment.yaml\n","hint_context":"`helm create \u003cname\u003e`","explanation_context":"helm create writes a complete working chart (a Deployment, Service, optional Ingress and HPA) that you can adapt. Most real charts start like this.","points":10,"is_optional":false,"is_stateful":true},{"id":"ee1bc760-4762-5093-b974-df32cdf55b30","lab_id":"4d838c97-594e-5ea9-b6a8-e8158aac778f","position":2,"title":"Render the templates without installing","description":"Render the chart with the release name `web` and `replicaCount=2`, and save the output to `~/work/rendered.yaml`. Open it and find the Deployment's `replicas:` line.","verification_script":"#!/bin/bash\nf=/home/labuser/work/rendered.yaml\ngrep -q 'kind: Deployment' \"$f\" \u0026\u0026 grep -q 'replicas: 2' \"$f\" \u0026\u0026 grep -q 'name: web-webapp' \"$f\"\n","hint_context":"`helm template \u003crelease\u003e \u003cchart-dir\u003e --set key=value \u003e file`","explanation_context":"helm template shows exactly the YAML Helm would send to the cluster. It is the first thing to run when a chart does not do what you expect.","points":10,"is_optional":false,"is_stateful":false},{"id":"bdad8da1-34cb-5ef5-aa31-28d1038d8232","lab_id":"4d838c97-594e-5ea9-b6a8-e8158aac778f","position":3,"title":"Install a release","description":"Install the chart as a release named `web` with 2 replicas. Then run `helm list`, `helm status web` and `kubectl get deploy,svc`.","verification_script":"#!/bin/bash\nhelm status web -o json 2\u003e/dev/null | grep -q '\"status\":\"deployed\"' || exit 1\ntest \"$(kubectl get deployment web-webapp -o jsonpath='{.spec.replicas}')\" = \"2\"\n","hint_context":"`helm install \u003crelease\u003e \u003cchart-dir\u003e --set replicaCount=2`","explanation_context":"Helm rendered the templates, applied them, and stored the release (revision 1) as a Secret in the namespace. Every object is named after the release, here web-webapp.","points":15,"is_optional":false,"is_stateful":true},{"id":"7da960e4-0f72-5577-bcf3-27cf75801c45","lab_id":"4d838c97-594e-5ea9-b6a8-e8158aac778f","position":4,"title":"Upgrade with a values file","description":"Create `~/work/prod-values.yaml` that sets `replicaCount` to `3` and `image.tag` to `\"1.27\"`. Upgrade the `web` release with it (keep the chart the same). Check `helm history web`.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get deployment web-webapp -o jsonpath='{.spec.replicas} {.spec.template.spec.containers[0].image}')\" = \"3 nginx:1.27\" || exit 1\nhelm history web | awk 'NR\u003e1{print $1}' | grep -qx 2\n","hint_context":"`image.tag` means a nested key: `image:` then `  tag: \"1.27\"` on the next line. Then `helm upgrade web ./webapp -f prod-values.yaml`.","explanation_context":"Values from -f override the chart's values.yaml. The upgrade created revision 2 and rolled the Deployment to the new image.","points":20,"is_optional":false,"is_stateful":true},{"id":"68683a06-e857-5efd-b1e8-3481c17d3b07","lab_id":"4d838c97-594e-5ea9-b6a8-e8158aac778f","position":5,"title":"Roll back the release","description":"Roll the `web` release back to revision 1. Check `helm history web` again and the Deployment's replicas and image.","verification_script":"#!/bin/bash\ntest \"$(kubectl get deployment web-webapp -o jsonpath='{.spec.replicas}')\" = \"2\" || exit 1\nhelm history web | awk 'NR\u003e1{print $1}' | grep -qx 3\n","hint_context":"`helm rollback \u003crelease\u003e \u003crevision\u003e`","explanation_context":"A rollback re-applies revision 1's rendered manifests and records them as a new revision (3). History is never rewritten.","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('a8ac2932-aeda-5050-b642-6651bed02751', '36c1653f-b6ba-56fb-9006-33e6b1a058d8', '646795ba-a1f9-576d-8fd9-c5e3bcbf2c96', 1, 'Create a chart', $md$In your work folder, create a new chart called `webapp` with `helm create`. Look around with `ls -R webapp` and open `webapp/values.yaml` and `webapp/templates/deployment.yaml`.$md$, $script$#!/bin/bash
test -f /home/labuser/work/webapp/Chart.yaml && test -f /home/labuser/work/webapp/values.yaml && test -f /home/labuser/work/webapp/templates/deployment.yaml
$script$, '`helm create <name>`', 'helm create writes a complete working chart (a Deployment, Service, optional Ingress and HPA) that you can adapt. Most real charts start like this.', 10, false, true),
('00d627b6-5e85-5a3b-a8e8-8729e9a92faf', '36c1653f-b6ba-56fb-9006-33e6b1a058d8', 'ee1bc760-4762-5093-b974-df32cdf55b30', 2, 'Render the templates without installing', $md$Render the chart with the release name `web` and `replicaCount=2`, and save the output to `~/work/rendered.yaml`. Open it and find the Deployment's `replicas:` line.$md$, $script$#!/bin/bash
f=/home/labuser/work/rendered.yaml
grep -q 'kind: Deployment' "$f" && grep -q 'replicas: 2' "$f" && grep -q 'name: web-webapp' "$f"
$script$, '`helm template <release> <chart-dir> --set key=value > file`', 'helm template shows exactly the YAML Helm would send to the cluster. It is the first thing to run when a chart does not do what you expect.', 10, false, false),
('3e1fa05e-49d3-525b-aaf7-c94dca498a66', '36c1653f-b6ba-56fb-9006-33e6b1a058d8', 'bdad8da1-34cb-5ef5-aa31-28d1038d8232', 3, 'Install a release', $md$Install the chart as a release named `web` with 2 replicas. Then run `helm list`, `helm status web` and `kubectl get deploy,svc`.$md$, $script$#!/bin/bash
helm status web -o json 2>/dev/null | grep -q '"status":"deployed"' || exit 1
test "$(kubectl get deployment web-webapp -o jsonpath='{.spec.replicas}')" = "2"
$script$, '`helm install <release> <chart-dir> --set replicaCount=2`', 'Helm rendered the templates, applied them, and stored the release (revision 1) as a Secret in the namespace. Every object is named after the release, here web-webapp.', 15, false, true),
('5f7bd32a-246c-5d9f-af82-e16b2e0be61f', '36c1653f-b6ba-56fb-9006-33e6b1a058d8', '7da960e4-0f72-5577-bcf3-27cf75801c45', 4, 'Upgrade with a values file', $md$Create `~/work/prod-values.yaml` that sets `replicaCount` to `3` and `image.tag` to `"1.27"`. Upgrade the `web` release with it (keep the chart the same). Check `helm history web`.
$md$, $script$#!/bin/bash
test "$(kubectl get deployment web-webapp -o jsonpath='{.spec.replicas} {.spec.template.spec.containers[0].image}')" = "3 nginx:1.27" || exit 1
helm history web | awk 'NR>1{print $1}' | grep -qx 2
$script$, '`image.tag` means a nested key: `image:` then `  tag: "1.27"` on the next line. Then `helm upgrade web ./webapp -f prod-values.yaml`.', 'Values from -f override the chart''s values.yaml. The upgrade created revision 2 and rolled the Deployment to the new image.', 20, false, true),
('a9902fe8-fdf2-51b0-9241-02b4e9681004', '36c1653f-b6ba-56fb-9006-33e6b1a058d8', '68683a06-e857-5efd-b1e8-3481c17d3b07', 5, 'Roll back the release', $md$Roll the `web` release back to revision 1. Check `helm history web` again and the Deployment's replicas and image.$md$, $script$#!/bin/bash
test "$(kubectl get deployment web-webapp -o jsonpath='{.spec.replicas}')" = "2" || exit 1
helm history web | awk 'NR>1{print $1}' | grep -qx 3
$script$, '`helm rollback <release> <revision>`', 'A rollback re-applies revision 1''s rendered manifests and records them as a new revision (3). History is never rewritten.', 15, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '36c1653f-b6ba-56fb-9006-33e6b1a058d8', updated_at = now()
WHERE id = '4d838c97-594e-5ea9-b6a8-e8158aac778f' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('9bd279a5-00b1-5953-a418-99a84c50d2fe', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is a Helm release?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c98ef511-5868-5f18-a22c-8a4008340717', '9bd279a5-00b1-5953-a418-99a84c50d2fe', 1, $json${"prompt":"What is a Helm release?","multiple":false,"options":[{"id":"a","text":"A new version of Helm itself","is_correct":false},{"id":"b","text":"One installed instance of a chart in a cluster, with its own name and revision history","is_correct":true},{"id":"c","text":"A chart repository","is_correct":false},{"id":"d","text":"A Docker image","is_correct":false}],"explanation":"Installing a chart creates a release. Upgrades and rollbacks add revisions to it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d8df29c2-ea6c-5add-81af-35be37ab6a31', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which file in a chart holds the default settings?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('abf969a7-dd92-518f-80ee-1c17527d9f34', 'd8df29c2-ea6c-5add-81af-35be37ab6a31', 1, $json${"prompt":"Which file in a chart holds the default settings?","multiple":false,"options":[{"id":"a","text":"Chart.yaml","is_correct":false},{"id":"b","text":"values.yaml","is_correct":true},{"id":"c","text":"templates/_helpers.tpl","is_correct":false},{"id":"d","text":"NOTES.txt","is_correct":false}],"explanation":"values.yaml has the defaults; Chart.yaml has metadata such as name, version and appVersion."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('aca724bd-e499-56f0-b936-8b920fbfb20f', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the difference between `version` and `appVersion` in Chart.yaml?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7aaca806-36fc-5546-870e-9da02407ac70', 'aca724bd-e499-56f0-b936-8b920fbfb20f', 1, $json${"prompt":"What is the difference between `version` and `appVersion` in Chart.yaml?","multiple":false,"options":[{"id":"a","text":"They must always be equal","is_correct":false},{"id":"b","text":"version is the chart package's version; appVersion is the version of the application it deploys","is_correct":true},{"id":"c","text":"version is for Helm 2, appVersion for Helm 3","is_correct":false},{"id":"d","text":"appVersion is the Kubernetes version","is_correct":false}],"explanation":"Bump version whenever the chart changes; appVersion tracks the app (often the default image tag)."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('1d417470-d6f1-5122-8985-736cc6481556', '00000000-0000-0000-0000-000000000001', 'mcq', 'Where does Helm 3 store release history?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0f0f7c97-ec74-50a5-987d-9e559651ef91', '1d417470-d6f1-5122-8985-736cc6481556', 1, $json${"prompt":"Where does Helm 3 store release history?","multiple":false,"options":[{"id":"a","text":"In Tiller running in kube-system","is_correct":false},{"id":"b","text":"As Secrets in the release's namespace","is_correct":true},{"id":"c","text":"In ~/.helm on your laptop only","is_correct":false},{"id":"d","text":"In the chart repository","is_correct":false}],"explanation":"Helm 3 has no server component; release data lives in the cluster as Secrets."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0b5dbf6d-dcb1-5c22-8cdf-0e3b967c253f', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which flag makes `helm upgrade` roll back automatically if the upgrade fails?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f72595ba-6124-53fd-9d0f-35e96d532e41', '0b5dbf6d-dcb1-5c22-8cdf-0e3b967c253f', 1, $json${"prompt":"Which flag makes `helm upgrade` roll back automatically if the upgrade fails?","multiple":false,"options":[{"id":"a","text":"--force","is_correct":false},{"id":"b","text":"--atomic","is_correct":true},{"id":"c","text":"--dry-run","is_correct":false},{"id":"d","text":"--reuse-values","is_correct":false}],"explanation":"--atomic waits for the upgrade to succeed and rolls back if it does not."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ad915452-6dd3-529a-b90f-c7e14e622ba6', '00000000-0000-0000-0000-000000000001', 'mcq', 'A release is behaving strangely. Which command shows the manifests Helm actua...', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('557cdf94-d7c5-559e-bc72-33f44717d281', 'ad915452-6dd3-529a-b90f-c7e14e622ba6', 1, $json${"prompt":"A release is behaving strangely. Which command shows the manifests Helm actually applied?","multiple":false,"options":[{"id":"a","text":"helm get manifest \u003crelease\u003e","is_correct":true},{"id":"b","text":"helm repo list","is_correct":false},{"id":"c","text":"helm search hub","is_correct":false},{"id":"d","text":"helm version","is_correct":false}],"explanation":"helm get manifest prints the rendered YAML of the current revision."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('598a1352-17a6-57de-939a-c8a6fa46b197', '00000000-0000-0000-0000-000000000001', 'mcq', 'After `helm uninstall db`, the PostgreSQL data is still on disk. Why?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('cad50a57-6572-5c5a-a403-d9090e558614', '598a1352-17a6-57de-939a-c8a6fa46b197', 1, $json${"prompt":"After `helm uninstall db`, the PostgreSQL data is still on disk. Why?","multiple":false,"options":[{"id":"a","text":"Helm uninstall is broken","is_correct":false},{"id":"b","text":"PVCs created from a StatefulSet's volumeClaimTemplates are not owned by the release, so they are kept","is_correct":true},{"id":"c","text":"Helm moves the data to etcd","is_correct":false},{"id":"d","text":"The data is in a ConfigMap","is_correct":false}],"explanation":"This protects data by default. Delete the PVCs manually if you really want the data gone."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('4918b4f2-671c-5a78-b8ba-3e00a1f9fb09', '00000000-0000-0000-0000-000000000001', 'Quiz: Helm', 'k8s-helm-quiz', 'Quiz covering Helm: Packaging Applications.', 'mcq', 'published', 'module', '8daa77a0-ae8d-5f35-aff4-2cda833e53e7', 15, 70, 5, 7, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '4918b4f2-671c-5a78-b8ba-3e00a1f9fb09' AND question_id NOT IN ('9bd279a5-00b1-5953-a418-99a84c50d2fe', 'd8df29c2-ea6c-5add-81af-35be37ab6a31', 'aca724bd-e499-56f0-b936-8b920fbfb20f', '1d417470-d6f1-5122-8985-736cc6481556', '0b5dbf6d-dcb1-5c22-8cdf-0e3b967c253f', 'ad915452-6dd3-529a-b90f-c7e14e622ba6', '598a1352-17a6-57de-939a-c8a6fa46b197');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('f3c98495-af04-507e-b009-8cb61ae20d9d', '4918b4f2-671c-5a78-b8ba-3e00a1f9fb09', '9bd279a5-00b1-5953-a418-99a84c50d2fe', 'c98ef511-5868-5f18-a22c-8a4008340717', 0, 1),
('67b5dc0f-77ec-54c7-98a0-f899837e5c3f', '4918b4f2-671c-5a78-b8ba-3e00a1f9fb09', 'd8df29c2-ea6c-5add-81af-35be37ab6a31', 'abf969a7-dd92-518f-80ee-1c17527d9f34', 1, 1),
('78c375ff-af31-5b38-93c5-e4c69151c52e', '4918b4f2-671c-5a78-b8ba-3e00a1f9fb09', 'aca724bd-e499-56f0-b936-8b920fbfb20f', '7aaca806-36fc-5546-870e-9da02407ac70', 2, 1),
('db8341c9-1c4a-5beb-b331-9fc73091af3a', '4918b4f2-671c-5a78-b8ba-3e00a1f9fb09', '1d417470-d6f1-5122-8985-736cc6481556', '0f0f7c97-ec74-50a5-987d-9e559651ef91', 3, 1),
('fb09641d-5715-5bd1-b90e-1f1f586fd259', '4918b4f2-671c-5a78-b8ba-3e00a1f9fb09', '0b5dbf6d-dcb1-5c22-8cdf-0e3b967c253f', 'f72595ba-6124-53fd-9d0f-35e96d532e41', 4, 1),
('a9f2bd1a-e4bf-596e-abe0-15f670beb68e', '4918b4f2-671c-5a78-b8ba-3e00a1f9fb09', 'ad915452-6dd3-529a-b90f-c7e14e622ba6', '557cdf94-d7c5-559e-bc72-33f44717d281', 5, 1),
('115148d5-5dea-5514-9694-9d68637c5e1b', '4918b4f2-671c-5a78-b8ba-3e00a1f9fb09', '598a1352-17a6-57de-939a-c8a6fa46b197', 'cad50a57-6572-5c5a-a403-d9090e558614', 6, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('8daa77a0-ae8d-5f35-aff4-2cda833e53e7', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '8c7e60f0-4e81-55a1-b5d2-e985155f8562', 'Quiz: Helm', 'assessment', 1, 8, '4918b4f2-671c-5a78-b8ba-3e00a1f9fb09')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Monitoring, Logging & Autoscaling
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('b5b0d081-fa01-57fe-860d-388f86b35cd6', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Monitoring, Logging & Autoscaling', 9)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('19c963d4-687d-5ae5-9936-3faef76f4bb5', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'b5b0d081-fa01-57fe-860d-388f86b35cd6', 'Monitoring, Logging and Autoscaling', 'notes', 0, $md$Running an app is only half the job. You also need to see what it is doing, find problems before users do, and handle more traffic without waking anyone up. This lesson covers the three pillars of **observability** in Kubernetes (events and logs, metrics, dashboards and alerts) plus **autoscaling**, which is built on metrics.

## Looking at the cluster with kubectl

Before any fancy tool, kubectl answers most questions:

```bash
kubectl get nodes -o wide                  # node status, versions, IPs
kubectl get pods -A -o wide                # every pod, where it runs
kubectl get pods -w                        # watch changes live (Linux: watch kubectl get pods)
kubectl get all -n shop                    # the common objects in a namespace
kubectl describe pod <name>                # details + Events
kubectl get events -A --sort-by=.lastTimestamp          # recent cluster events
kubectl get events --field-selector type=Warning        # only problems
```

**Events** are short records of what happened: pod scheduled, image pulled, probe failed, container killed, volume could not attach. They are kept for only about **one hour** by default, so look at them soon after a problem, or ship them to your logging system.

A quick health check you can run any time:

```bash
kubectl get nodes                                      # are all nodes Ready?
kubectl get pods -A | grep -v -E 'Running|Completed'   # anything not healthy?
kubectl get events -A --field-selector type=Warning
```

[[lab-task:1]]

```knowledge-check
{ "questions": [
  { "id": "k8s-obs-kubectl-q1", "type": "mcq",
    "prompt": "A pod failed to start two days ago and `kubectl get events` shows nothing about it. Why?",
    "options": [
      {"id": "a", "text": "Events are only kept for a short time (about an hour by default)"},
      {"id": "b", "text": "Events are only recorded for Deployments"},
      {"id": "c", "text": "You need helm to see events"},
      {"id": "d", "text": "Events are stored inside the container"}
    ],
    "correct": "a",
    "explanation": "Events expire quickly. For history, forward events and logs to a central system." }
] }
```

## Logs

Kubernetes expects apps to write logs to **stdout and stderr**, not to files. The container runtime stores that output on the node, and `kubectl logs` reads it:

```bash
kubectl logs deploy/api                  # one pod of a Deployment
kubectl logs -l app=api --all-containers --prefix   # every pod with the label
kubectl logs api-7c9d-xk2 -c sidecar     # a specific container
kubectl logs api-7c9d-xk2 --previous     # the crashed instance
kubectl logs api-7c9d-xk2 --since=15m -f # last 15 minutes, then follow
```

The catch: node logs are rotated and **deleted with the pod**. When a pod is gone, so are its logs. In production you ship logs off the nodes:

- A **log agent DaemonSet** (Fluent Bit, Fluentd, Vector, Promtail/Alloy) runs on every node, reads all container logs from `/var/log/containers`, and sends them to a store.
- The store and UI: **Loki + Grafana**, **Elasticsearch/OpenSearch + Kibana (EFK)**, or a cloud service (CloudWatch, Cloud Logging, Azure Monitor).

Write logs as **structured JSON** with a level, a timestamp and a request ID. That makes them searchable.

```knowledge-check
{ "questions": [
  { "id": "k8s-obs-logs-q1", "type": "mcq",
    "prompt": "Where should an app running in Kubernetes write its logs?",
    "options": [
      {"id": "a", "text": "To a file inside the container"},
      {"id": "b", "text": "To stdout/stderr, so the runtime and log agents can collect them"},
      {"id": "c", "text": "Directly into etcd"},
      {"id": "d", "text": "Into a ConfigMap"}
    ],
    "correct": "b",
    "explanation": "stdout/stderr is what kubectl logs and node log agents read. Files inside the container disappear with it." }
] }
```

## Metrics: metrics-server and kubectl top

**metrics-server** collects current CPU and memory usage from every kubelet. It powers `kubectl top` and the autoscalers. Most managed clusters have it; on minikube run `minikube addons enable metrics-server`.

```bash
kubectl top nodes
kubectl top pods -A --sort-by=memory
kubectl top pod api-7c9d-xk2 --containers
```

If you get `error: Metrics API not available`, metrics-server is not installed. metrics-server only keeps the **latest** values; it is not a monitoring system with history. For history, graphs and alerts you need Prometheus.

```knowledge-check
{ "questions": [
  { "id": "k8s-obs-metrics-q1", "type": "mcq",
    "prompt": "`kubectl top pods` fails with 'Metrics API not available'. What is missing?",
    "options": [
      {"id": "a", "text": "Prometheus"},
      {"id": "b", "text": "metrics-server"},
      {"id": "c", "text": "An Ingress controller"},
      {"id": "d", "text": "Helm"}
    ],
    "correct": "b",
    "explanation": "kubectl top reads from the Metrics API, which metrics-server provides." }
] }
```

## Prometheus and Grafana

The standard monitoring stack:

- **Prometheus** *scrapes* (pulls) metrics over HTTP from targets every few seconds and stores them as time series. You query it with **PromQL**.
- **node-exporter** (a DaemonSet) exposes node metrics: CPU, memory, disk, network.
- **kube-state-metrics** exposes the state of Kubernetes objects: desired vs available replicas, pod restarts, pending pods.
- **Alertmanager** sends alerts (Slack, email, PagerDuty) when rules fire.
- **Grafana** draws dashboards from Prometheus data.

The **kube-prometheus-stack** Helm chart installs all of these, with ready-made dashboards and alerts:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# open http://localhost:3000 ; user admin, password from:
kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

To expose Grafana without port-forward, set its Service type in your values file (for example `grafana.service.type: NodePort`) or add an Ingress. To make Prometheus scrape your own app, expose a `/metrics` endpoint and create a **ServiceMonitor** object that points at your app's Service.

A few PromQL queries worth knowing:

```
sum(rate(container_cpu_usage_seconds_total{namespace="shop"}[5m])) by (pod)       # CPU per pod
kube_deployment_status_replicas_available / kube_deployment_spec_replicas           # health of deployments
increase(kube_pod_container_status_restarts_total[1h]) > 3                          # pods restarting often
```

You can also monitor nodes outside Kubernetes (for example Windows servers with windows_exporter) by adding them as extra scrape targets in the chart's values (`prometheus.prometheusSpec.additionalScrapeConfigs`).

```knowledge-check
{ "questions": [
  { "id": "k8s-obs-prom-q1", "type": "mcq",
    "prompt": "How does Prometheus get metrics from your application?",
    "options": [
      {"id": "a", "text": "The app pushes metrics into etcd"},
      {"id": "b", "text": "Prometheus scrapes an HTTP endpoint (usually /metrics) on a schedule"},
      {"id": "c", "text": "Grafana collects them and forwards them to Prometheus"},
      {"id": "d", "text": "kubectl top sends them"}
    ],
    "correct": "b",
    "explanation": "Prometheus is pull-based. A ServiceMonitor tells the Prometheus Operator which Services to scrape." },
  { "id": "k8s-obs-prom-q2", "type": "mcq",
    "prompt": "Which component gives Prometheus the number of desired vs available replicas of each Deployment?",
    "options": [
      {"id": "a", "text": "node-exporter"},
      {"id": "b", "text": "kube-state-metrics"},
      {"id": "c", "text": "Grafana"},
      {"id": "d", "text": "CoreDNS"}
    ],
    "correct": "b",
    "explanation": "kube-state-metrics turns the state of Kubernetes objects into metrics. node-exporter covers machine-level metrics." }
] }
```

## The Kubernetes Dashboard

The **Kubernetes Dashboard** is a web UI to browse and edit cluster objects. On minikube: `minikube dashboard`. On other clusters install it with its Helm chart and log in with a ServiceAccount token:

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard -n kubernetes-dashboard --create-namespace
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
kubectl -n kubernetes-dashboard create token <service-account-name>    # paste this token to log in
```

Never expose the dashboard to the internet, and do not give it cluster-admin rights "to make it work". A dashboard with admin rights is an open door into your whole cluster. Many teams use tools like **k9s** (a terminal UI) or **Headlamp** / **Lens** instead.

```knowledge-check
{ "questions": [
  { "id": "k8s-obs-dash-q1", "type": "mcq",
    "prompt": "Why is exposing the Kubernetes Dashboard publicly with a cluster-admin token dangerous?",
    "options": [
      {"id": "a", "text": "It makes the cluster slower"},
      {"id": "b", "text": "Anyone who gets in can control every object in the cluster"},
      {"id": "c", "text": "The dashboard deletes pods automatically"},
      {"id": "d", "text": "It disables RBAC"}
    ],
    "correct": "b",
    "explanation": "The dashboard acts with the permissions of the token used. Keep it private and give it minimal rights." }
] }
```

## Autoscaling

Picture a restaurant kitchen on a busy Saturday night. The manager watches how many orders are waiting and calls in extra cooks when the queue grows, then sends them home once things are quiet again. That is what the autoscalers below do, just with pods and nodes instead of cooks. Kubernetes can scale at three levels:

| Autoscaler | Scales | Based on |
|---|---|---|
| **HorizontalPodAutoscaler (HPA)** | The number of **pods** of a Deployment/StatefulSet | CPU, memory or custom metrics |
| **VerticalPodAutoscaler (VPA)** | The **requests/limits** of pods | Observed usage over time |
| **Cluster Autoscaler / Karpenter** | The number of **nodes** | Pods stuck Pending for lack of room |

They work together: traffic grows → HPA adds pods → new pods do not fit → the cluster autoscaler adds a node.

Creating an HPA:

```bash
kubectl autoscale deployment api --cpu-percent=60 --min=2 --max=8
kubectl get hpa -w
```

or declaratively:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60     # % of the pods' CPU *request*
```

Things that trip people up:

- The HPA needs **metrics-server**. Without it TARGETS shows `<unknown>` and nothing scales.
- Utilization is measured **against requests**. Pods without CPU requests cannot be autoscaled on CPU.
- Remove `replicas` from the Deployment YAML (or ignore it in GitOps). Otherwise every `kubectl apply` fights the HPA.
- The HPA scales **down slowly** on purpose (a 5-minute stabilization window by default) to avoid flapping.
- For queue-based or event-driven scaling (including scaling to zero), look at **KEDA**.

[[lab-task:2]]

[[lab-task:3]]

```knowledge-check
{ "questions": [
  { "id": "k8s-obs-hpa-q1", "type": "mcq",
    "prompt": "An HPA targets 50% CPU. Pods request 200m CPU and each uses about 200m. What does the HPA do?",
    "options": [
      {"id": "a", "text": "Nothing; usage equals the request"},
      {"id": "b", "text": "Scales up, because usage is 100% of the request, double the 50% target"},
      {"id": "c", "text": "Scales down"},
      {"id": "d", "text": "Raises the CPU limit"}
    ],
    "correct": "b",
    "explanation": "Utilization = usage / request = 100%. The HPA adds pods until the average is back near 50%, roughly doubling the replicas." },
  { "id": "k8s-obs-hpa-q2", "type": "mcq",
    "prompt": "Pods are Pending with 'Insufficient cpu' after the HPA scaled up. Which component fixes this?",
    "options": [
      {"id": "a", "text": "VerticalPodAutoscaler"},
      {"id": "b", "text": "Cluster Autoscaler (or Karpenter), which adds nodes"},
      {"id": "c", "text": "metrics-server"},
      {"id": "d", "text": "kube-proxy"}
    ],
    "correct": "b",
    "explanation": "The HPA adds pods; when they do not fit, the cluster autoscaler adds nodes for them." }
] }
```

## Interview questions and real-world scenarios

**Q: What are the three pillars of observability?**
Metrics (Prometheus), logs (Loki/EFK), traces (OpenTelemetry with Jaeger/Tempo). Events are a fourth Kubernetes-specific signal.

**Q: How do you collect logs in Kubernetes?**
Apps log to stdout/stderr; a DaemonSet agent (Fluent Bit, Vector, Alloy) ships node logs to a central store. Sidecar log shippers are only for apps that must write files.

**Q: What would you alert on for a web service?**
User-facing symptoms first: error rate, latency (p95/p99), availability (the "golden signals", also traffic and saturation). Plus platform alerts: pods crash-looping, nodes NotReady, disk almost full, certificates expiring, PVs filling up.

**Q: How does HPA calculate replicas?**
desired = ceil(current × currentMetric / target), within min/max, with a scale-down stabilization window. Utilization is against requests.

**Q: HPA vs VPA vs Cluster Autoscaler?**
More pods, bigger pods, more nodes. Don't use HPA and VPA on the same CPU/memory metric at the same time.

**Real-world scenario: traffic spike, HPA scaled up, but latency is still high.**
New pods are Pending (no node capacity → cluster autoscaler too slow or at max), pods are slow to become ready (long startup), or the bottleneck is elsewhere (the database). Check pending pods, readiness time and database metrics; consider a higher `minReplicas` before known peaks.

**Real-world scenario: "We have no idea why it was slow last night."**
Logs were lost with the pods and metrics weren't retained. Set up central logs, Prometheus with retention (or long-term storage like Thanos/Mimir), and dashboards per service.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-obs-int-q1",
      "type": "mcq",
      "prompt": "Which alert is most useful to page an engineer at night for a web API?",
      "options": [
        {
          "id": "a",
          "text": "CPU of one pod above 50%"
        },
        {
          "id": "b",
          "text": "Error rate above 5% for 5 minutes (a user-facing symptom)"
        },
        {
          "id": "c",
          "text": "A new Deployment was created"
        },
        {
          "id": "d",
          "text": "A ConfigMap changed"
        }
      ],
      "correct": "b",
      "explanation": "Page on symptoms users feel (errors, latency). Resource-level signals are better as dashboards or low-urgency alerts."
    }
  ]
}
```
$md$, 50, $json$[{"id":"k8s-obs-kubectl-q1","type":"mcq","correct":"a"},{"id":"k8s-obs-logs-q1","type":"mcq","correct":"b"},{"id":"k8s-obs-metrics-q1","type":"mcq","correct":"b"},{"id":"k8s-obs-prom-q1","type":"mcq","correct":"b"},{"id":"k8s-obs-prom-q2","type":"mcq","correct":"b"},{"id":"k8s-obs-dash-q1","type":"mcq","correct":"b"},{"id":"k8s-obs-hpa-q1","type":"mcq","correct":"b"},{"id":"k8s-obs-hpa-q2","type":"mcq","correct":"b"},{"id":"k8s-obs-int-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('46582c8d-a427-51e9-9843-8a5346e1f69e', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '19c963d4-687d-5ae5-9936-3faef76f4bb5', 'module', 'Monitoring, Logging and Autoscaling', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/app.yaml <<'MFEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: nginx:1.27
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: reporter
spec:
  nodeSelector:
    hardware: gpu
  containers:
  - name: reporter
    image: busybox:1.36

MFEOF
chmod 666 /home/labuser/work/app.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '822d8449-3f8a-5eb8-9d32-6e9d72232b4a' AND id NOT IN ('3cfa0496-a005-5e03-afca-50dcc2ddee12', '8e18c369-5b2e-52ec-92a2-c515f9c73e5c', 'd2465d7f-df31-5e17-b8f8-fd664295da80');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '822d8449-3f8a-5eb8-9d32-6e9d72232b4a';
DELETE FROM lab_tasks WHERE lab_id = '46582c8d-a427-51e9-9843-8a5346e1f69e' AND id NOT IN ('f5f24704-aa5e-57b8-b898-08482852936d', 'b6dcb943-b167-5a39-a02b-2c7a3c019f77', '2bcbb504-048c-570a-9071-b6314d54fbcd');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '46582c8d-a427-51e9-9843-8a5346e1f69e';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('f5f24704-aa5e-57b8-b898-08482852936d', '46582c8d-a427-51e9-9843-8a5346e1f69e', 1, 'Find out why a pod is not running', $md$Apply `app.yaml`. One pod never starts. Use `kubectl get pods`, `kubectl describe pod` and `kubectl get events --sort-by=.lastTimestamp` to find which pod it is and why. Save the **name of the node label** it is waiting for (just the key) to `~/work/answer.txt`.
$md$, $script$#!/bin/bash
grep -qx 'hardware' /home/labuser/work/answer.txt
$script$, 'Look for the FailedScheduling event. It says the node(s) did not match the pod''s node affinity/selector. Then read the pod''s nodeSelector.', 'The reporter pod has nodeSelector hardware=gpu and no node has that label. Events plus describe answer most "why isn''t it running" questions within a minute.', 15, false, true),
('b6dcb943-b167-5a39-a02b-2c7a3c019f77', '46582c8d-a427-51e9-9843-8a5346e1f69e', 2, 'Add a HorizontalPodAutoscaler', $md$Create an HPA for the `api` Deployment that keeps average CPU around **60%**, with at least **2** and at most **8** replicas. Check it with `kubectl get hpa`.$md$, $script$#!/bin/bash
test "$(kubectl get hpa api -o jsonpath='{.spec.minReplicas} {.spec.maxReplicas} {.spec.metrics[0].resource.target.averageUtilization}')" = "2 8 60"
$script$, '`kubectl autoscale deployment <name> --cpu-percent=<n> --min=<n> --max=<n>`', 'The HPA compares actual CPU usage (from metrics-server) with the pods'' CPU requests. This sandbox has no metrics-server, so TARGETS shows <unknown>, which is exactly what you would see on a real cluster that is missing it.', 15, false, true),
('2bcbb504-048c-570a-9071-b6314d54fbcd', '46582c8d-a427-51e9-9843-8a5346e1f69e', 3, 'Write an autoscaling/v2 HPA with two metrics', $md$Replace the HPA: delete `api` and write `hpa.yaml` with `apiVersion: autoscaling/v2`, name `api`, targeting Deployment `api`, min 2, max 10, and **two** metrics: CPU average utilization 60% and memory average utilization 75%. Apply it.
$md$, $script$#!/bin/bash
test "$(kubectl get hpa api -o jsonpath='{.spec.maxReplicas}')" = "10" || exit 1
M=$(kubectl get hpa api -o jsonpath='{range .spec.metrics[*]}{.resource.name}={.resource.target.averageUtilization}{"\n"}{end}' | sort | tr '\n' ' ')
test "$M" = "cpu=60 memory=75 "
$script$, '`metrics:` is a list; each item has `type: Resource` and `resource:` with `name` and `target: {type: Utilization, averageUtilization: N}`. `scaleTargetRef` names the Deployment.', 'With several metrics the HPA computes a replica count for each and uses the highest, so the app scales up if either CPU or memory is high.', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('822d8449-3f8a-5eb8-9d32-6e9d72232b4a', '46582c8d-a427-51e9-9843-8a5346e1f69e', 1, $json$[{"id":"f5f24704-aa5e-57b8-b898-08482852936d","lab_id":"46582c8d-a427-51e9-9843-8a5346e1f69e","position":1,"title":"Find out why a pod is not running","description":"Apply `app.yaml`. One pod never starts. Use `kubectl get pods`, `kubectl describe pod` and `kubectl get events --sort-by=.lastTimestamp` to find which pod it is and why. Save the **name of the node label** it is waiting for (just the key) to `~/work/answer.txt`.\n","verification_script":"#!/bin/bash\ngrep -qx 'hardware' /home/labuser/work/answer.txt\n","hint_context":"Look for the FailedScheduling event. It says the node(s) did not match the pod's node affinity/selector. Then read the pod's nodeSelector.","explanation_context":"The reporter pod has nodeSelector hardware=gpu and no node has that label. Events plus describe answer most \"why isn't it running\" questions within a minute.","points":15,"is_optional":false,"is_stateful":true},{"id":"b6dcb943-b167-5a39-a02b-2c7a3c019f77","lab_id":"46582c8d-a427-51e9-9843-8a5346e1f69e","position":2,"title":"Add a HorizontalPodAutoscaler","description":"Create an HPA for the `api` Deployment that keeps average CPU around **60%**, with at least **2** and at most **8** replicas. Check it with `kubectl get hpa`.","verification_script":"#!/bin/bash\ntest \"$(kubectl get hpa api -o jsonpath='{.spec.minReplicas} {.spec.maxReplicas} {.spec.metrics[0].resource.target.averageUtilization}')\" = \"2 8 60\"\n","hint_context":"`kubectl autoscale deployment \u003cname\u003e --cpu-percent=\u003cn\u003e --min=\u003cn\u003e --max=\u003cn\u003e`","explanation_context":"The HPA compares actual CPU usage (from metrics-server) with the pods' CPU requests. This sandbox has no metrics-server, so TARGETS shows \u003cunknown\u003e, which is exactly what you would see on a real cluster that is missing it.","points":15,"is_optional":false,"is_stateful":true},{"id":"2bcbb504-048c-570a-9071-b6314d54fbcd","lab_id":"46582c8d-a427-51e9-9843-8a5346e1f69e","position":3,"title":"Write an autoscaling/v2 HPA with two metrics","description":"Replace the HPA: delete `api` and write `hpa.yaml` with `apiVersion: autoscaling/v2`, name `api`, targeting Deployment `api`, min 2, max 10, and **two** metrics: CPU average utilization 60% and memory average utilization 75%. Apply it.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get hpa api -o jsonpath='{.spec.maxReplicas}')\" = \"10\" || exit 1\nM=$(kubectl get hpa api -o jsonpath='{range .spec.metrics[*]}{.resource.name}={.resource.target.averageUtilization}{\"\\n\"}{end}' | sort | tr '\\n' ' ')\ntest \"$M\" = \"cpu=60 memory=75 \"\n","hint_context":"`metrics:` is a list; each item has `type: Resource` and `resource:` with `name` and `target: {type: Utilization, averageUtilization: N}`. `scaleTargetRef` names the Deployment.","explanation_context":"With several metrics the HPA computes a replica count for each and uses the highest, so the app scales up if either CPU or memory is high.","points":20,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('3cfa0496-a005-5e03-afca-50dcc2ddee12', '822d8449-3f8a-5eb8-9d32-6e9d72232b4a', 'f5f24704-aa5e-57b8-b898-08482852936d', 1, 'Find out why a pod is not running', $md$Apply `app.yaml`. One pod never starts. Use `kubectl get pods`, `kubectl describe pod` and `kubectl get events --sort-by=.lastTimestamp` to find which pod it is and why. Save the **name of the node label** it is waiting for (just the key) to `~/work/answer.txt`.
$md$, $script$#!/bin/bash
grep -qx 'hardware' /home/labuser/work/answer.txt
$script$, 'Look for the FailedScheduling event. It says the node(s) did not match the pod''s node affinity/selector. Then read the pod''s nodeSelector.', 'The reporter pod has nodeSelector hardware=gpu and no node has that label. Events plus describe answer most "why isn''t it running" questions within a minute.', 15, false, true),
('8e18c369-5b2e-52ec-92a2-c515f9c73e5c', '822d8449-3f8a-5eb8-9d32-6e9d72232b4a', 'b6dcb943-b167-5a39-a02b-2c7a3c019f77', 2, 'Add a HorizontalPodAutoscaler', $md$Create an HPA for the `api` Deployment that keeps average CPU around **60%**, with at least **2** and at most **8** replicas. Check it with `kubectl get hpa`.$md$, $script$#!/bin/bash
test "$(kubectl get hpa api -o jsonpath='{.spec.minReplicas} {.spec.maxReplicas} {.spec.metrics[0].resource.target.averageUtilization}')" = "2 8 60"
$script$, '`kubectl autoscale deployment <name> --cpu-percent=<n> --min=<n> --max=<n>`', 'The HPA compares actual CPU usage (from metrics-server) with the pods'' CPU requests. This sandbox has no metrics-server, so TARGETS shows <unknown>, which is exactly what you would see on a real cluster that is missing it.', 15, false, true),
('d2465d7f-df31-5e17-b8f8-fd664295da80', '822d8449-3f8a-5eb8-9d32-6e9d72232b4a', '2bcbb504-048c-570a-9071-b6314d54fbcd', 3, 'Write an autoscaling/v2 HPA with two metrics', $md$Replace the HPA: delete `api` and write `hpa.yaml` with `apiVersion: autoscaling/v2`, name `api`, targeting Deployment `api`, min 2, max 10, and **two** metrics: CPU average utilization 60% and memory average utilization 75%. Apply it.
$md$, $script$#!/bin/bash
test "$(kubectl get hpa api -o jsonpath='{.spec.maxReplicas}')" = "10" || exit 1
M=$(kubectl get hpa api -o jsonpath='{range .spec.metrics[*]}{.resource.name}={.resource.target.averageUtilization}{"\n"}{end}' | sort | tr '\n' ' ')
test "$M" = "cpu=60 memory=75 "
$script$, '`metrics:` is a list; each item has `type: Resource` and `resource:` with `name` and `target: {type: Utilization, averageUtilization: N}`. `scaleTargetRef` names the Deployment.', 'With several metrics the HPA computes a replica count for each and uses the highest, so the app scales up if either CPU or memory is high.', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '822d8449-3f8a-5eb8-9d32-6e9d72232b4a', updated_at = now()
WHERE id = '46582c8d-a427-51e9-9843-8a5346e1f69e' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b964ad06-9027-50bb-b745-db1cf31522d1', '00000000-0000-0000-0000-000000000001', 'mcq', 'What happens to a pod''s logs on the node when the pod is deleted?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5b2f8fd9-b01b-516e-96c2-62727f1a1948', 'b964ad06-9027-50bb-b745-db1cf31522d1', 1, $json${"prompt":"What happens to a pod's logs on the node when the pod is deleted?","multiple":false,"options":[{"id":"a","text":"They are kept forever in etcd","is_correct":false},{"id":"b","text":"They are removed, which is why logs are shipped to a central store","is_correct":true},{"id":"c","text":"They move to the next pod","is_correct":false},{"id":"d","text":"They are emailed to the admin","is_correct":false}],"explanation":"Node logs belong to the container. A log agent DaemonSet ships them to Loki, Elasticsearch or a cloud service."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('58b33983-df98-5fce-ad49-8e63a570a219', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the typical way to run a log collector like Fluent Bit?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c9939bba-627e-540b-8cde-4dc98c7f7e8d', '58b33983-df98-5fce-ad49-8e63a570a219', 1, $json${"prompt":"What is the typical way to run a log collector like Fluent Bit?","multiple":false,"options":[{"id":"a","text":"As a DaemonSet, one pod per node","is_correct":true},{"id":"b","text":"As a CronJob","is_correct":false},{"id":"c","text":"Inside every application image","is_correct":false},{"id":"d","text":"As a single Deployment replica","is_correct":false}],"explanation":"Each node has its own container log files, so the collector must run on every node."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('76a60d18-2c8c-5a64-9053-e85d3356cbd7', '00000000-0000-0000-0000-000000000001', 'mcq', 'An HPA shows TARGETS <unknown>/60%. What is the most likely cause?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e7dc0b90-e9e2-578b-af4e-9560c966ba99', '76a60d18-2c8c-5a64-9053-e85d3356cbd7', 1, $json${"prompt":"An HPA shows TARGETS \u003cunknown\u003e/60%. What is the most likely cause?","multiple":false,"options":[{"id":"a","text":"The Deployment has too many replicas","is_correct":false},{"id":"b","text":"metrics-server is missing, or the pods have no CPU requests","is_correct":true},{"id":"c","text":"The HPA must be created with Helm","is_correct":false},{"id":"d","text":"The Service is ClusterIP","is_correct":false}],"explanation":"The HPA needs usage data from metrics-server and computes utilization against requests."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ebb78675-5d33-5c6a-9f96-ab7e2e01b005', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which tool is used to build dashboards on top of Prometheus data?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c21015dd-f301-5f2d-a6a2-0388317c0377', 'ebb78675-5d33-5c6a-9f96-ab7e2e01b005', 1, $json${"prompt":"Which tool is used to build dashboards on top of Prometheus data?","multiple":false,"options":[{"id":"a","text":"Alertmanager","is_correct":false},{"id":"b","text":"Grafana","is_correct":true},{"id":"c","text":"kube-proxy","is_correct":false},{"id":"d","text":"etcd","is_correct":false}],"explanation":"Grafana visualizes; Prometheus stores and queries; Alertmanager routes alerts."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('027197af-7f46-5906-8551-ecfdef3ef0a2', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does the Cluster Autoscaler react to?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ee280f3a-1494-5f14-836f-8a4646bc7912', '027197af-7f46-5906-8551-ecfdef3ef0a2', 1, $json${"prompt":"What does the Cluster Autoscaler react to?","multiple":false,"options":[{"id":"a","text":"High CPU usage on a single pod","is_correct":false},{"id":"b","text":"Pods that stay Pending because no node has room (and underused nodes it can remove)","is_correct":true},{"id":"c","text":"Failed liveness probes","is_correct":false},{"id":"d","text":"New Helm releases","is_correct":false}],"explanation":"It adds nodes for unschedulable pods and removes nodes that are mostly empty."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a52a095e-a582-5a27-b3fd-0fcef9a73700', '00000000-0000-0000-0000-000000000001', 'mcq', 'Your app exposes /metrics. With kube-prometheus-stack installed, how do you m...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4a2da0ef-43fc-53d0-aa89-8b76b2cc848e', 'a52a095e-a582-5a27-b3fd-0fcef9a73700', 1, $json${"prompt":"Your app exposes /metrics. With kube-prometheus-stack installed, how do you make Prometheus scrape it?","multiple":false,"options":[{"id":"a","text":"Restart Prometheus","is_correct":false},{"id":"b","text":"Create a ServiceMonitor that selects your app's Service","is_correct":true},{"id":"c","text":"Add the app to kube-system","is_correct":false},{"id":"d","text":"Run kubectl top","is_correct":false}],"explanation":"The Prometheus Operator watches ServiceMonitor objects and adds matching Services as scrape targets."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('0e885af3-4393-5331-a0f9-7441054ab6c7', '00000000-0000-0000-0000-000000000001', 'Quiz: Monitoring, Logging & Autoscaling', 'k8s-observability-quiz', 'Quiz covering Monitoring, Logging & Autoscaling.', 'mcq', 'published', 'module', '404642ba-977e-5b0c-b766-59e027ff951b', 15, 70, 5, 6, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = '0e885af3-4393-5331-a0f9-7441054ab6c7' AND question_id NOT IN ('b964ad06-9027-50bb-b745-db1cf31522d1', '58b33983-df98-5fce-ad49-8e63a570a219', '76a60d18-2c8c-5a64-9053-e85d3356cbd7', 'ebb78675-5d33-5c6a-9f96-ab7e2e01b005', '027197af-7f46-5906-8551-ecfdef3ef0a2', 'a52a095e-a582-5a27-b3fd-0fcef9a73700');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('fa23e644-9e1b-560e-916f-f4118cc520db', '0e885af3-4393-5331-a0f9-7441054ab6c7', 'b964ad06-9027-50bb-b745-db1cf31522d1', '5b2f8fd9-b01b-516e-96c2-62727f1a1948', 0, 1),
('d54da056-7670-5bcb-848b-b7d8dfff5d3a', '0e885af3-4393-5331-a0f9-7441054ab6c7', '58b33983-df98-5fce-ad49-8e63a570a219', 'c9939bba-627e-540b-8cde-4dc98c7f7e8d', 1, 1),
('d55b0dad-49e7-5c7c-8d2d-903e665b9d8e', '0e885af3-4393-5331-a0f9-7441054ab6c7', '76a60d18-2c8c-5a64-9053-e85d3356cbd7', 'e7dc0b90-e9e2-578b-af4e-9560c966ba99', 2, 1),
('fbeba547-2bdf-562a-adc9-0abd6564966c', '0e885af3-4393-5331-a0f9-7441054ab6c7', 'ebb78675-5d33-5c6a-9f96-ab7e2e01b005', 'c21015dd-f301-5f2d-a6a2-0388317c0377', 3, 1),
('5b619d49-bfe1-5099-b2e1-6a9b85389c0c', '0e885af3-4393-5331-a0f9-7441054ab6c7', '027197af-7f46-5906-8551-ecfdef3ef0a2', 'ee280f3a-1494-5f14-836f-8a4646bc7912', 4, 1),
('361cf64a-850e-5a68-ab9e-79612d81748c', '0e885af3-4393-5331-a0f9-7441054ab6c7', 'a52a095e-a582-5a27-b3fd-0fcef9a73700', '4a2da0ef-43fc-53d0-aa89-8b76b2cc848e', 5, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('404642ba-977e-5b0c-b766-59e027ff951b', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'b5b0d081-fa01-57fe-860d-388f86b35cd6', 'Quiz: Monitoring, Logging & Autoscaling', 'assessment', 1, 8, '0e885af3-4393-5331-a0f9-7441054ab6c7')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Real Clusters: Setup, Security and Operations
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('a6a3c179-127f-5a21-b823-1ddb520e36eb', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Real Clusters: Setup, Security and Operations', 10)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2c2863cc-1d25-5e1c-8281-0616c84947ec', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'a6a3c179-127f-5a21-b823-1ddb520e36eb', 'Building a Cluster with kubeadm', 'notes', 0, $md$Until now you used a cluster someone else built. This lesson shows how a real multi-node cluster is put together with **kubeadm**, the official tool for bootstrapping Kubernetes on your own machines. Even if you will use a managed service at work, knowing these steps explains what every node is actually running, and it is a common interview topic.

## Managed or self-managed?

| | Managed (EKS, GKE, AKS) | Self-managed (kubeadm, k3s, RKE2) |
|---|---|---|
| Control plane | Run, patched and backed up by the provider | You install, upgrade and back it up |
| Cost | Control-plane fee plus nodes | Only the machines, plus your time |
| Control | Less (provider picks some versions and add-ons) | Full |
| Typical use | Most companies in the cloud | On-premises, edge, air-gapped, learning |

**For production in the cloud, choose managed unless you have a strong reason not to.** Running etcd and control-plane upgrades yourself is real operational work.

The plan for the rest of this lesson: 1 control-plane node + workers, Ubuntu, containerd as the runtime, Calico as the network plugin. You can create the VMs locally with **Multipass**:

```bash
multipass launch --name master  -c 2 -m 2G -d 10G     # 2 CPUs, 2 GB RAM, 10 GB disk
multipass launch --name worker1 -c 2 -m 2G -d 10G
multipass shell master
```

The minimum per node is 2 CPUs and 2 GB of RAM for the control plane. Nodes need unique hostnames and MAC addresses, and full network connectivity between them.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-choice-q1", "type": "mcq",
    "prompt": "With a managed service like EKS or GKE, which of these do you NOT have to do yourself?",
    "options": [
      {"id": "a", "text": "Deploy your applications"},
      {"id": "b", "text": "Back up and upgrade etcd and the API server"},
      {"id": "c", "text": "Choose node sizes"},
      {"id": "d", "text": "Write Deployments and Services"}
    ],
    "correct": "b",
    "explanation": "The provider operates the control plane, including etcd. You still own your workloads and usually your node pools." }
] }
```

## Step 1: prepare every node

Run on **all** nodes (control plane and workers).

**Turn off swap.** By default the kubelet refuses to start with swap on, because it makes memory limits unpredictable.

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab        # keep it off after reboot
```

**Load kernel modules and enable forwarding**, so pod traffic can cross the node's bridge and be routed:

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
```

**Behind a corporate proxy?** Set `http_proxy`, `https_proxy` and `no_proxy` (in `/etc/environment` and for containerd's systemd service). `no_proxy` must include the node IPs, the pod and service CIDRs, and the API server address, or nodes will try to reach each other through the proxy.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-prep-q1", "type": "mcq",
    "prompt": "Why does kubeadm's preflight check complain when swap is enabled?",
    "options": [
      {"id": "a", "text": "Swap makes the disk too slow for etcd"},
      {"id": "b", "text": "By default the kubelet requires swap off, because swapping makes memory requests and limits unreliable"},
      {"id": "c", "text": "Swap is needed only on Windows"},
      {"id": "d", "text": "Swap conflicts with Calico"}
    ],
    "correct": "b",
    "explanation": "Kubernetes' memory accounting assumes no swap unless swap support is explicitly configured." }
] }
```

## Step 2: install the container runtime (containerd)

On all nodes:

```bash
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
# IMPORTANT: use the systemd cgroup driver, the same one the kubelet uses
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

The `SystemdCgroup = true` line matters. If containerd and the kubelet use different cgroup drivers, pods restart randomly and the control plane becomes unstable. It is one of the most common broken-cluster causes.

**Docker as the runtime?** Kubernetes removed its built-in Docker support ("dockershim") in 1.24. You can still build images with Docker, and those images run fine on containerd. To keep Docker Engine as the runtime you would need the extra `cri-dockerd` adapter, which new clusters rarely use.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-runtime-q1", "type": "mcq",
    "prompt": "After Kubernetes removed dockershim, can images built with `docker build` still run on a containerd-based cluster?",
    "options": [
      {"id": "a", "text": "No, they must be rebuilt with containerd"},
      {"id": "b", "text": "Yes, they are standard OCI images that any runtime can run"},
      {"id": "c", "text": "Only on Windows nodes"},
      {"id": "d", "text": "Only if Docker is also installed on every node"}
    ],
    "correct": "b",
    "explanation": "Docker builds OCI-compliant images. Removing dockershim only changed which runtime starts containers on nodes." }
] }
```

## Step 3: install kubeadm, kubelet and kubectl

On all nodes. Packages come from the community repository `pkgs.k8s.io`, which has one repository per minor version. (The old `apt.kubernetes.io` repository is frozen; guides that still use it no longer work.) Replace `v1.33` with the version you want:

```bash
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl     # never upgrade these by accident with apt upgrade
sudo systemctl enable --now kubelet
```

- **kubeadm** bootstraps the cluster.
- **kubelet** is the node agent. It restarts in a loop until kubeadm configures it; that is expected.
- **kubectl** is the client. It is only really needed where you run commands.

`apt-mark hold` matters: Kubernetes upgrades follow a specific order (next lesson), and a random `apt upgrade` must not jump versions.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-install-q1", "type": "mcq",
    "prompt": "Why run `apt-mark hold kubelet kubeadm kubectl`?",
    "options": [
      {"id": "a", "text": "To make them start faster"},
      {"id": "b", "text": "So routine OS updates cannot upgrade Kubernetes components out of the planned upgrade order"},
      {"id": "c", "text": "It is required by Calico"},
      {"id": "d", "text": "To hide them from other users"}
    ],
    "correct": "b",
    "explanation": "Kubernetes must be upgraded deliberately (control plane first, one minor version at a time)." }
] }
```

## Step 4: create the control plane

On the **control-plane node** only:

```bash
sudo kubeadm config images pull
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=<MASTER_IP> \
  --control-plane-endpoint=<MASTER_IP>
```

- `--pod-network-cidr` is the IP range for pods. It must match the network plugin's setting and must not overlap your real network. (`192.168.0.0/16` is Calico's default; if your LAN already uses 192.168.x.x, choose e.g. `10.244.0.0/16` and configure Calico to match.)
- `--control-plane-endpoint` should be a stable address. For a highly available cluster it is a load balancer or DNS name in front of several control-plane nodes.

kubeadm generates certificates, writes static pod manifests for etcd, kube-apiserver, kube-controller-manager and kube-scheduler (in `/etc/kubernetes/manifests`, run by the kubelet), and prints two important things: how to set up kubectl, and a **join command**.

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes          # the master is NotReady: no network plugin yet
```

`admin.conf` is a full cluster-admin credential. Treat it like a root password.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-init-q1", "type": "mcq",
    "prompt": "Right after `kubeadm init`, the control-plane node shows NotReady. What is usually missing?",
    "options": [
      {"id": "a", "text": "A worker node"},
      {"id": "b", "text": "A CNI network plugin such as Calico or Flannel"},
      {"id": "c", "text": "A Helm installation"},
      {"id": "d", "text": "An Ingress controller"}
    ],
    "correct": "b",
    "explanation": "Nodes stay NotReady until a network plugin is installed and pods can get IPs." },
  { "id": "k8s-kubeadm-init-q2", "type": "mcq",
    "prompt": "How do the control-plane components run on a kubeadm cluster?",
    "options": [
      {"id": "a", "text": "As systemd services installed by apt"},
      {"id": "b", "text": "As static pods, defined by files in /etc/kubernetes/manifests and started by the kubelet"},
      {"id": "c", "text": "As a Deployment in the default namespace"},
      {"id": "d", "text": "Inside the Calico pods"}
    ],
    "correct": "b",
    "explanation": "kubeadm writes static pod manifests; the kubelet runs them directly. You see them in kube-system as mirror pods." }
] }
```

## Step 5: install the network plugin (CNI)

Pods cannot talk to each other until a **CNI plugin** is installed. Calico (which also supports NetworkPolicy):

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml
watch kubectl get pods -n calico-system      # wait until all Running
kubectl get nodes                            # now Ready
```

Other common choices: **Cilium** (eBPF-based, strong NetworkPolicy and observability) and **Flannel** (simple, but no NetworkPolicy). Check the plugin's docs for the current version. Its manifest URLs change between releases.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-cni-q1", "type": "mcq",
    "prompt": "You need NetworkPolicy enforcement. Which CNI choice would NOT give you that on its own?",
    "options": [
      {"id": "a", "text": "Calico"},
      {"id": "b", "text": "Cilium"},
      {"id": "c", "text": "Flannel"},
      {"id": "d", "text": "All of them enforce it"}
    ],
    "correct": "c",
    "explanation": "Plain Flannel only provides connectivity. NetworkPolicy objects are accepted but not enforced." }
] }
```

## Step 6: join worker nodes

Think of this join command as a guest Wi-Fi password: it lets a new device onto the network, but it expires after a day so it cannot be reused by just anyone who once saw it. On each **worker**, run the join command that `kubeadm init` printed:

```bash
sudo kubeadm join <MASTER_IP>:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

Tokens expire after **24 hours**. To join a node later, create a fresh command on the control plane:

```bash
kubeadm token create --print-join-command
kubeadm token list
```

(If you ever need the CA hash by hand: `openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'`.)

Add `--control-plane --certificate-key <key>` to join an additional **control-plane** node for high availability. Run an **odd number** of control-plane nodes (3 or 5) so etcd keeps a majority (quorum) when one fails.

```bash
kubectl get nodes -o wide        # all nodes Ready
kubectl label node worker1 node-role.kubernetes.io/worker=     # optional: show a ROLE
```

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-join-q1", "type": "mcq",
    "prompt": "A week after setting up the cluster you want to add a worker, but the original join token no longer works. What do you do?",
    "options": [
      {"id": "a", "text": "Reinstall the cluster"},
      {"id": "b", "text": "Run `kubeadm token create --print-join-command` on the control plane and use the new command"},
      {"id": "c", "text": "Copy admin.conf to the worker"},
      {"id": "d", "text": "Restart the kubelet on the master"}
    ],
    "correct": "b",
    "explanation": "Bootstrap tokens expire (24h by default). Creating a new one prints a ready-to-use join command." },
  { "id": "k8s-kubeadm-join-q2", "type": "mcq",
    "prompt": "Why run 3 control-plane nodes instead of 2?",
    "options": [
      {"id": "a", "text": "etcd needs a majority; with 3 members one can fail and 2 still form a majority, with 2 members losing one stops the cluster"},
      {"id": "b", "text": "kubeadm refuses even numbers"},
      {"id": "c", "text": "The scheduler needs three copies"},
      {"id": "d", "text": "It doubles the pod capacity"}
    ],
    "correct": "a",
    "explanation": "etcd quorum is floor(n/2)+1. Two members tolerate zero failures, three tolerate one, five tolerate two." }
] }
```

## Private registries, NFS storage and Windows nodes

**Private image registry.** Real clusters pull company images from a private registry (Harbor, GitLab, ECR, ACR, GCR). The clean way is a registry with a proper TLS certificate plus an `imagePullSecrets` credential (Secrets lesson). For a quick lab registry you can run one yourself:

```bash
docker run -d -p 5000:5000 --restart always --name localregistry registry:2
docker tag myapp:1.0 <MASTER_IP>:5000/myapp:1.0
docker push <MASTER_IP>:5000/myapp:1.0
```

A registry without TLS must be explicitly trusted by containerd on every node (in `/etc/containerd/certs.d/<host:port>/hosts.toml`, then restart containerd). Only do this in labs; in production always use TLS.

**NFS for PersistentVolumes.** On-premises clusters often use an NFS server for shared (RWX) storage. Install `nfs-common` on every node, then either create NFS PVs by hand (Storage lesson) or install the **csi-driver-nfs** (or nfs-subdir-external-provisioner) chart so PVCs get NFS volumes automatically through a StorageClass.

**Windows worker nodes.** Kubernetes can schedule Windows containers on Windows Server 2019/2022 worker nodes. The control plane is always Linux. Windows nodes use containerd, need a CNI that supports Windows (Calico, Flannel with host-gw/VXLAN), and need a `nodeSelector: kubernetes.io/os: windows` on Windows pods, so that Linux pods never land there and vice versa.

**Control-plane IP changed?** kubeadm bakes the API server address into certificates and kubeconfigs. Give control-plane nodes **static IPs or a DNS name** from day one. If the IP does change in a lab, the quick (destructive) fix is `sudo kubeadm reset` on every node, `kubeadm init` again, reinstall the CNI, and re-join the workers.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-extra-q1", "type": "mcq",
    "prompt": "A mixed cluster has Linux and Windows workers. How do you make sure a Windows container image is only scheduled on Windows nodes?",
    "options": [
      {"id": "a", "text": "It happens automatically for every image"},
      {"id": "b", "text": "Add nodeSelector kubernetes.io/os: windows to the pod spec"},
      {"id": "c", "text": "Run it as a DaemonSet"},
      {"id": "d", "text": "Put it in the kube-system namespace"}
    ],
    "correct": "b",
    "explanation": "Every node carries the kubernetes.io/os label. Selecting it keeps pods on nodes with the matching OS." }
] }
```

## Interview questions and real-world scenarios

**Q: Walk me through creating a cluster with kubeadm.**
Prepare nodes (swap off, kernel modules, sysctl), install containerd with SystemdCgroup, install kubeadm/kubelet/kubectl from pkgs.k8s.io and hold them, `kubeadm init` on the control plane, set up kubeconfig, install a CNI, `kubeadm join` the workers.

**Q: What does kubeadm init actually create?**
Certificates (PKI), kubeconfigs, static pod manifests for etcd and the control plane, the kubelet config, CoreDNS and kube-proxy add-ons, and a bootstrap token for joins.

**Q: Why did Kubernetes remove dockershim, and what changed for users?**
Kubernetes talks to runtimes through CRI; Docker Engine didn't implement CRI, so a shim had to be maintained. Clusters now use containerd or CRI-O directly. Images built with Docker still work unchanged.

**Q: How do you make the control plane highly available?**
3 (or 5) control-plane nodes behind a load balancer (`--control-plane-endpoint`), with stacked or external etcd. Odd member count for quorum.

**Q: Managed vs self-managed Kubernetes?**
Managed removes control-plane operations (etcd, upgrades, HA) at a small cost; self-managed gives full control and suits on-prem, edge or air-gapped setups.

**Real-world scenario: pods on a new kubeadm cluster restart randomly every few minutes.**
Classic cgroup-driver mismatch: containerd was left with `SystemdCgroup = false`. Fix the config on every node and restart containerd and the kubelet.

**Real-world scenario: a new node joins but stays NotReady.**
Check `journalctl -u kubelet`. Usual causes: no CNI pods on that node (check the CNI DaemonSet), firewall blocking required ports (6443, 10250, CNI ports), or swap still on.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-kubeadm-int-q1",
      "type": "mcq",
      "prompt": "A freshly built kubeadm cluster has pods restarting randomly and etcd complaining. What should you check first?",
      "options": [
        {
          "id": "a",
          "text": "The Helm version"
        },
        {
          "id": "b",
          "text": "That containerd uses SystemdCgroup = true, matching the kubelet's cgroup driver"
        },
        {
          "id": "c",
          "text": "The Ingress class"
        },
        {
          "id": "d",
          "text": "The HPA settings"
        }
      ],
      "correct": "b",
      "explanation": "A cgroup driver mismatch is the classic cause of this instability."
    }
  ]
}
```
$md$, 50, $json$[{"id":"k8s-kubeadm-choice-q1","type":"mcq","correct":"b"},{"id":"k8s-kubeadm-prep-q1","type":"mcq","correct":"b"},{"id":"k8s-kubeadm-runtime-q1","type":"mcq","correct":"b"},{"id":"k8s-kubeadm-install-q1","type":"mcq","correct":"b"},{"id":"k8s-kubeadm-init-q1","type":"mcq","correct":"b"},{"id":"k8s-kubeadm-init-q2","type":"mcq","correct":"b"},{"id":"k8s-kubeadm-cni-q1","type":"mcq","correct":"c"},{"id":"k8s-kubeadm-join-q1","type":"mcq","correct":"b"},{"id":"k8s-kubeadm-join-q2","type":"mcq","correct":"a"},{"id":"k8s-kubeadm-extra-q1","type":"mcq","correct":"b"},{"id":"k8s-kubeadm-int-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('d9affb68-e253-5271-b35e-3c0b8488c4b0', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'a6a3c179-127f-5a21-b823-1ddb520e36eb', 'Security with RBAC, ServiceAccounts and Pod Security', 'notes', 1, $md$A cluster runs many teams' apps and holds their secrets, so access must be controlled carefully. This lesson covers the three security basics everyone working with Kubernetes needs: **who can do what** (authentication and RBAC), **what identity pods use** (ServiceAccounts), and **what pods are allowed to do on the node** (security contexts and Pod Security Standards).

## Authentication vs authorization

Every request to the API server goes through two checks, then admission:

1. **Authentication: who are you?** Kubernetes has no user database. People are identified by client certificates, tokens, or (most commonly in companies) an **OIDC** identity provider such as Azure AD/Entra ID, Google, Okta or Keycloak. Programs use **ServiceAccount** tokens.
2. **Authorization: are you allowed to do this?** Almost every cluster uses **RBAC** (role-based access control).
3. **Admission: is this object acceptable?** Admission controllers can reject or modify objects (for example Pod Security Admission, or policy engines such as Kyverno and OPA Gatekeeper).

```knowledge-check
{ "questions": [
  { "id": "k8s-sec-authn-q1", "type": "mcq",
    "prompt": "Where does Kubernetes store its list of human users?",
    "options": [
      {"id": "a", "text": "In etcd under /users"},
      {"id": "b", "text": "Nowhere; users come from external identity (certificates, tokens, OIDC), and only ServiceAccounts are Kubernetes objects"},
      {"id": "c", "text": "In a ConfigMap in kube-system"},
      {"id": "d", "text": "In the kubelet"}
    ],
    "correct": "b",
    "explanation": "Kubernetes trusts external identity for people. ServiceAccounts are the only identities it manages itself." }
] }
```

## RBAC: Roles and bindings

Think of an office ID card system. A **Role** is like the printed list of doors a certain type of card can open (server room, accounts, cafeteria). Giving that actual card to a person is the **RoleBinding**. The card only works in this one office building; a **ClusterRole** and **ClusterRoleBinding** are the same idea for a card that works across every branch office. RBAC has four object kinds:

| Object | Scope | Purpose |
|---|---|---|
| **Role** | One namespace | A set of permissions (verbs on resources) |
| **ClusterRole** | Whole cluster | Same, for cluster-wide resources (nodes, PVs) or for reuse in many namespaces |
| **RoleBinding** | One namespace | Gives a Role (or a ClusterRole) to subjects **in that namespace** |
| **ClusterRoleBinding** | Whole cluster | Gives a ClusterRole to subjects **everywhere** |

A Role:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: team-a
rules:
- apiGroups: [""]              # "" = core group (pods, services, configmaps, secrets)
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
```

Give it to a user, a group and a ServiceAccount:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: team-a
subjects:
- kind: User
  name: jane@mindforge.test
- kind: Group
  name: team-a-devs
- kind: ServiceAccount
  name: ci-bot
  namespace: team-a
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Rules to remember:

- RBAC is **additive only**: there is no "deny" rule. Anything not granted is forbidden.
- Follow **least privilege**. Avoid giving `cluster-admin`, and be careful with `*` verbs, `secrets` access, and `pods/exec` (which lets someone run commands inside containers).
- Built-in ClusterRoles `view`, `edit`, `admin` and `cluster-admin` cover common needs. Bind `edit` in a namespace with a RoleBinding to give a team full control of their own namespace only.

Test permissions with `can-i`:

```bash
kubectl auth can-i create deployments -n team-a
kubectl auth can-i delete pods -n team-a --as=jane@mindforge.test
kubectl auth can-i --list -n team-a --as=system:serviceaccount:team-a:ci-bot
```

[[lab-task:1]]

[[lab-task:2]]

[[lab-task:3]]

```knowledge-check
{ "questions": [
  { "id": "k8s-sec-rbac-q1", "type": "mcq",
    "prompt": "You bind the built-in ClusterRole `edit` to a team using a RoleBinding in namespace `team-a`. Where can the team edit objects?",
    "options": [
      {"id": "a", "text": "In every namespace"},
      {"id": "b", "text": "Only in team-a"},
      {"id": "c", "text": "Nowhere; a ClusterRole needs a ClusterRoleBinding"},
      {"id": "d", "text": "Only on cluster-wide resources"}
    ],
    "correct": "b",
    "explanation": "A RoleBinding limits the granted permissions to its own namespace, even when it references a ClusterRole." },
  { "id": "k8s-sec-rbac-q2", "type": "mcq",
    "prompt": "How do you forbid a user from deleting Secrets in RBAC?",
    "options": [
      {"id": "a", "text": "Add a rule with verb deny"},
      {"id": "b", "text": "Simply do not grant that permission in any Role or ClusterRole bound to them"},
      {"id": "c", "text": "Add a negative RoleBinding"},
      {"id": "d", "text": "Label the Secret protected=true"}
    ],
    "correct": "b",
    "explanation": "RBAC only grants. Everything not granted is denied by default." }
] }
```

## ServiceAccounts: identities for pods

Every pod runs as a **ServiceAccount** (the `default` one in its namespace unless you set `serviceAccountName`). Its token is mounted into the pod at `/var/run/secrets/kubernetes.io/serviceaccount/`, so code inside the pod can call the Kubernetes API with that identity. Tools such as CI runners, operators and Argo CD use this.

```yaml
spec:
  serviceAccountName: ci-bot
  automountServiceAccountToken: true    # set false for pods that never call the API
```

Good practice:

- Create one ServiceAccount per app that needs API access, and bind only the permissions it needs.
- Set `automountServiceAccountToken: false` for apps that never talk to the Kubernetes API. That way a stolen token cannot be misused.
- Tokens are short-lived and rotated automatically (projected tokens). Get one for testing with `kubectl create token ci-bot -n team-a`.
- On clouds, ServiceAccounts can be mapped to cloud IAM roles (IRSA / EKS Pod Identity on AWS, Workload Identity on GKE/AKS), so pods get cloud permissions without stored keys.

```knowledge-check
{ "questions": [
  { "id": "k8s-sec-sa-q1", "type": "mcq",
    "prompt": "Which identity does a pod use to call the Kubernetes API if you don't specify one?",
    "options": [
      {"id": "a", "text": "cluster-admin"},
      {"id": "b", "text": "The `default` ServiceAccount of its namespace"},
      {"id": "c", "text": "The user who created the pod"},
      {"id": "d", "text": "It cannot call the API"}
    ],
    "correct": "b",
    "explanation": "Pods default to the namespace's `default` ServiceAccount, which has no extra permissions unless someone binds them." }
] }
```

## Security context: what a container may do

By default many images run as **root**. If an attacker breaks into such a container, they are root inside it, which makes escaping to the node easier. `securityContext` tightens this:

```yaml
spec:
  securityContext:                 # pod level
    runAsNonRoot: true             # refuse to start if the image would run as root
    runAsUser: 1000
    fsGroup: 2000                  # group owner for mounted volumes
    seccompProfile:
      type: RuntimeDefault         # block dangerous system calls
  containers:
  - name: app
    image: myapp:1.0
    securityContext:               # container level
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true # app can only write to mounted volumes
      capabilities:
        drop: ["ALL"]              # remove all special kernel powers
```

Never use `privileged: true`, `hostNetwork`, `hostPID` or broad `hostPath` mounts for normal apps. They remove most of the isolation between the container and the node.

```knowledge-check
{ "questions": [
  { "id": "k8s-sec-ctx-q1", "type": "mcq",
    "prompt": "What does `readOnlyRootFilesystem: true` do?",
    "options": [
      {"id": "a", "text": "Makes all volumes read-only"},
      {"id": "b", "text": "Prevents the container from writing to its image filesystem; it can still write to mounted volumes such as an emptyDir"},
      {"id": "c", "text": "Makes the image smaller"},
      {"id": "d", "text": "Blocks network access"}
    ],
    "correct": "b",
    "explanation": "Attackers cannot drop tools or change binaries in the image. Give the app an emptyDir for temp files if it needs one." }
] }
```

## Pod Security Standards and admission

Kubernetes defines three **Pod Security Standards**:

- **privileged**: no restrictions (for system components).
- **baseline**: blocks the obviously dangerous settings (privileged, host namespaces...).
- **restricted**: also requires non-root, dropped capabilities, seccomp and no privilege escalation. Best practice for apps.

The built-in **Pod Security Admission** controller enforces them per namespace, using labels:

```bash
kubectl label namespace team-a \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted
```

- `enforce` rejects violating pods.
- `warn` only prints a warning (good for trying a level first).
- `audit` records violations in the audit log.

For rules beyond this (allowed registries, required labels, resource limits present), teams use **Kyverno** or **OPA Gatekeeper**.

[[lab-task:4]]

[[lab-task:5]]

```knowledge-check
{ "questions": [
  { "id": "k8s-sec-psa-q1", "type": "mcq",
    "prompt": "A namespace has pod-security.kubernetes.io/enforce=restricted. A Deployment's pods run as root. What happens?",
    "options": [
      {"id": "a", "text": "The pods run with a warning"},
      {"id": "b", "text": "The pods are rejected, so the ReplicaSet cannot create them"},
      {"id": "c", "text": "Kubernetes changes the user to non-root automatically"},
      {"id": "d", "text": "The whole namespace is deleted"}
    ],
    "correct": "b",
    "explanation": "enforce rejects non-compliant pods. The Deployment is accepted but its ReplicaSet reports FailedCreate events. Use warn mode first to find problems." }
] }
```

## Interview questions and real-world scenarios

**Q: Authentication vs authorization vs admission?**
Who are you (certs, tokens, OIDC)? Are you allowed (RBAC)? Is this object acceptable (admission controllers such as Pod Security, Kyverno, Gatekeeper)?

**Q: Role vs ClusterRole, RoleBinding vs ClusterRoleBinding?**
Namespaced vs cluster-wide permission sets; namespace-scoped vs cluster-wide grants. A RoleBinding can reference a ClusterRole to reuse it inside one namespace.

**Q: How do you give a pod access to a cloud service (for example S3) securely?**
Workload identity: map the pod's ServiceAccount to a cloud IAM role (IRSA / EKS Pod Identity, GKE/AKS Workload Identity) instead of storing access keys in Secrets.

**Q: What would you check in a Kubernetes security review?**
RBAC (no broad cluster-admin, no wildcard verbs, limited secrets/exec access), Pod Security (restricted), NetworkPolicies (default deny), image sources and scanning, secrets management, API server not public, audit logging, up-to-date versions.

**Q: Why is access to `pods/exec` or `create pods` dangerous?**
exec gives a shell inside containers with their secrets. Anyone who can create pods can mount any Secret in the namespace or (without Pod Security) run a privileged pod and take over a node.

**Real-world scenario: a developer needs to debug production.**
Give time-limited, read-only access (`view` role, logs) via SSO groups; for exec, use a just-in-time access process with audit logging, not permanent rights.

**Real-world scenario: after enabling `enforce=restricted`, a Deployment stops creating pods.**
The ReplicaSet shows FailedCreate events listing the violations. Fix the pod's securityContext (non-root, drop capabilities, seccomp); roll out policies with `warn` first to find these before enforcing.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-sec-int-q1",
      "type": "mcq",
      "prompt": "Why is permission to create pods in a namespace close to having access to all Secrets in that namespace?",
      "options": [
        {
          "id": "a",
          "text": "It is not related"
        },
        {
          "id": "b",
          "text": "A new pod can mount or read any Secret in its namespace as a volume or env var"
        },
        {
          "id": "c",
          "text": "Creating pods deletes Secrets"
        },
        {
          "id": "d",
          "text": "Pods are stored inside Secrets"
        }
      ],
      "correct": "b",
      "explanation": "RBAC on Secrets alone is not enough; pod creation rights must be treated as sensitive too."
    }
  ]
}
```
$md$, 45, $json$[{"id":"k8s-sec-authn-q1","type":"mcq","correct":"b"},{"id":"k8s-sec-rbac-q1","type":"mcq","correct":"b"},{"id":"k8s-sec-rbac-q2","type":"mcq","correct":"b"},{"id":"k8s-sec-sa-q1","type":"mcq","correct":"b"},{"id":"k8s-sec-ctx-q1","type":"mcq","correct":"b"},{"id":"k8s-sec-psa-q1","type":"mcq","correct":"b"},{"id":"k8s-sec-int-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('14fbda20-0a6a-5d2e-a64f-4140e0663233', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'd9affb68-e253-5271-b35e-3c0b8488c4b0', 'module', 'Security with RBAC, ServiceAccounts and Pod Security', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '4aba4490-e29d-596d-a00d-9960f99fc705' AND id NOT IN ('3e6c7b67-465b-5a63-947b-835f44555024', '1fe51294-6d24-5e30-ba51-36fbec69ee0d', '309d299d-0181-52a2-946a-b283367b2f0e', 'e56fdc09-c048-555f-9d35-454c7e4794da', '84717b76-028d-5ee2-9ae1-4e5ea1c94a80');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '4aba4490-e29d-596d-a00d-9960f99fc705';
DELETE FROM lab_tasks WHERE lab_id = '14fbda20-0a6a-5d2e-a64f-4140e0663233' AND id NOT IN ('29fc7c14-f92a-5f34-b53d-dfc024079d1c', '31b8135f-e37d-5dbd-8be4-6a5f4d8b7f7a', 'e90259c7-667b-5052-a716-ad2964502db5', '3b281bfe-46f5-5c1c-93a2-6406ed8d4704', '4146f78d-8ae2-5924-9571-b4528f35772f');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '14fbda20-0a6a-5d2e-a64f-4140e0663233';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('29fc7c14-f92a-5f34-b53d-dfc024079d1c', '14fbda20-0a6a-5d2e-a64f-4140e0663233', 1, 'Create a namespace and a ServiceAccount', $md$Create the namespace `team-a` and, inside it, a ServiceAccount named `ci-bot`.$md$, $script$#!/bin/bash
kubectl get serviceaccount ci-bot -n team-a >/dev/null 2>&1
$script$, '`kubectl create namespace ...` then `kubectl create serviceaccount <name> -n <namespace>`', 'A ServiceAccount is an identity for software (a CI pipeline, an operator, a pod), just as a user account is an identity for a person.', 10, false, true),
('31b8135f-e37d-5dbd-8be4-6a5f4d8b7f7a', '14fbda20-0a6a-5d2e-a64f-4140e0663233', 2, 'Create a Role', $md$In `team-a`, create a Role named `deployer` that can `get`, `list`, `watch`, `create`, `update` and `patch` **deployments** (API group `apps`), and only `get`, `list`, `watch` **pods**.$md$, $script$#!/bin/bash
R=$(kubectl get role deployer -n team-a -o jsonpath='{range .rules[*]}{.resources[*]}:{.verbs[*]}{"\n"}{end}')
echo "$R" | grep -q '^deployments:.*create' || exit 1
echo "$R" | grep -q '^deployments:.*patch' || exit 1
P=$(echo "$R" | grep '^pods:') || exit 1
echo "$P" | grep -q list && ! echo "$P" | grep -qE 'create|delete|update|patch'
$script$, 'Two `kubectl create role` rules are easiest in YAML: `rules:` with one entry for `apiGroups: ["apps"]`/`resources: ["deployments"]` and one for `apiGroups: [""]`/`resources: ["pods"]`.', 'Rules list API groups, resources and verbs. Core objects such as pods are in the empty API group "". Anything not listed is denied, because RBAC only grants, never denies.', 15, false, true),
('e90259c7-667b-5052-a716-ad2964502db5', '14fbda20-0a6a-5d2e-a64f-4140e0663233', 3, 'Bind the Role to the ServiceAccount', $md$Create a RoleBinding named `ci-bot-deployer` in `team-a` that gives the Role `deployer` to the ServiceAccount `team-a:ci-bot`.$md$, $script$#!/bin/bash
test "$(kubectl get rolebinding ci-bot-deployer -n team-a -o jsonpath='{.roleRef.kind}/{.roleRef.name} {.subjects[0].kind}/{.subjects[0].namespace}/{.subjects[0].name}')" = "Role/deployer ServiceAccount/team-a/ci-bot"
$script$, '`kubectl create rolebinding <name> --role=<role> --serviceaccount=<namespace>:<sa> -n <namespace>`', 'On a normal cluster you could now check with `kubectl auth can-i create deployments -n team-a --as=system:serviceaccount:team-a:ci-bot` (yes) and `... delete pods ...` (no). This sandbox''s API server runs with authorization turned off, so can-i always answers yes here.', 15, false, true),
('3b281bfe-46f5-5c1c-93a2-6406ed8d4704', '14fbda20-0a6a-5d2e-a64f-4140e0663233', 4, 'Enforce the restricted Pod Security Standard', $md$Label the namespace `team-a` with `pod-security.kubernetes.io/enforce=restricted`. Then try `kubectl run root-pod --image=nginx:1.27 -n team-a` and read the error. The pod is rejected.
$md$, $script$#!/bin/bash
test "$(kubectl get ns team-a -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" = "restricted" || exit 1
! kubectl get pod root-pod -n team-a >/dev/null 2>&1
$script$, '`kubectl label namespace team-a pod-security.kubernetes.io/enforce=restricted`', 'Pod Security Admission checks every new pod in the namespace. A plain nginx pod may run as root, allows privilege escalation and keeps default capabilities, so the restricted level rejects it.', 15, false, true),
('4146f78d-8ae2-5924-9571-b4528f35772f', '14fbda20-0a6a-5d2e-a64f-4140e0663233', 5, 'Write a pod that passes the restricted policy', $md$Create a pod `safe-pod` in `team-a` (image `nginxinc/nginx-unprivileged:1.27`) that is accepted by the restricted policy. It must:
- run as non-root (`runAsNonRoot: true`, `runAsUser: 101`)
- use `seccompProfile.type: RuntimeDefault`
- set `allowPrivilegeEscalation: false`
- drop `ALL` capabilities
$md$, $script$#!/bin/bash
kubectl get pod safe-pod -n team-a >/dev/null 2>&1 || exit 1
test "$(kubectl get pod safe-pod -n team-a -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}')" = "false"
$script$, 'Pod-level `securityContext` takes runAsNonRoot, runAsUser and seccompProfile. The container-level `securityContext` takes allowPrivilegeEscalation and `capabilities: {drop: ["ALL"]}`.', 'These settings mean that even if the app is hacked, the attacker is not root, cannot gain more privileges, and has no special kernel capabilities. They are good defaults for every production pod.', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('4aba4490-e29d-596d-a00d-9960f99fc705', '14fbda20-0a6a-5d2e-a64f-4140e0663233', 1, $json$[{"id":"29fc7c14-f92a-5f34-b53d-dfc024079d1c","lab_id":"14fbda20-0a6a-5d2e-a64f-4140e0663233","position":1,"title":"Create a namespace and a ServiceAccount","description":"Create the namespace `team-a` and, inside it, a ServiceAccount named `ci-bot`.","verification_script":"#!/bin/bash\nkubectl get serviceaccount ci-bot -n team-a \u003e/dev/null 2\u003e\u00261\n","hint_context":"`kubectl create namespace ...` then `kubectl create serviceaccount \u003cname\u003e -n \u003cnamespace\u003e`","explanation_context":"A ServiceAccount is an identity for software (a CI pipeline, an operator, a pod), just as a user account is an identity for a person.","points":10,"is_optional":false,"is_stateful":true},{"id":"31b8135f-e37d-5dbd-8be4-6a5f4d8b7f7a","lab_id":"14fbda20-0a6a-5d2e-a64f-4140e0663233","position":2,"title":"Create a Role","description":"In `team-a`, create a Role named `deployer` that can `get`, `list`, `watch`, `create`, `update` and `patch` **deployments** (API group `apps`), and only `get`, `list`, `watch` **pods**.","verification_script":"#!/bin/bash\nR=$(kubectl get role deployer -n team-a -o jsonpath='{range .rules[*]}{.resources[*]}:{.verbs[*]}{\"\\n\"}{end}')\necho \"$R\" | grep -q '^deployments:.*create' || exit 1\necho \"$R\" | grep -q '^deployments:.*patch' || exit 1\nP=$(echo \"$R\" | grep '^pods:') || exit 1\necho \"$P\" | grep -q list \u0026\u0026 ! echo \"$P\" | grep -qE 'create|delete|update|patch'\n","hint_context":"Two `kubectl create role` rules are easiest in YAML: `rules:` with one entry for `apiGroups: [\"apps\"]`/`resources: [\"deployments\"]` and one for `apiGroups: [\"\"]`/`resources: [\"pods\"]`.","explanation_context":"Rules list API groups, resources and verbs. Core objects such as pods are in the empty API group \"\". Anything not listed is denied, because RBAC only grants, never denies.","points":15,"is_optional":false,"is_stateful":true},{"id":"e90259c7-667b-5052-a716-ad2964502db5","lab_id":"14fbda20-0a6a-5d2e-a64f-4140e0663233","position":3,"title":"Bind the Role to the ServiceAccount","description":"Create a RoleBinding named `ci-bot-deployer` in `team-a` that gives the Role `deployer` to the ServiceAccount `team-a:ci-bot`.","verification_script":"#!/bin/bash\ntest \"$(kubectl get rolebinding ci-bot-deployer -n team-a -o jsonpath='{.roleRef.kind}/{.roleRef.name} {.subjects[0].kind}/{.subjects[0].namespace}/{.subjects[0].name}')\" = \"Role/deployer ServiceAccount/team-a/ci-bot\"\n","hint_context":"`kubectl create rolebinding \u003cname\u003e --role=\u003crole\u003e --serviceaccount=\u003cnamespace\u003e:\u003csa\u003e -n \u003cnamespace\u003e`","explanation_context":"On a normal cluster you could now check with `kubectl auth can-i create deployments -n team-a --as=system:serviceaccount:team-a:ci-bot` (yes) and `... delete pods ...` (no). This sandbox's API server runs with authorization turned off, so can-i always answers yes here.","points":15,"is_optional":false,"is_stateful":true},{"id":"3b281bfe-46f5-5c1c-93a2-6406ed8d4704","lab_id":"14fbda20-0a6a-5d2e-a64f-4140e0663233","position":4,"title":"Enforce the restricted Pod Security Standard","description":"Label the namespace `team-a` with `pod-security.kubernetes.io/enforce=restricted`. Then try `kubectl run root-pod --image=nginx:1.27 -n team-a` and read the error. The pod is rejected.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get ns team-a -o jsonpath='{.metadata.labels.pod-security\\.kubernetes\\.io/enforce}')\" = \"restricted\" || exit 1\n! kubectl get pod root-pod -n team-a \u003e/dev/null 2\u003e\u00261\n","hint_context":"`kubectl label namespace team-a pod-security.kubernetes.io/enforce=restricted`","explanation_context":"Pod Security Admission checks every new pod in the namespace. A plain nginx pod may run as root, allows privilege escalation and keeps default capabilities, so the restricted level rejects it.","points":15,"is_optional":false,"is_stateful":true},{"id":"4146f78d-8ae2-5924-9571-b4528f35772f","lab_id":"14fbda20-0a6a-5d2e-a64f-4140e0663233","position":5,"title":"Write a pod that passes the restricted policy","description":"Create a pod `safe-pod` in `team-a` (image `nginxinc/nginx-unprivileged:1.27`) that is accepted by the restricted policy. It must:\n- run as non-root (`runAsNonRoot: true`, `runAsUser: 101`)\n- use `seccompProfile.type: RuntimeDefault`\n- set `allowPrivilegeEscalation: false`\n- drop `ALL` capabilities\n","verification_script":"#!/bin/bash\nkubectl get pod safe-pod -n team-a \u003e/dev/null 2\u003e\u00261 || exit 1\ntest \"$(kubectl get pod safe-pod -n team-a -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}')\" = \"false\"\n","hint_context":"Pod-level `securityContext` takes runAsNonRoot, runAsUser and seccompProfile. The container-level `securityContext` takes allowPrivilegeEscalation and `capabilities: {drop: [\"ALL\"]}`.","explanation_context":"These settings mean that even if the app is hacked, the attacker is not root, cannot gain more privileges, and has no special kernel capabilities. They are good defaults for every production pod.","points":20,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('3e6c7b67-465b-5a63-947b-835f44555024', '4aba4490-e29d-596d-a00d-9960f99fc705', '29fc7c14-f92a-5f34-b53d-dfc024079d1c', 1, 'Create a namespace and a ServiceAccount', $md$Create the namespace `team-a` and, inside it, a ServiceAccount named `ci-bot`.$md$, $script$#!/bin/bash
kubectl get serviceaccount ci-bot -n team-a >/dev/null 2>&1
$script$, '`kubectl create namespace ...` then `kubectl create serviceaccount <name> -n <namespace>`', 'A ServiceAccount is an identity for software (a CI pipeline, an operator, a pod), just as a user account is an identity for a person.', 10, false, true),
('1fe51294-6d24-5e30-ba51-36fbec69ee0d', '4aba4490-e29d-596d-a00d-9960f99fc705', '31b8135f-e37d-5dbd-8be4-6a5f4d8b7f7a', 2, 'Create a Role', $md$In `team-a`, create a Role named `deployer` that can `get`, `list`, `watch`, `create`, `update` and `patch` **deployments** (API group `apps`), and only `get`, `list`, `watch` **pods**.$md$, $script$#!/bin/bash
R=$(kubectl get role deployer -n team-a -o jsonpath='{range .rules[*]}{.resources[*]}:{.verbs[*]}{"\n"}{end}')
echo "$R" | grep -q '^deployments:.*create' || exit 1
echo "$R" | grep -q '^deployments:.*patch' || exit 1
P=$(echo "$R" | grep '^pods:') || exit 1
echo "$P" | grep -q list && ! echo "$P" | grep -qE 'create|delete|update|patch'
$script$, 'Two `kubectl create role` rules are easiest in YAML: `rules:` with one entry for `apiGroups: ["apps"]`/`resources: ["deployments"]` and one for `apiGroups: [""]`/`resources: ["pods"]`.', 'Rules list API groups, resources and verbs. Core objects such as pods are in the empty API group "". Anything not listed is denied, because RBAC only grants, never denies.', 15, false, true),
('309d299d-0181-52a2-946a-b283367b2f0e', '4aba4490-e29d-596d-a00d-9960f99fc705', 'e90259c7-667b-5052-a716-ad2964502db5', 3, 'Bind the Role to the ServiceAccount', $md$Create a RoleBinding named `ci-bot-deployer` in `team-a` that gives the Role `deployer` to the ServiceAccount `team-a:ci-bot`.$md$, $script$#!/bin/bash
test "$(kubectl get rolebinding ci-bot-deployer -n team-a -o jsonpath='{.roleRef.kind}/{.roleRef.name} {.subjects[0].kind}/{.subjects[0].namespace}/{.subjects[0].name}')" = "Role/deployer ServiceAccount/team-a/ci-bot"
$script$, '`kubectl create rolebinding <name> --role=<role> --serviceaccount=<namespace>:<sa> -n <namespace>`', 'On a normal cluster you could now check with `kubectl auth can-i create deployments -n team-a --as=system:serviceaccount:team-a:ci-bot` (yes) and `... delete pods ...` (no). This sandbox''s API server runs with authorization turned off, so can-i always answers yes here.', 15, false, true),
('e56fdc09-c048-555f-9d35-454c7e4794da', '4aba4490-e29d-596d-a00d-9960f99fc705', '3b281bfe-46f5-5c1c-93a2-6406ed8d4704', 4, 'Enforce the restricted Pod Security Standard', $md$Label the namespace `team-a` with `pod-security.kubernetes.io/enforce=restricted`. Then try `kubectl run root-pod --image=nginx:1.27 -n team-a` and read the error. The pod is rejected.
$md$, $script$#!/bin/bash
test "$(kubectl get ns team-a -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" = "restricted" || exit 1
! kubectl get pod root-pod -n team-a >/dev/null 2>&1
$script$, '`kubectl label namespace team-a pod-security.kubernetes.io/enforce=restricted`', 'Pod Security Admission checks every new pod in the namespace. A plain nginx pod may run as root, allows privilege escalation and keeps default capabilities, so the restricted level rejects it.', 15, false, true),
('84717b76-028d-5ee2-9ae1-4e5ea1c94a80', '4aba4490-e29d-596d-a00d-9960f99fc705', '4146f78d-8ae2-5924-9571-b4528f35772f', 5, 'Write a pod that passes the restricted policy', $md$Create a pod `safe-pod` in `team-a` (image `nginxinc/nginx-unprivileged:1.27`) that is accepted by the restricted policy. It must:
- run as non-root (`runAsNonRoot: true`, `runAsUser: 101`)
- use `seccompProfile.type: RuntimeDefault`
- set `allowPrivilegeEscalation: false`
- drop `ALL` capabilities
$md$, $script$#!/bin/bash
kubectl get pod safe-pod -n team-a >/dev/null 2>&1 || exit 1
test "$(kubectl get pod safe-pod -n team-a -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}')" = "false"
$script$, 'Pod-level `securityContext` takes runAsNonRoot, runAsUser and seccompProfile. The container-level `securityContext` takes allowPrivilegeEscalation and `capabilities: {drop: ["ALL"]}`.', 'These settings mean that even if the app is hacked, the attacker is not root, cannot gain more privileges, and has no special kernel capabilities. They are good defaults for every production pod.', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '4aba4490-e29d-596d-a00d-9960f99fc705', updated_at = now()
WHERE id = '14fbda20-0a6a-5d2e-a64f-4140e0663233' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('c1e1534c-188f-5750-a204-686ad4001fe4', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'a6a3c179-127f-5a21-b823-1ddb520e36eb', 'Day-2 Operations: Maintenance, Upgrades and Backups', 'notes', 2, $md$"Day 1" is building the cluster. "Day 2" is everything after that: patching nodes without downtime, upgrading Kubernetes, backing up, renewing certificates and removing machines. These are the tasks that decide whether production stays up, and they come up often in interviews for DevOps and SRE roles.

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
$md$, 45, $json$[{"id":"k8s-day2-drain-q1","type":"mcq","correct":"b"},{"id":"k8s-day2-drain-q2","type":"mcq","correct":"b"},{"id":"k8s-day2-pdb-q1","type":"mcq","correct":"b"},{"id":"k8s-day2-remove-q1","type":"mcq","correct":"b"},{"id":"k8s-day2-upgrade-q1","type":"mcq","correct":"b"},{"id":"k8s-day2-backup-q1","type":"mcq","correct":"b"},{"id":"k8s-day2-backup-q2","type":"mcq","correct":"b"},{"id":"k8s-day2-int-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('612bc750-1403-592d-b53b-bbab3900bf52', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c1e1534c-188f-5750-a204-686ad4001fe4', 'module', 'Day-2 Operations: Maintenance, Upgrades and Backups', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/node2.yaml <<'MFEOF'
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

MFEOF
chmod 666 /home/labuser/work/node2.yaml
cat > /home/labuser/work/web.yaml <<'MFEOF'
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

MFEOF
chmod 666 /home/labuser/work/web.yaml
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, NULL, 45, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '38246ef5-1088-508a-b562-6bf4f364a2ce' AND id NOT IN ('3a06d138-ef7c-5163-ad8b-0cdbbf138e6f', '3b8954dc-302e-50a0-a8d4-013f67ed3647', '35449922-41be-5b42-9768-62ad760289ca', 'ad839936-f59a-570e-bc9e-0655e4b55637', 'b2d4c085-4de2-5115-b76c-aeafe3156dd6', '72053d1b-b9fd-5c93-9a52-8768ddf815d5');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '38246ef5-1088-508a-b562-6bf4f364a2ce';
DELETE FROM lab_tasks WHERE lab_id = '612bc750-1403-592d-b53b-bbab3900bf52' AND id NOT IN ('dd8d776a-58f7-54a0-8c8f-7a26f1bab503', '72aea050-94b3-5d20-a4ea-3329b46c3504', 'df0fec6f-07c6-55c4-a324-d1fed1c2ea0f', '2ef5ff28-94dc-5ea3-a9fc-0b3559f9e507', 'f35d63b7-fca1-5c4f-b23e-4f5a0d94f677', '61debc9c-171f-508d-8700-91379dcaeae9');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '612bc750-1403-592d-b53b-bbab3900bf52';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('dd8d776a-58f7-54a0-8c8f-7a26f1bab503', '612bc750-1403-592d-b53b-bbab3900bf52', 1, 'Run an app across two nodes', $md$Register a second node (`kubectl apply -f node2.yaml`), then apply `web.yaml`. Check with `kubectl get pods -o wide` that the 4 pods are spread over both nodes.$md$, $script$#!/bin/bash
test "$(kubectl get deploy web -o jsonpath='{.status.readyReplicas}')" = "4" || exit 1
kubectl get pods -l app=web -o jsonpath='{.items[*].spec.nodeName}' | grep -q node2
$script$, 'Apply node2.yaml first, wait until `kubectl get nodes` shows it Ready, then apply web.yaml.', 'The topologySpreadConstraint asked the scheduler to keep the pod count per node within 1, so the pods landed 2 and 2.', 10, false, true),
('72aea050-94b3-5d20-a4ea-3329b46c3504', '612bc750-1403-592d-b53b-bbab3900bf52', 2, 'Protect the app with a PodDisruptionBudget', $md$Create a PodDisruptionBudget named `web-pdb` that keeps at least **3** pods with label `app=web` available during voluntary disruptions like a drain.$md$, $script$#!/bin/bash
test "$(kubectl get pdb web-pdb -o jsonpath='{.spec.minAvailable} {.spec.selector.matchLabels.app}')" = "3 web"
$script$, '`kubectl create pdb <name> --selector=app=web --min-available=3`', 'A drain evicts pods through the Eviction API, which respects PDBs. It will never take the app below 3 available pods at once.', 15, false, true),
('df0fec6f-07c6-55c4-a324-d1fed1c2ea0f', '612bc750-1403-592d-b53b-bbab3900bf52', 3, 'Cordon a node', $md$Mark `node2` as unschedulable so no new pods go there. Look at `kubectl get nodes`.$md$, $script$#!/bin/bash
test "$(kubectl get node node2 -o jsonpath='{.spec.unschedulable}')" = "true"
$script$, '`kubectl cordon <node>`', 'The node now shows SchedulingDisabled. Pods already running there are not touched. Cordon only stops new placements.', 10, false, true),
('2ef5ff28-94dc-5ea3-a9fc-0b3559f9e507', '612bc750-1403-592d-b53b-bbab3900bf52', 4, 'Drain the node for maintenance', $md$Drain `node2` so all `web` pods move to `kwok-node`. Then check `kubectl get pods -o wide`.$md$, $script$#!/bin/bash
! kubectl get pods -l app=web -o jsonpath='{.items[*].spec.nodeName}' | grep -q node2 || exit 1
test "$(kubectl get deploy web -o jsonpath='{.status.readyReplicas}')" = "4"
$script$, '`kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`', 'drain cordons the node and evicts its pods (respecting the PDB). The Deployment recreated them on kwok-node. The node is now safe to patch or reboot.', 20, false, true),
('f35d63b7-fca1-5c4f-b23e-4f5a0d94f677', '612bc750-1403-592d-b53b-bbab3900bf52', 5, 'Bring the node back', $md$Maintenance is done. Make `node2` schedulable again. (Existing pods do not move back on their own; new pods can use it again.)$md$, $script$#!/bin/bash
test -z "$(kubectl get node node2 -o jsonpath='{.spec.unschedulable}')"
$script$, '`kubectl uncordon <node>`', 'uncordon removes the unschedulable flag. The scheduler does not rebalance running pods; a rollout restart or future scaling spreads them again.', 10, false, false),
('61debc9c-171f-508d-8700-91379dcaeae9', '612bc750-1403-592d-b53b-bbab3900bf52', 6, 'Back up etcd', $md$This sandbox's etcd listens on `http://127.0.0.1:2379` without TLS. Save a snapshot to `~/work/etcd-backup.db` with `etcdctl snapshot save`, then check it with `etcdctl --write-out=table snapshot status ~/work/etcd-backup.db`.
$md$, $script$#!/bin/bash
f=/home/labuser/work/etcd-backup.db
test -s "$f" && ETCDCTL_API=3 etcdctl snapshot status "$f" >/dev/null 2>&1
$script$, '`ETCDCTL_API=3 etcdctl --endpoints=http://127.0.0.1:2379 snapshot save <file>`. On a kubeadm cluster you would also pass --cacert, --cert and --key from /etc/kubernetes/pki/etcd/.', 'The snapshot contains every object in the cluster. Store it off the cluster, on a schedule. Restoring it (etcdutl snapshot restore) brings the whole cluster state back.', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('38246ef5-1088-508a-b562-6bf4f364a2ce', '612bc750-1403-592d-b53b-bbab3900bf52', 1, $json$[{"id":"dd8d776a-58f7-54a0-8c8f-7a26f1bab503","lab_id":"612bc750-1403-592d-b53b-bbab3900bf52","position":1,"title":"Run an app across two nodes","description":"Register a second node (`kubectl apply -f node2.yaml`), then apply `web.yaml`. Check with `kubectl get pods -o wide` that the 4 pods are spread over both nodes.","verification_script":"#!/bin/bash\ntest \"$(kubectl get deploy web -o jsonpath='{.status.readyReplicas}')\" = \"4\" || exit 1\nkubectl get pods -l app=web -o jsonpath='{.items[*].spec.nodeName}' | grep -q node2\n","hint_context":"Apply node2.yaml first, wait until `kubectl get nodes` shows it Ready, then apply web.yaml.","explanation_context":"The topologySpreadConstraint asked the scheduler to keep the pod count per node within 1, so the pods landed 2 and 2.","points":10,"is_optional":false,"is_stateful":true},{"id":"72aea050-94b3-5d20-a4ea-3329b46c3504","lab_id":"612bc750-1403-592d-b53b-bbab3900bf52","position":2,"title":"Protect the app with a PodDisruptionBudget","description":"Create a PodDisruptionBudget named `web-pdb` that keeps at least **3** pods with label `app=web` available during voluntary disruptions like a drain.","verification_script":"#!/bin/bash\ntest \"$(kubectl get pdb web-pdb -o jsonpath='{.spec.minAvailable} {.spec.selector.matchLabels.app}')\" = \"3 web\"\n","hint_context":"`kubectl create pdb \u003cname\u003e --selector=app=web --min-available=3`","explanation_context":"A drain evicts pods through the Eviction API, which respects PDBs. It will never take the app below 3 available pods at once.","points":15,"is_optional":false,"is_stateful":true},{"id":"df0fec6f-07c6-55c4-a324-d1fed1c2ea0f","lab_id":"612bc750-1403-592d-b53b-bbab3900bf52","position":3,"title":"Cordon a node","description":"Mark `node2` as unschedulable so no new pods go there. Look at `kubectl get nodes`.","verification_script":"#!/bin/bash\ntest \"$(kubectl get node node2 -o jsonpath='{.spec.unschedulable}')\" = \"true\"\n","hint_context":"`kubectl cordon \u003cnode\u003e`","explanation_context":"The node now shows SchedulingDisabled. Pods already running there are not touched. Cordon only stops new placements.","points":10,"is_optional":false,"is_stateful":true},{"id":"2ef5ff28-94dc-5ea3-a9fc-0b3559f9e507","lab_id":"612bc750-1403-592d-b53b-bbab3900bf52","position":4,"title":"Drain the node for maintenance","description":"Drain `node2` so all `web` pods move to `kwok-node`. Then check `kubectl get pods -o wide`.","verification_script":"#!/bin/bash\n! kubectl get pods -l app=web -o jsonpath='{.items[*].spec.nodeName}' | grep -q node2 || exit 1\ntest \"$(kubectl get deploy web -o jsonpath='{.status.readyReplicas}')\" = \"4\"\n","hint_context":"`kubectl drain \u003cnode\u003e --ignore-daemonsets --delete-emptydir-data`","explanation_context":"drain cordons the node and evicts its pods (respecting the PDB). The Deployment recreated them on kwok-node. The node is now safe to patch or reboot.","points":20,"is_optional":false,"is_stateful":true},{"id":"f35d63b7-fca1-5c4f-b23e-4f5a0d94f677","lab_id":"612bc750-1403-592d-b53b-bbab3900bf52","position":5,"title":"Bring the node back","description":"Maintenance is done. Make `node2` schedulable again. (Existing pods do not move back on their own; new pods can use it again.)","verification_script":"#!/bin/bash\ntest -z \"$(kubectl get node node2 -o jsonpath='{.spec.unschedulable}')\"\n","hint_context":"`kubectl uncordon \u003cnode\u003e`","explanation_context":"uncordon removes the unschedulable flag. The scheduler does not rebalance running pods; a rollout restart or future scaling spreads them again.","points":10,"is_optional":false,"is_stateful":false},{"id":"61debc9c-171f-508d-8700-91379dcaeae9","lab_id":"612bc750-1403-592d-b53b-bbab3900bf52","position":6,"title":"Back up etcd","description":"This sandbox's etcd listens on `http://127.0.0.1:2379` without TLS. Save a snapshot to `~/work/etcd-backup.db` with `etcdctl snapshot save`, then check it with `etcdctl --write-out=table snapshot status ~/work/etcd-backup.db`.\n","verification_script":"#!/bin/bash\nf=/home/labuser/work/etcd-backup.db\ntest -s \"$f\" \u0026\u0026 ETCDCTL_API=3 etcdctl snapshot status \"$f\" \u003e/dev/null 2\u003e\u00261\n","hint_context":"`ETCDCTL_API=3 etcdctl --endpoints=http://127.0.0.1:2379 snapshot save \u003cfile\u003e`. On a kubeadm cluster you would also pass --cacert, --cert and --key from /etc/kubernetes/pki/etcd/.","explanation_context":"The snapshot contains every object in the cluster. Store it off the cluster, on a schedule. Restoring it (etcdutl snapshot restore) brings the whole cluster state back.","points":20,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('3a06d138-ef7c-5163-ad8b-0cdbbf138e6f', '38246ef5-1088-508a-b562-6bf4f364a2ce', 'dd8d776a-58f7-54a0-8c8f-7a26f1bab503', 1, 'Run an app across two nodes', $md$Register a second node (`kubectl apply -f node2.yaml`), then apply `web.yaml`. Check with `kubectl get pods -o wide` that the 4 pods are spread over both nodes.$md$, $script$#!/bin/bash
test "$(kubectl get deploy web -o jsonpath='{.status.readyReplicas}')" = "4" || exit 1
kubectl get pods -l app=web -o jsonpath='{.items[*].spec.nodeName}' | grep -q node2
$script$, 'Apply node2.yaml first, wait until `kubectl get nodes` shows it Ready, then apply web.yaml.', 'The topologySpreadConstraint asked the scheduler to keep the pod count per node within 1, so the pods landed 2 and 2.', 10, false, true),
('3b8954dc-302e-50a0-a8d4-013f67ed3647', '38246ef5-1088-508a-b562-6bf4f364a2ce', '72aea050-94b3-5d20-a4ea-3329b46c3504', 2, 'Protect the app with a PodDisruptionBudget', $md$Create a PodDisruptionBudget named `web-pdb` that keeps at least **3** pods with label `app=web` available during voluntary disruptions like a drain.$md$, $script$#!/bin/bash
test "$(kubectl get pdb web-pdb -o jsonpath='{.spec.minAvailable} {.spec.selector.matchLabels.app}')" = "3 web"
$script$, '`kubectl create pdb <name> --selector=app=web --min-available=3`', 'A drain evicts pods through the Eviction API, which respects PDBs. It will never take the app below 3 available pods at once.', 15, false, true),
('35449922-41be-5b42-9768-62ad760289ca', '38246ef5-1088-508a-b562-6bf4f364a2ce', 'df0fec6f-07c6-55c4-a324-d1fed1c2ea0f', 3, 'Cordon a node', $md$Mark `node2` as unschedulable so no new pods go there. Look at `kubectl get nodes`.$md$, $script$#!/bin/bash
test "$(kubectl get node node2 -o jsonpath='{.spec.unschedulable}')" = "true"
$script$, '`kubectl cordon <node>`', 'The node now shows SchedulingDisabled. Pods already running there are not touched. Cordon only stops new placements.', 10, false, true),
('ad839936-f59a-570e-bc9e-0655e4b55637', '38246ef5-1088-508a-b562-6bf4f364a2ce', '2ef5ff28-94dc-5ea3-a9fc-0b3559f9e507', 4, 'Drain the node for maintenance', $md$Drain `node2` so all `web` pods move to `kwok-node`. Then check `kubectl get pods -o wide`.$md$, $script$#!/bin/bash
! kubectl get pods -l app=web -o jsonpath='{.items[*].spec.nodeName}' | grep -q node2 || exit 1
test "$(kubectl get deploy web -o jsonpath='{.status.readyReplicas}')" = "4"
$script$, '`kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`', 'drain cordons the node and evicts its pods (respecting the PDB). The Deployment recreated them on kwok-node. The node is now safe to patch or reboot.', 20, false, true),
('b2d4c085-4de2-5115-b76c-aeafe3156dd6', '38246ef5-1088-508a-b562-6bf4f364a2ce', 'f35d63b7-fca1-5c4f-b23e-4f5a0d94f677', 5, 'Bring the node back', $md$Maintenance is done. Make `node2` schedulable again. (Existing pods do not move back on their own; new pods can use it again.)$md$, $script$#!/bin/bash
test -z "$(kubectl get node node2 -o jsonpath='{.spec.unschedulable}')"
$script$, '`kubectl uncordon <node>`', 'uncordon removes the unschedulable flag. The scheduler does not rebalance running pods; a rollout restart or future scaling spreads them again.', 10, false, false),
('72053d1b-b9fd-5c93-9a52-8768ddf815d5', '38246ef5-1088-508a-b562-6bf4f364a2ce', '61debc9c-171f-508d-8700-91379dcaeae9', 6, 'Back up etcd', $md$This sandbox's etcd listens on `http://127.0.0.1:2379` without TLS. Save a snapshot to `~/work/etcd-backup.db` with `etcdctl snapshot save`, then check it with `etcdctl --write-out=table snapshot status ~/work/etcd-backup.db`.
$md$, $script$#!/bin/bash
f=/home/labuser/work/etcd-backup.db
test -s "$f" && ETCDCTL_API=3 etcdctl snapshot status "$f" >/dev/null 2>&1
$script$, '`ETCDCTL_API=3 etcdctl --endpoints=http://127.0.0.1:2379 snapshot save <file>`. On a kubeadm cluster you would also pass --cacert, --cert and --key from /etc/kubernetes/pki/etcd/.', 'The snapshot contains every object in the cluster. Store it off the cluster, on a schedule. Restoring it (etcdutl snapshot restore) brings the whole cluster state back.', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '38246ef5-1088-508a-b562-6bf4f364a2ce', updated_at = now()
WHERE id = '612bc750-1403-592d-b53b-bbab3900bf52' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b12db871-05a7-5d91-a355-7cf5f23f4d02', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why must containerd be configured with SystemdCgroup = true on a kubeadm clus...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('92a34821-4c7b-5e72-bc67-ebd4844a617b', 'b12db871-05a7-5d91-a355-7cf5f23f4d02', 1, $json${"prompt":"Why must containerd be configured with SystemdCgroup = true on a kubeadm cluster?","multiple":false,"options":[{"id":"a","text":"It makes images download faster","is_correct":false},{"id":"b","text":"The kubelet uses the systemd cgroup driver, and the runtime must use the same one or pods and the control plane become unstable","is_correct":true},{"id":"c","text":"It enables NetworkPolicy","is_correct":false},{"id":"d","text":"It is only needed on Windows","is_correct":false}],"explanation":"Mismatched cgroup drivers are a classic cause of random restarts on new kubeadm clusters."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3f32bc90-e94e-514f-bf99-df566fb31e0f', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command prints a fresh join command for adding a worker node?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4b56242b-a64c-5a12-a3a7-13e596da2f33', '3f32bc90-e94e-514f-bf99-df566fb31e0f', 1, $json${"prompt":"Which command prints a fresh join command for adding a worker node?","multiple":false,"options":[{"id":"a","text":"kubeadm init --join","is_correct":false},{"id":"b","text":"kubeadm token create --print-join-command","is_correct":true},{"id":"c","text":"kubectl join node","is_correct":false},{"id":"d","text":"kubeadm reset","is_correct":false}],"explanation":"Join tokens expire after 24 hours; this creates a new token and prints the full command."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e9f93475-c462-5e72-ac02-d71264f4b5fd', '00000000-0000-0000-0000-000000000001', 'mcq', 'A RoleBinding in namespace dev references the ClusterRole admin. What can its...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f7296826-36e8-5e08-bcb9-cca399f0bd2e', 'e9f93475-c462-5e72-ac02-d71264f4b5fd', 1, $json${"prompt":"A RoleBinding in namespace dev references the ClusterRole admin. What can its subjects do?","multiple":false,"options":[{"id":"a","text":"Administer the whole cluster","is_correct":false},{"id":"b","text":"Administer objects in namespace dev only","is_correct":true},{"id":"c","text":"Nothing, because the kinds do not match","is_correct":false},{"id":"d","text":"Only read objects","is_correct":false}],"explanation":"RoleBindings scope a ClusterRole's permissions to their own namespace."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('35f9ed93-6297-579e-a6cd-c887aa43e122', '00000000-0000-0000-0000-000000000001', 'mcq', 'An app never calls the Kubernetes API. What is a good hardening step for its ...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('449adc58-823f-5144-b4e1-bc94bc59a367', '35f9ed93-6297-579e-a6cd-c887aa43e122', 1, $json${"prompt":"An app never calls the Kubernetes API. What is a good hardening step for its pods?","multiple":false,"options":[{"id":"a","text":"Give it cluster-admin just in case","is_correct":false},{"id":"b","text":"Set automountServiceAccountToken false","is_correct":true},{"id":"c","text":"Run it as root","is_correct":false},{"id":"d","text":"Use hostNetwork","is_correct":false}],"explanation":"Without a mounted token, an attacker in the container cannot use it to talk to the API."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('70e9dae2-55a7-5da4-9718-477b58985c4d', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does `kubectl drain node1 --ignore-daemonsets` do?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2a908a11-dfd5-512f-87b2-1a73beb4eeb3', '70e9dae2-55a7-5da4-9718-477b58985c4d', 1, $json${"prompt":"What does `kubectl drain node1 --ignore-daemonsets` do?","multiple":false,"options":[{"id":"a","text":"Deletes node1 from the cluster","is_correct":false},{"id":"b","text":"Marks node1 unschedulable and evicts its pods (except DaemonSet pods) so they move elsewhere","is_correct":true},{"id":"c","text":"Restarts all containers on node1","is_correct":false},{"id":"d","text":"Upgrades the kubelet","is_correct":false}],"explanation":"Drain prepares a node for maintenance. Uncordon it afterwards."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('18217f74-c267-572a-b43b-eaffea658cf5', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does a PodDisruptionBudget protect against?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e048b21b-45af-5813-afdc-28a58fef4f4c', '18217f74-c267-572a-b43b-eaffea658cf5', 1, $json${"prompt":"What does a PodDisruptionBudget protect against?","multiple":false,"options":[{"id":"a","text":"Node hardware failures","is_correct":false},{"id":"b","text":"Too many pods of an app being evicted at once during voluntary disruptions such as drains and upgrades","is_correct":true},{"id":"c","text":"Pods using too much memory","is_correct":false},{"id":"d","text":"Image pull errors","is_correct":false}],"explanation":"PDBs only cover voluntary evictions. Crashes and node failures are involuntary."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7d5d2d20-64f8-5e9f-b8b4-88f00e479b5f', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the correct order when upgrading a kubeadm cluster by one minor version?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('863b72ba-d318-5acd-b03c-05904172605b', '7d5d2d20-64f8-5e9f-b8b4-88f00e479b5f', 1, $json${"prompt":"What is the correct order when upgrading a kubeadm cluster by one minor version?","multiple":false,"options":[{"id":"a","text":"Workers first, then the control plane","is_correct":false},{"id":"b","text":"Control plane first (kubeadm upgrade apply), then each worker one at a time (drain, upgrade, uncordon)","is_correct":true},{"id":"c","text":"All nodes at the same moment","is_correct":false},{"id":"d","text":"Only the kubelets need upgrading","is_correct":false}],"explanation":"Kubelets must never be newer than the API server, so the control plane goes first."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7b7733f4-f301-5b7c-a9b1-dad6fe8448cd', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does an etcd snapshot let you recover?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0bce5b6e-f71e-5cba-807f-559a817c2724', '7b7733f4-f301-5b7c-a9b1-dad6fe8448cd', 1, $json${"prompt":"What does an etcd snapshot let you recover?","multiple":false,"options":[{"id":"a","text":"The cluster's objects (Deployments, Services, Secrets, RBAC)","is_correct":true},{"id":"b","text":"The files stored in PersistentVolumes","is_correct":false},{"id":"c","text":"Container images","is_correct":false},{"id":"d","text":"Node operating systems","is_correct":false}],"explanation":"etcd stores the API objects. Volume contents and images need separate backups."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('8be46d53-4a2e-51e3-b0ca-5f918002e7f3', '00000000-0000-0000-0000-000000000001', 'mcq', 'A namespace should reject pods that run as root or keep all capabilities. Whi...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e048ed6b-f36b-5e59-a66b-e4cd462299aa', '8be46d53-4a2e-51e3-b0ca-5f918002e7f3', 1, $json${"prompt":"A namespace should reject pods that run as root or keep all capabilities. Which built-in feature does this?","multiple":false,"options":[{"id":"a","text":"NetworkPolicy","is_correct":false},{"id":"b","text":"Pod Security Admission with enforce=restricted on the namespace","is_correct":true},{"id":"c","text":"ResourceQuota","is_correct":false},{"id":"d","text":"PodDisruptionBudget","is_correct":false}],"explanation":"Labeling the namespace with the restricted Pod Security Standard makes the API server reject non-compliant pods."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('c78fe849-5b5e-594f-833a-731b252a7a3e', '00000000-0000-0000-0000-000000000001', 'Quiz: Real Clusters', 'k8s-cluster-ops-quiz', 'Quiz covering Real Clusters: Setup, Security and Operations.', 'mcq', 'published', 'module', '0bfbb16a-6679-565f-9573-e306d6c30409', 20, 70, 5, 9, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = 'c78fe849-5b5e-594f-833a-731b252a7a3e' AND question_id NOT IN ('b12db871-05a7-5d91-a355-7cf5f23f4d02', '3f32bc90-e94e-514f-bf99-df566fb31e0f', 'e9f93475-c462-5e72-ac02-d71264f4b5fd', '35f9ed93-6297-579e-a6cd-c887aa43e122', '70e9dae2-55a7-5da4-9718-477b58985c4d', '18217f74-c267-572a-b43b-eaffea658cf5', '7d5d2d20-64f8-5e9f-b8b4-88f00e479b5f', '7b7733f4-f301-5b7c-a9b1-dad6fe8448cd', '8be46d53-4a2e-51e3-b0ca-5f918002e7f3');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('ae5425d2-aea3-5453-b309-dd3f6fa25992', 'c78fe849-5b5e-594f-833a-731b252a7a3e', 'b12db871-05a7-5d91-a355-7cf5f23f4d02', '92a34821-4c7b-5e72-bc67-ebd4844a617b', 0, 1),
('dc9ec86a-6dd0-5352-9219-e3640c98aced', 'c78fe849-5b5e-594f-833a-731b252a7a3e', '3f32bc90-e94e-514f-bf99-df566fb31e0f', '4b56242b-a64c-5a12-a3a7-13e596da2f33', 1, 1),
('ec18e6c3-a069-5507-8277-90c5b0e6a0f2', 'c78fe849-5b5e-594f-833a-731b252a7a3e', 'e9f93475-c462-5e72-ac02-d71264f4b5fd', 'f7296826-36e8-5e08-bcb9-cca399f0bd2e', 2, 1),
('74422129-2cfa-5004-9c63-b795d0a5d632', 'c78fe849-5b5e-594f-833a-731b252a7a3e', '35f9ed93-6297-579e-a6cd-c887aa43e122', '449adc58-823f-5144-b4e1-bc94bc59a367', 3, 1),
('a2eefe95-3d4a-513f-8057-dc1c6c98159f', 'c78fe849-5b5e-594f-833a-731b252a7a3e', '70e9dae2-55a7-5da4-9718-477b58985c4d', '2a908a11-dfd5-512f-87b2-1a73beb4eeb3', 4, 1),
('e3591243-63c0-50d1-a59c-7f8f4f4e7f0f', 'c78fe849-5b5e-594f-833a-731b252a7a3e', '18217f74-c267-572a-b43b-eaffea658cf5', 'e048b21b-45af-5813-afdc-28a58fef4f4c', 5, 1),
('83f11bd9-d537-59f1-b5e4-dff1b65b3d1f', 'c78fe849-5b5e-594f-833a-731b252a7a3e', '7d5d2d20-64f8-5e9f-b8b4-88f00e479b5f', '863b72ba-d318-5acd-b03c-05904172605b', 6, 1),
('b2e2e031-6bba-58c4-9bc0-0c9397854886', 'c78fe849-5b5e-594f-833a-731b252a7a3e', '7b7733f4-f301-5b7c-a9b1-dad6fe8448cd', '0bce5b6e-f71e-5cba-807f-559a817c2724', 7, 1),
('36924bbf-3cee-51d5-a483-e39f40dcee05', 'c78fe849-5b5e-594f-833a-731b252a7a3e', '8be46d53-4a2e-51e3-b0ca-5f918002e7f3', 'e048ed6b-f36b-5e59-a66b-e4cd462299aa', 8, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('0bfbb16a-6679-565f-9573-e306d6c30409', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'a6a3c179-127f-5a21-b823-1ddb520e36eb', 'Quiz: Real Clusters', 'assessment', 3, 12, 'c78fe849-5b5e-594f-833a-731b252a7a3e')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Cheat Sheet
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('e4330df2-0c59-592e-be64-093765351ea3', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Cheat Sheet', 11)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('f533fd17-715c-5f6f-bffe-a29bef310af2', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'e4330df2-0c59-592e-be64-093765351ea3', 'kubectl and Helm Cheat Sheet', 'notes', 0, $md$A one-page reference of the commands used in this course, grouped by task. Keep it open while you work.

## Cluster, contexts and help

```bash
kubectl version                          # client and server versions
kubectl cluster-info                     # API server address
kubectl get nodes -o wide
kubectl api-resources                    # every kind + short name + namespaced?
kubectl explain deployment.spec.strategy # documentation for any field
kubectl config get-contexts              # which clusters you can talk to
kubectl config use-context <name>        # switch cluster
kubectl config set-context --current --namespace=<ns>   # default namespace
```

Handy shell setup:

```bash
alias k=kubectl
source <(kubectl completion bash)        # tab completion (zsh: kubectl completion zsh)
complete -o default -F __start_kubectl k
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-cluster-q1", "type": "mcq",
    "prompt": "You forgot which fields a Deployment's rolling update supports. Which command shows the documentation inside the terminal?",
    "options": [
      {"id": "a", "text": "kubectl explain deployment.spec.strategy.rollingUpdate"},
      {"id": "b", "text": "kubectl describe deployment --help-fields"},
      {"id": "c", "text": "kubectl api-resources deployment"},
      {"id": "d", "text": "kubectl get deployment -o docs"}
    ],
    "correct": "a",
    "explanation": "kubectl explain reads the schema from the cluster itself, so it always matches your cluster's version." }
] }
```

## Viewing and finding things

```bash
kubectl get pods                         # current namespace
kubectl get pods -A                      # all namespaces
kubectl get pods -o wide                 # + IP and node
kubectl get pods -l app=web              # by label
kubectl get pods --field-selector status.phase=Pending
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get pod web -o yaml              # the full object
kubectl get pod web -o jsonpath='{.status.podIP}'
kubectl get deploy,svc,ingress -n shop
kubectl describe pod web                 # details + Events
kubectl get events -A --sort-by=.lastTimestamp
kubectl get pods -w                      # watch live
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-view-q1", "type": "mcq",
    "prompt": "Which command prints only the IP address of pod web?",
    "options": [
      {"id": "a", "text": "kubectl get pod web -o jsonpath='{.status.podIP}'"},
      {"id": "b", "text": "kubectl describe pod web --ip"},
      {"id": "c", "text": "kubectl get pod web --ip-only"},
      {"id": "d", "text": "kubectl logs web --ip"}
    ],
    "correct": "a",
    "explanation": "jsonpath extracts any field from the object. It is ideal for scripts." }
] }
```

## Creating, changing and deleting

```bash
kubectl apply -f file.yaml               # create or update (declarative)
kubectl apply -f ./manifests/            # a whole folder
kubectl apply -k ./overlays/prod         # Kustomize
kubectl diff -f file.yaml                # what would change?
kubectl create deployment web --image=nginx:1.27 --replicas=3
kubectl create deployment web --image=nginx:1.27 --dry-run=client -o yaml > web.yaml
kubectl run tmp --rm -it --image=busybox:1.36 -- sh     # throwaway debug pod
kubectl expose deployment web --port=80 --type=ClusterIP
kubectl edit deployment web
kubectl label pod web env=prod           # add label   (env- removes it)
kubectl annotate pod web note="hello"
kubectl delete -f file.yaml
kubectl delete pod web
kubectl delete pods -l app=web
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-change-q1", "type": "mcq",
    "prompt": "Before applying a changed manifest to production, which command shows exactly what would change?",
    "options": [
      {"id": "a", "text": "kubectl diff -f file.yaml"},
      {"id": "b", "text": "kubectl apply --preview"},
      {"id": "c", "text": "kubectl describe -f file.yaml"},
      {"id": "d", "text": "kubectl get -f file.yaml -w"}
    ],
    "correct": "a",
    "explanation": "kubectl diff compares the file with the live object on the server." }
] }
```

## Deployments, scaling and rollouts

```bash
kubectl scale deployment web --replicas=5
kubectl autoscale deployment web --cpu-percent=60 --min=2 --max=10
kubectl set image deployment/web nginx=nginx:1.27.1
kubectl set resources deployment web -c nginx --requests=cpu=100m,memory=128Mi --limits=memory=256Mi
kubectl rollout status deployment/web
kubectl rollout history deployment/web
kubectl rollout undo deployment/web [--to-revision=2]
kubectl rollout pause|resume deployment/web
kubectl rollout restart deployment/web
kubectl create job manual --from=cronjob/backup
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-rollout-q1", "type": "mcq",
    "prompt": "Which command replaces all pods of a Deployment with fresh ones without changing its spec?",
    "options": [
      {"id": "a", "text": "kubectl rollout restart deployment/web"},
      {"id": "b", "text": "kubectl rollout undo deployment/web"},
      {"id": "c", "text": "kubectl scale deployment/web --replicas=0"},
      {"id": "d", "text": "kubectl delete deployment web"}
    ],
    "correct": "a",
    "explanation": "rollout restart triggers a normal rolling update with the same template, with no downtime." }
] }
```

## Debugging

```bash
kubectl logs web [-c container] [-f] [--previous] [--since=10m]
kubectl logs -l app=web --all-containers --prefix
kubectl exec -it web -- sh
kubectl exec web -- env
kubectl port-forward pod/web 8080:80
kubectl port-forward svc/web 8080:80
kubectl cp web:/tmp/dump.txt ./dump.txt
kubectl debug -it web --image=busybox:1.36 --target=web     # ephemeral debug container
kubectl debug node/worker1 -it --image=busybox:1.36          # shell on a node
kubectl top nodes / kubectl top pods -A
kubectl get endpoints web                                    # does the Service have pods?
kubectl auth can-i delete pods --as=jane -n dev
```

`kubectl debug` adds a temporary container with tools to a running pod. It is perfect for minimal ("distroless") images that have no shell.

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-debug-q1", "type": "mcq",
    "prompt": "A pod uses a distroless image with no shell, so `kubectl exec -it pod -- sh` fails. How can you still investigate inside it?",
    "options": [
      {"id": "a", "text": "kubectl debug -it <pod> --image=busybox:1.36 --target=<container>"},
      {"id": "b", "text": "Rebuild the image with bash"},
      {"id": "c", "text": "kubectl logs --shell"},
      {"id": "d", "text": "It is impossible"}
    ],
    "correct": "a",
    "explanation": "An ephemeral debug container shares the pod's namespaces and brings its own tools." }
] }
```

## Nodes and cluster maintenance

```bash
kubectl cordon node1 / kubectl uncordon node1
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data
kubectl taint node node1 key=value:NoSchedule      # key- removes it
kubectl label node node1 disktype=ssd
kubectl delete node node1
kubeadm token create --print-join-command
kubeadm certs check-expiration
kubeadm upgrade plan
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-nodes-q1", "type": "mcq",
    "prompt": "Which command removes the taint with key gpu from node1?",
    "options": [
      {"id": "a", "text": "kubectl taint node node1 gpu-"},
      {"id": "b", "text": "kubectl untaint node1 gpu"},
      {"id": "c", "text": "kubectl label node node1 gpu-"},
      {"id": "d", "text": "kubectl taint node node1 --delete gpu"}
    ],
    "correct": "a",
    "explanation": "A trailing minus removes taints (and labels) with that key." }
] }
```

## Helm

```bash
helm repo add <name> <url> && helm repo update
helm search repo <keyword> / helm search hub <keyword>
helm show values <chart>
helm install <release> <chart> -n <ns> --create-namespace -f values.yaml
helm upgrade --install <release> <chart> -f values.yaml --atomic --wait
helm list -A
helm status <release>
helm history <release>
helm rollback <release> <revision>
helm get values <release> [--all]
helm get manifest <release>
helm template <release> <chart> -f values.yaml
helm lint <chart-dir>
helm uninstall <release>
helm create <name> / helm package <chart-dir> / helm dependency update <chart-dir>
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-helm-q1", "type": "mcq",
    "prompt": "Which command shows the values you supplied when a release was installed or last upgraded?",
    "options": [
      {"id": "a", "text": "helm get values <release>"},
      {"id": "b", "text": "helm show values <release>"},
      {"id": "c", "text": "helm history <release>"},
      {"id": "d", "text": "helm lint <release>"}
    ],
    "correct": "a",
    "explanation": "helm get values reads the release; helm show values reads a chart's defaults." }
] }
```
$md$, 20, $json$[{"id":"k8s-ref-cluster-q1","type":"mcq","correct":"a"},{"id":"k8s-ref-view-q1","type":"mcq","correct":"a"},{"id":"k8s-ref-change-q1","type":"mcq","correct":"a"},{"id":"k8s-ref-rollout-q1","type":"mcq","correct":"a"},{"id":"k8s-ref-debug-q1","type":"mcq","correct":"a"},{"id":"k8s-ref-nodes-q1","type":"mcq","correct":"a"},{"id":"k8s-ref-helm-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Interview Prep & Production Troubleshooting
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('050f01cb-eacf-550f-8789-c0f2b5a3fc5e', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Interview Prep & Production Troubleshooting', 12)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('3c1c626d-4fb2-52b5-b3c6-8b211a42e0f9', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '050f01cb-eacf-550f-8789-c0f2b5a3fc5e', 'Kubernetes Interview Questions and Answers', 'notes', 0, $md$This lesson collects the Kubernetes questions that come up again and again in DevOps, SRE, platform and backend interviews. They go from basic to advanced, with short, correct answers you can say out loud. Everything here was taught earlier in the course; the goal now is to **explain it clearly and connect it to real situations**.

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
$md$, 60, $json$[{"id":"k8s-int-basic-q1","type":"mcq","correct":"b"},{"id":"k8s-int-mid-q1","type":"mcq","correct":"b"},{"id":"k8s-int-adv-q1","type":"mcq","correct":"b"},{"id":"k8s-int-adv-q2","type":"mcq","correct":"b"},{"id":"k8s-int-scenario-q1","type":"mcq","correct":"b"},{"id":"k8s-int-scenario-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('fbd8c935-e981-592c-b6fe-bbfe798e1a87', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '050f01cb-eacf-550f-8789-c0f2b5a3fc5e', 'Production Troubleshooting Playbook', 'notes', 1, $md$Knowing the objects is not enough. In a real job you get paged with a vague message like "checkout is broken" and have to find the cause quickly. This playbook gives you a **repeatable method** and the **most common failures**, each with symptoms, commands, causes and fixes. The lab at the end drops you into a broken namespace to practice.

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
$md$, 60, $json$[{"id":"k8s-ts-method-q1","type":"mcq","correct":"b"},{"id":"k8s-ts-status-q1","type":"mcq","correct":"b"},{"id":"k8s-ts-status-q2","type":"mcq","correct":"a"},{"id":"k8s-ts-net-q1","type":"mcq","correct":"a"},{"id":"k8s-ts-net-q2","type":"mcq","correct":"a"},{"id":"k8s-ts-deploy-q1","type":"mcq","correct":"b"},{"id":"k8s-ts-node-q1","type":"mcq","correct":"a"},{"id":"k8s-ts-practice-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('462aa580-f30d-5ba1-b3fa-6cb30780fa10', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'fbd8c935-e981-592c-b6fe-bbfe798e1a87', 'module', 'Production Troubleshooting Playbook', NULL, 'terminal', 'mindforge/lab-k8s:1.31', 0, $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/shop.yaml <<'MFEOF'
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

MFEOF
chmod 666 /home/labuser/work/shop.yaml
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
$script$, NULL, 60, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

DELETE FROM lab_task_version_items WHERE task_version_id = '11788130-789d-5e88-bdae-9f104cf40121' AND id NOT IN ('80a8e99f-f8fa-5851-8f94-279ec3a352b9', '38b089e8-4cba-52bd-83f4-ce6d92dfbdde', 'b9528073-5d67-517c-a684-7de28e2a5239', '610ba56d-723a-5d10-87a5-ad344105ab55');
UPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = '11788130-789d-5e88-bdae-9f104cf40121';
DELETE FROM lab_tasks WHERE lab_id = '462aa580-f30d-5ba1-b3fa-6cb30780fa10' AND id NOT IN ('cc4dc1f6-4298-532b-bf4d-733df07d32ba', 'c8d68a41-bc8a-549f-a9f7-53a5a4b9591a', 'a5e941cb-7d2d-5e01-a9d0-438d026cb54d', '7d22f173-5bcb-5c16-bc56-ee2b42748b6b');
UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '462aa580-f30d-5ba1-b3fa-6cb30780fa10';

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('cc4dc1f6-4298-532b-bf4d-733df07d32ba', '462aa580-f30d-5ba1-b3fa-6cb30780fa10', 1, 'Incident 1: the catalog Service sends traffic nowhere', $md$Everything is in the `shop` namespace. The team says "catalog is up but nobody can reach it through its Service". Find the cause with `kubectl get endpoints -n shop` and friends, and fix it **without** changing the pods.
$md$, $script$#!/bin/bash
test "$(kubectl get endpoints catalog -n shop -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)" = "2"
$script$, 'Compare the Service''s selector with the pods'' labels (`kubectl get pods -n shop --show-labels`).', 'The Service selected app=catalogue, but the pods are labeled app=catalog, so there were no endpoints. Fixing the selector filled the endpoint list immediately.', 20, false, false),
('c8d68a41-bc8a-549f-a9f7-53a5a4b9591a', '462aa580-f30d-5ba1-b3fa-6cb30780fa10', 2, 'Incident 2: payments pods are stuck in Pending', $md$The `payments` pods never start. Find out why from the pod events. The node pool the pods ask for was never created, and the team confirms payments may run on any node. Fix the Deployment so its pods run.
$md$, $script$#!/bin/bash
test "$(kubectl get deploy payments -n shop -o jsonpath='{.status.readyReplicas}')" = "2" || exit 1
test -z "$(kubectl get deploy payments -n shop -o jsonpath='{.spec.template.spec.nodeSelector.pool}')"
$script$, '`kubectl describe pod -n shop -l app=payments` shows a FailedScheduling event about node affinity/selector. Remove the nodeSelector from the Deployment (kubectl edit, or a JSON patch).', 'The pods required a node with label pool=payments and no node has it. Removing the nodeSelector (or labeling a node, if the pool really existed) lets the scheduler place them.', 20, false, false),
('a5e941cb-7d2d-5e01-a9d0-438d026cb54d', '462aa580-f30d-5ba1-b3fa-6cb30780fa10', 3, 'Incident 3: the checkout rollout is stuck', $md$A new `checkout` release went out a few minutes ago and never finished. Old pods still serve traffic, but new pods are Pending. Look at `kubectl rollout status`, `kubectl rollout history` and the new pods' events, then get checkout back to the last working version.
$md$, $script$#!/bin/bash
test "$(kubectl get deploy checkout -n shop -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')" = "100m" || exit 1
test "$(kubectl get deploy checkout -n shop -o jsonpath='{.status.updatedReplicas}/{.status.readyReplicas}')" = "3/3"
$script$, 'The new pods request 64 CPUs (Insufficient cpu). The quickest safe fix is `kubectl rollout undo`.', 'A bad release that can never become ready leaves the rollout stuck, while the old ReplicaSet keeps serving (that is RollingUpdate protecting you). rollout undo returns to the previous template; then fix the manifest properly before redeploying.', 20, false, false),
('7d22f173-5bcb-5c16-bc56-ee2b42748b6b', '462aa580-f30d-5ba1-b3fa-6cb30780fa10', 4, 'Incident 4: the orders volume never binds', $md$The claim `orders-data` stays Pending. The cluster has no StorageClass, and the admins pre-created a matching disk `orders-pv`. Make the claim bind to it. (Tip: many PVC fields cannot be changed after creation.)
$md$, $script$#!/bin/bash
test "$(kubectl get pvc orders-data -n shop -o jsonpath='{.status.phase} {.spec.volumeName}')" = "Bound orders-pv"
$script$, '`kubectl describe pvc orders-data -n shop` says storageclass fast-ssd was not found. storageClassName is immutable, so delete the claim and recreate it with `storageClassName: ""`.', 'The claim asked for a StorageClass that does not exist, so nothing could provision or bind it. An empty storageClassName means "bind to a pre-created PV without a class". Because the field is immutable, the claim had to be recreated.', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('11788130-789d-5e88-bdae-9f104cf40121', '462aa580-f30d-5ba1-b3fa-6cb30780fa10', 1, $json$[{"id":"cc4dc1f6-4298-532b-bf4d-733df07d32ba","lab_id":"462aa580-f30d-5ba1-b3fa-6cb30780fa10","position":1,"title":"Incident 1: the catalog Service sends traffic nowhere","description":"Everything is in the `shop` namespace. The team says \"catalog is up but nobody can reach it through its Service\". Find the cause with `kubectl get endpoints -n shop` and friends, and fix it **without** changing the pods.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get endpoints catalog -n shop -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)\" = \"2\"\n","hint_context":"Compare the Service's selector with the pods' labels (`kubectl get pods -n shop --show-labels`).","explanation_context":"The Service selected app=catalogue, but the pods are labeled app=catalog, so there were no endpoints. Fixing the selector filled the endpoint list immediately.","points":20,"is_optional":false,"is_stateful":false},{"id":"c8d68a41-bc8a-549f-a9f7-53a5a4b9591a","lab_id":"462aa580-f30d-5ba1-b3fa-6cb30780fa10","position":2,"title":"Incident 2: payments pods are stuck in Pending","description":"The `payments` pods never start. Find out why from the pod events. The node pool the pods ask for was never created, and the team confirms payments may run on any node. Fix the Deployment so its pods run.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get deploy payments -n shop -o jsonpath='{.status.readyReplicas}')\" = \"2\" || exit 1\ntest -z \"$(kubectl get deploy payments -n shop -o jsonpath='{.spec.template.spec.nodeSelector.pool}')\"\n","hint_context":"`kubectl describe pod -n shop -l app=payments` shows a FailedScheduling event about node affinity/selector. Remove the nodeSelector from the Deployment (kubectl edit, or a JSON patch).","explanation_context":"The pods required a node with label pool=payments and no node has it. Removing the nodeSelector (or labeling a node, if the pool really existed) lets the scheduler place them.","points":20,"is_optional":false,"is_stateful":false},{"id":"a5e941cb-7d2d-5e01-a9d0-438d026cb54d","lab_id":"462aa580-f30d-5ba1-b3fa-6cb30780fa10","position":3,"title":"Incident 3: the checkout rollout is stuck","description":"A new `checkout` release went out a few minutes ago and never finished. Old pods still serve traffic, but new pods are Pending. Look at `kubectl rollout status`, `kubectl rollout history` and the new pods' events, then get checkout back to the last working version.\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get deploy checkout -n shop -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')\" = \"100m\" || exit 1\ntest \"$(kubectl get deploy checkout -n shop -o jsonpath='{.status.updatedReplicas}/{.status.readyReplicas}')\" = \"3/3\"\n","hint_context":"The new pods request 64 CPUs (Insufficient cpu). The quickest safe fix is `kubectl rollout undo`.","explanation_context":"A bad release that can never become ready leaves the rollout stuck, while the old ReplicaSet keeps serving (that is RollingUpdate protecting you). rollout undo returns to the previous template; then fix the manifest properly before redeploying.","points":20,"is_optional":false,"is_stateful":false},{"id":"7d22f173-5bcb-5c16-bc56-ee2b42748b6b","lab_id":"462aa580-f30d-5ba1-b3fa-6cb30780fa10","position":4,"title":"Incident 4: the orders volume never binds","description":"The claim `orders-data` stays Pending. The cluster has no StorageClass, and the admins pre-created a matching disk `orders-pv`. Make the claim bind to it. (Tip: many PVC fields cannot be changed after creation.)\n","verification_script":"#!/bin/bash\ntest \"$(kubectl get pvc orders-data -n shop -o jsonpath='{.status.phase} {.spec.volumeName}')\" = \"Bound orders-pv\"\n","hint_context":"`kubectl describe pvc orders-data -n shop` says storageclass fast-ssd was not found. storageClassName is immutable, so delete the claim and recreate it with `storageClassName: \"\"`.","explanation_context":"The claim asked for a StorageClass that does not exist, so nothing could provision or bind it. An empty storageClassName means \"bind to a pre-created PV without a class\". Because the field is immutable, the claim had to be recreated.","points":20,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('80a8e99f-f8fa-5851-8f94-279ec3a352b9', '11788130-789d-5e88-bdae-9f104cf40121', 'cc4dc1f6-4298-532b-bf4d-733df07d32ba', 1, 'Incident 1: the catalog Service sends traffic nowhere', $md$Everything is in the `shop` namespace. The team says "catalog is up but nobody can reach it through its Service". Find the cause with `kubectl get endpoints -n shop` and friends, and fix it **without** changing the pods.
$md$, $script$#!/bin/bash
test "$(kubectl get endpoints catalog -n shop -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)" = "2"
$script$, 'Compare the Service''s selector with the pods'' labels (`kubectl get pods -n shop --show-labels`).', 'The Service selected app=catalogue, but the pods are labeled app=catalog, so there were no endpoints. Fixing the selector filled the endpoint list immediately.', 20, false, false),
('38b089e8-4cba-52bd-83f4-ce6d92dfbdde', '11788130-789d-5e88-bdae-9f104cf40121', 'c8d68a41-bc8a-549f-a9f7-53a5a4b9591a', 2, 'Incident 2: payments pods are stuck in Pending', $md$The `payments` pods never start. Find out why from the pod events. The node pool the pods ask for was never created, and the team confirms payments may run on any node. Fix the Deployment so its pods run.
$md$, $script$#!/bin/bash
test "$(kubectl get deploy payments -n shop -o jsonpath='{.status.readyReplicas}')" = "2" || exit 1
test -z "$(kubectl get deploy payments -n shop -o jsonpath='{.spec.template.spec.nodeSelector.pool}')"
$script$, '`kubectl describe pod -n shop -l app=payments` shows a FailedScheduling event about node affinity/selector. Remove the nodeSelector from the Deployment (kubectl edit, or a JSON patch).', 'The pods required a node with label pool=payments and no node has it. Removing the nodeSelector (or labeling a node, if the pool really existed) lets the scheduler place them.', 20, false, false),
('b9528073-5d67-517c-a684-7de28e2a5239', '11788130-789d-5e88-bdae-9f104cf40121', 'a5e941cb-7d2d-5e01-a9d0-438d026cb54d', 3, 'Incident 3: the checkout rollout is stuck', $md$A new `checkout` release went out a few minutes ago and never finished. Old pods still serve traffic, but new pods are Pending. Look at `kubectl rollout status`, `kubectl rollout history` and the new pods' events, then get checkout back to the last working version.
$md$, $script$#!/bin/bash
test "$(kubectl get deploy checkout -n shop -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')" = "100m" || exit 1
test "$(kubectl get deploy checkout -n shop -o jsonpath='{.status.updatedReplicas}/{.status.readyReplicas}')" = "3/3"
$script$, 'The new pods request 64 CPUs (Insufficient cpu). The quickest safe fix is `kubectl rollout undo`.', 'A bad release that can never become ready leaves the rollout stuck, while the old ReplicaSet keeps serving (that is RollingUpdate protecting you). rollout undo returns to the previous template; then fix the manifest properly before redeploying.', 20, false, false),
('610ba56d-723a-5d10-87a5-ad344105ab55', '11788130-789d-5e88-bdae-9f104cf40121', '7d22f173-5bcb-5c16-bc56-ee2b42748b6b', 4, 'Incident 4: the orders volume never binds', $md$The claim `orders-data` stays Pending. The cluster has no StorageClass, and the admins pre-created a matching disk `orders-pv`. Make the claim bind to it. (Tip: many PVC fields cannot be changed after creation.)
$md$, $script$#!/bin/bash
test "$(kubectl get pvc orders-data -n shop -o jsonpath='{.status.phase} {.spec.volumeName}')" = "Bound orders-pv"
$script$, '`kubectl describe pvc orders-data -n shop` says storageclass fast-ssd was not found. storageClassName is immutable, so delete the claim and recreate it with `storageClassName: ""`.', 'The claim asked for a StorageClass that does not exist, so nothing could provision or bind it. An empty storageClassName means "bind to a pre-created PV without a class". Because the field is immutable, the claim had to be recreated.', 20, false, false)
ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

UPDATE lab_definitions
SET is_published = true, published_version_id = '11788130-789d-5e88-bdae-9f104cf40121', updated_at = now()
WHERE id = '462aa580-f30d-5ba1-b3fa-6cb30780fa10' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a21affb9-feae-5408-a45c-2bb1795e5a20', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which component is the only one that talks to etcd directly?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('edf894aa-f1a9-5248-b0bd-7e83ac332614', 'a21affb9-feae-5408-a45c-2bb1795e5a20', 1, $json${"prompt":"Which component is the only one that talks to etcd directly?","multiple":false,"options":[{"id":"a","text":"kubelet","is_correct":false},{"id":"b","text":"kube-apiserver","is_correct":true},{"id":"c","text":"kube-scheduler","is_correct":false},{"id":"d","text":"kube-proxy","is_correct":false}],"explanation":"Every other component goes through the API server."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6112872c-a732-592e-8fea-94b3d9f9075a', '00000000-0000-0000-0000-000000000001', 'mcq', 'You deleted a pod that belongs to a Deployment with 3 replicas. What happens?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e175ebe4-4363-5f07-a876-f81784156e95', '6112872c-a732-592e-8fea-94b3d9f9075a', 1, $json${"prompt":"You deleted a pod that belongs to a Deployment with 3 replicas. What happens?","multiple":false,"options":[{"id":"a","text":"The Deployment now has 2 replicas","is_correct":false},{"id":"b","text":"The ReplicaSet creates a replacement pod to get back to 3","is_correct":true},{"id":"c","text":"The Deployment is deleted too","is_correct":false},{"id":"d","text":"The node restarts","is_correct":false}],"explanation":"The desired state is still 3, so the controller recreates the missing pod."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('596d4539-0763-56c2-8e7f-823632628407', '00000000-0000-0000-0000-000000000001', 'mcq', 'New pods of a rollout are Running but never get traffic, and the rollout does...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('23345282-ab19-54f4-93de-c23ae5664268', '596d4539-0763-56c2-8e7f-823632628407', 1, $json${"prompt":"New pods of a rollout are Running but never get traffic, and the rollout does not progress. What is the most likely reason?","multiple":false,"options":[{"id":"a","text":"The readiness probe is failing","is_correct":true},{"id":"b","text":"The liveness probe is missing","is_correct":false},{"id":"c","text":"The Service type is ClusterIP","is_correct":false},{"id":"d","text":"The image is too small","is_correct":false}],"explanation":"Pods that never become ready are not added to endpoints and do not count as available, so the rollout waits."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7b891573-104a-5bb0-aa29-ad469c553aff', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which workload gives each replica a stable name and its own PersistentVolumeC...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('20d47cc7-5604-566a-b223-9d218e387cfc', '7b891573-104a-5bb0-aa29-ad469c553aff', 1, $json${"prompt":"Which workload gives each replica a stable name and its own PersistentVolumeClaim?","multiple":false,"options":[{"id":"a","text":"Deployment","is_correct":false},{"id":"b","text":"DaemonSet","is_correct":false},{"id":"c","text":"StatefulSet","is_correct":true},{"id":"d","text":"Job","is_correct":false}],"explanation":"StatefulSets use volumeClaimTemplates and ordinal names."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('69c93329-2555-5a67-80b8-bc3f4c8ea3a4', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the full DNS name of Service api in namespace prod?', 'beginner', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0eace016-f7bb-5293-8d24-e43c110b7d17', '69c93329-2555-5a67-80b8-bc3f4c8ea3a4', 1, $json${"prompt":"What is the full DNS name of Service api in namespace prod?","multiple":false,"options":[{"id":"a","text":"api.prod.svc.cluster.local","is_correct":true},{"id":"b","text":"prod.api.cluster.local","is_correct":false},{"id":"c","text":"api.svc.prod","is_correct":false},{"id":"d","text":"api.cluster.prod.local","is_correct":false}],"explanation":"\u003cservice\u003e.\u003cnamespace\u003e.svc.\u003ccluster-domain\u003e, usually cluster.local."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('fda08c20-ed46-5191-b96d-7c745f0f35c1', '00000000-0000-0000-0000-000000000001', 'mcq', 'A container''s CPU usage goes above its CPU limit. What happens?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('54bfd7d4-c045-57f2-909c-68fd33f057d2', 'fda08c20-ed46-5191-b96d-7c745f0f35c1', 1, $json${"prompt":"A container's CPU usage goes above its CPU limit. What happens?","multiple":false,"options":[{"id":"a","text":"It is OOMKilled","is_correct":false},{"id":"b","text":"It is throttled","is_correct":true},{"id":"c","text":"It is moved to another node","is_correct":false},{"id":"d","text":"Nothing","is_correct":false}],"explanation":"CPU is compressible and gets throttled; memory is not and gets OOMKilled."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2f661d13-98fa-5b88-9138-613564cce077', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which is true about Kubernetes Secrets by default?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('884e109d-b440-5ab2-aebe-eb4724cc5d0f', '2f661d13-98fa-5b88-9138-613564cce077', 1, $json${"prompt":"Which is true about Kubernetes Secrets by default?","multiple":false,"options":[{"id":"a","text":"They are encrypted with a cluster key","is_correct":false},{"id":"b","text":"They are base64-encoded and must be protected with RBAC and encryption at rest","is_correct":true},{"id":"c","text":"They cannot be read once created","is_correct":false},{"id":"d","text":"They are stored only on nodes, not in etcd","is_correct":false}],"explanation":"base64 is encoding. Restrict access and enable encryption at rest."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3b87a45d-f335-51f4-aa35-231ff310bc76', '00000000-0000-0000-0000-000000000001', 'mcq', 'A PVC with storageClassName fast-ssd stays Pending in a cluster without that ...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f0ef3627-5835-5a1a-a20f-461a6b9e0d17', '3b87a45d-f335-51f4-aa35-231ff310bc76', 1, $json${"prompt":"A PVC with storageClassName fast-ssd stays Pending in a cluster without that StorageClass. What is the fix?","multiple":false,"options":[{"id":"a","text":"Edit storageClassName on the existing PVC","is_correct":false},{"id":"b","text":"Recreate the PVC with an existing class (or \"\" to bind a pre-created PV), since the field is immutable","is_correct":true},{"id":"c","text":"Restart the kubelet","is_correct":false},{"id":"d","text":"Add a toleration","is_correct":false}],"explanation":"PVC classes cannot be changed after creation."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('060edafb-3eab-5a36-9a0d-7835b16e5c10', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does a taint with effect NoExecute do to running pods that do not tolera...', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c2ec1d5f-bf20-5e50-922f-fe4acc446002', '060edafb-3eab-5a36-9a0d-7835b16e5c10', 1, $json${"prompt":"What does a taint with effect NoExecute do to running pods that do not tolerate it?","multiple":false,"options":[{"id":"a","text":"Nothing","is_correct":false},{"id":"b","text":"Evicts them","is_correct":true},{"id":"c","text":"Restarts their containers","is_correct":false},{"id":"d","text":"Lowers their priority","is_correct":false}],"explanation":"NoExecute both blocks scheduling and evicts non-tolerating pods."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f02af5af-b019-508b-9c4a-74281c7f2116', '00000000-0000-0000-0000-000000000001', 'mcq', 'An Ingress has no ADDRESS and routes nothing. What is most likely missing?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('19db18c4-44ec-5889-b2ed-4f309c4c7cfd', 'f02af5af-b019-508b-9c4a-74281c7f2116', 1, $json${"prompt":"An Ingress has no ADDRESS and routes nothing. What is most likely missing?","multiple":false,"options":[{"id":"a","text":"An ingress controller, or the correct ingressClassName","is_correct":true},{"id":"b","text":"A StatefulSet","is_correct":false},{"id":"c","text":"A ConfigMap","is_correct":false},{"id":"d","text":"A PodDisruptionBudget","is_correct":false}],"explanation":"Ingress objects are only rules; a controller implements them."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('7db2eade-4fff-5a9f-a27f-e610faa2f474', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the purpose of a PodDisruptionBudget?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('84ade001-7904-51fc-ae7b-93a62305d186', '7db2eade-4fff-5a9f-a27f-e610faa2f474', 1, $json${"prompt":"What is the purpose of a PodDisruptionBudget?","multiple":false,"options":[{"id":"a","text":"Limit how many pods of an app voluntary disruptions (drains, upgrades) may take down at once","is_correct":true},{"id":"b","text":"Limit CPU usage","is_correct":false},{"id":"c","text":"Prevent node crashes","is_correct":false},{"id":"d","text":"Schedule pods on specific nodes","is_correct":false}],"explanation":"PDBs protect availability during planned maintenance."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3c7ccd50-113a-5795-b6a9-2f50be97117c', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why run 3 etcd members instead of 2?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('75bbf298-a158-59ad-90cf-1dd989b78869', '3c7ccd50-113a-5795-b6a9-2f50be97117c', 1, $json${"prompt":"Why run 3 etcd members instead of 2?","multiple":false,"options":[{"id":"a","text":"3 members can lose one and keep quorum; 2 members cannot lose any","is_correct":true},{"id":"b","text":"etcd cannot run with 2 members at all","is_correct":false},{"id":"c","text":"Reads are 3x faster","is_correct":false},{"id":"d","text":"kubeadm requires exactly 3","is_correct":false}],"explanation":"Quorum is a majority, floor(n/2)+1."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3c791252-29c0-5125-bc6d-35506fd778ad', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the correct upgrade path from 1.30 to 1.32 on a kubeadm cluster?', 'advanced', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ca7308fb-d34c-5b35-a8f2-79b7352be674', '3c791252-29c0-5125-bc6d-35506fd778ad', 1, $json${"prompt":"What is the correct upgrade path from 1.30 to 1.32 on a kubeadm cluster?","multiple":false,"options":[{"id":"a","text":"1.30 → 1.32 in one step, workers first","is_correct":false},{"id":"b","text":"1.30 → 1.31 → 1.32, control plane first then workers at each step","is_correct":true},{"id":"c","text":"Upgrade only the kubelets","is_correct":false},{"id":"d","text":"Reinstall the cluster on 1.32","is_correct":false}],"explanation":"One minor version at a time, and kubelets must never be newer than the API server."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('878eefda-a2b4-5212-acf8-506318dbbbbc', '00000000-0000-0000-0000-000000000001', 'mcq', 'An HPA shows TARGETS <unknown>. Which two things should you check?', 'intermediate', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2e7e4af9-7941-5134-8c4e-161d4a7fa082', '878eefda-a2b4-5212-acf8-506318dbbbbc', 1, $json${"prompt":"An HPA shows TARGETS \u003cunknown\u003e. Which two things should you check?","multiple":false,"options":[{"id":"a","text":"That metrics-server is installed and the pods have CPU requests","is_correct":true},{"id":"b","text":"That the Service is NodePort and the image is small","is_correct":false},{"id":"c","text":"That etcd has 3 members and Helm is installed","is_correct":false},{"id":"d","text":"That the namespace has a ResourceQuota and a PDB","is_correct":false}],"explanation":"The HPA needs usage metrics and computes utilization against requests."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e9a46c74-1f55-5e02-96f6-e4f9c39c3ab7', '00000000-0000-0000-0000-000000000001', 'mcq', 'A team needs to read pods and logs in namespace team-a only. Which RBAC setup...', 'advanced', 1, ARRAY['kubernetes','k8s','devops','containers','helm','cloud-native','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type, title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('3249fc1f-666e-5133-b6e4-8f746d2ea333', 'e9a46c74-1f55-5e02-96f6-e4f9c39c3ab7', 1, $json${"prompt":"A team needs to read pods and logs in namespace team-a only. Which RBAC setup is right?","multiple":false,"options":[{"id":"a","text":"ClusterRoleBinding to cluster-admin","is_correct":false},{"id":"b","text":"A Role with get/list/watch on pods and pods/log in team-a, bound with a RoleBinding in team-a","is_correct":true},{"id":"c","text":"A ClusterRole bound with a ClusterRoleBinding for all namespaces","is_correct":false},{"id":"d","text":"Give them the kubeadm admin.conf","is_correct":false}],"explanation":"Least privilege, scoped to one namespace."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('ddff4236-5438-5a4c-9a5e-a4844295dcf9', '00000000-0000-0000-0000-000000000001', 'Final Exam: Kubernetes from Zero to Production', 'k8s-interview-prep-quiz', 'Quiz covering Interview Prep & Production Troubleshooting.', 'mcq', 'published', 'module', '41f0d05d-57a8-5380-9c27-c27f7de3119c', 35, 75, 5, 15, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

DELETE FROM assessment_questions WHERE assessment_id = 'ddff4236-5438-5a4c-9a5e-a4844295dcf9' AND question_id NOT IN ('a21affb9-feae-5408-a45c-2bb1795e5a20', '6112872c-a732-592e-8fea-94b3d9f9075a', '596d4539-0763-56c2-8e7f-823632628407', '7b891573-104a-5bb0-aa29-ad469c553aff', '69c93329-2555-5a67-80b8-bc3f4c8ea3a4', 'fda08c20-ed46-5191-b96d-7c745f0f35c1', '2f661d13-98fa-5b88-9138-613564cce077', '3b87a45d-f335-51f4-aa35-231ff310bc76', '060edafb-3eab-5a36-9a0d-7835b16e5c10', 'f02af5af-b019-508b-9c4a-74281c7f2116', '7db2eade-4fff-5a9f-a27f-e610faa2f474', '3c7ccd50-113a-5795-b6a9-2f50be97117c', '3c791252-29c0-5125-bc6d-35506fd778ad', '878eefda-a2b4-5212-acf8-506318dbbbbc', 'e9a46c74-1f55-5e02-96f6-e4f9c39c3ab7');

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('3ae8c829-5047-5d2a-8c75-0864baa94612', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', 'a21affb9-feae-5408-a45c-2bb1795e5a20', 'edf894aa-f1a9-5248-b0bd-7e83ac332614', 0, 1),
('fd5a3fe1-9092-5fda-a0c1-458fec3ac005', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', '6112872c-a732-592e-8fea-94b3d9f9075a', 'e175ebe4-4363-5f07-a876-f81784156e95', 1, 1),
('f4b38470-95e9-51d9-bb3e-4158dc5748b4', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', '596d4539-0763-56c2-8e7f-823632628407', '23345282-ab19-54f4-93de-c23ae5664268', 2, 1),
('659fda1a-97e7-510f-9da8-4d428a2784eb', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', '7b891573-104a-5bb0-aa29-ad469c553aff', '20d47cc7-5604-566a-b223-9d218e387cfc', 3, 1),
('730e1f7c-909d-5a30-874b-d3812b7e7a21', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', '69c93329-2555-5a67-80b8-bc3f4c8ea3a4', '0eace016-f7bb-5293-8d24-e43c110b7d17', 4, 1),
('e8983b40-d9c1-52be-8e0b-dc0344860386', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', 'fda08c20-ed46-5191-b96d-7c745f0f35c1', '54bfd7d4-c045-57f2-909c-68fd33f057d2', 5, 1),
('a734d834-8e88-5be1-a14e-786e265a9476', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', '2f661d13-98fa-5b88-9138-613564cce077', '884e109d-b440-5ab2-aebe-eb4724cc5d0f', 6, 1),
('04109f32-199e-5860-962c-eb74b9e5de70', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', '3b87a45d-f335-51f4-aa35-231ff310bc76', 'f0ef3627-5835-5a1a-a20f-461a6b9e0d17', 7, 1),
('287e5351-da45-5f38-ab96-0bc231cf4afd', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', '060edafb-3eab-5a36-9a0d-7835b16e5c10', 'c2ec1d5f-bf20-5e50-922f-fe4acc446002', 8, 1),
('5afdf119-55e9-5df4-b96c-b99f26daabef', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', 'f02af5af-b019-508b-9c4a-74281c7f2116', '19db18c4-44ec-5889-b2ed-4f309c4c7cfd', 9, 1),
('36620cb9-a7ce-5646-a7ba-737574b196e7', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', '7db2eade-4fff-5a9f-a27f-e610faa2f474', '84ade001-7904-51fc-ae7b-93a62305d186', 10, 1),
('2e5aa706-87b5-5f0e-8ed3-4371d5f4a29a', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', '3c7ccd50-113a-5795-b6a9-2f50be97117c', '75bbf298-a158-59ad-90cf-1dd989b78869', 11, 1),
('ae767045-a1be-5583-b8f7-22b4577bd016', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', '3c791252-29c0-5125-bc6d-35506fd778ad', 'ca7308fb-d34c-5b35-a8f2-79b7352be674', 12, 1),
('d143083f-4c68-5b58-9c69-33482859cf72', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', '878eefda-a2b4-5212-acf8-506318dbbbbc', '2e7e4af9-7941-5134-8c4e-161d4a7fa082', 13, 1),
('f1589942-8bae-52a3-b6d2-2fadadbeb43e', 'ddff4236-5438-5a4c-9a5e-a4844295dcf9', 'e9a46c74-1f55-5e02-96f6-e4f9c39c3ab7', '3249fc1f-666e-5133-b6e4-8f746d2ea333', 14, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('41f0d05d-57a8-5380-9c27-c27f7de3119c', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '050f01cb-eacf-550f-8789-c0f2b5a3fc5e', 'Final Exam: Kubernetes from Zero to Production', 'assessment', 2, 25, 'ddff4236-5438-5a4c-9a5e-a4844295dcf9')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('b76c3962-dcf2-5631-869c-8e2310f740dc', '00000000-0000-0000-0000-000000000014', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

