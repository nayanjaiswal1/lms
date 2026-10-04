---
kind: lesson
id_key: k8s/networking/lesson
course: fast-kubernetes
section: networking
section_title: Services & Networking
section_position: 4
title: Services, DNS and Ingress
position: 0
estimated_minutes: 55
source:
  - K8s-Service-App.md
  - K8s-Ingress.md
---

Pods get a new IP address every time they are recreated, and a Deployment may have many of them. So how does a frontend find its backend, and how do users on the internet reach your app? This lesson answers both: **Services** inside the cluster and **Ingress** (or Gateway API) at the edge.

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

**ExternalName**: no pods at all. A DNS alias to an outside name, for example `externalName: db.example.com`.

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
