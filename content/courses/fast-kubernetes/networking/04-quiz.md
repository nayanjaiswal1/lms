---
kind: quiz
id_key: k8s/networking/quiz
course: fast-kubernetes
section: networking
section_title: Services & Networking
section_position: 4
title: 'Quiz: Services & Networking'
position: 3
estimated_minutes: 10
source:
  - K8s-Service-App.md
  - K8s-Ingress.md
pass_percentage: 70
duration_minutes: 15
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What is the main job of a Service?
    options:
      - text: To build container images
        correct: false
      - text: To give a changing group of pods one stable IP address and DNS name
        correct: true
      - text: To store configuration files
        correct: false
      - text: To schedule pods on nodes
        correct: false
    explanation: Pods come and go with new IPs. A Service selects them by label and gives clients a fixed address.
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which Service type is the default?
    options:
      - text: NodePort
        correct: false
      - text: LoadBalancer
        correct: false
      - text: ClusterIP
        correct: true
      - text: ExternalName
        correct: false
    explanation: ClusterIP is the default and is only reachable inside the cluster.
  - id_key: q3
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What port range does Kubernetes use for NodePort by default?
    options:
      - text: 1–1024
        correct: false
      - text: 8000–9000
        correct: false
      - text: 30000–32767
        correct: true
      - text: Any port
        correct: false
    explanation: NodePorts are allocated from 30000–32767 unless the cluster is configured otherwise.
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: A pod in namespace `shop` calls `http://payments`. The payments Service is in namespace `billing`. What happens?
    options:
      - text: It works, because DNS searches all namespaces
        correct: false
      - text: It fails to resolve; the pod must use payments.billing (or the full name)
        correct: true
      - text: It reaches a random Service called payments
        correct: false
      - text: Kubernetes blocks cross-namespace calls
        correct: false
    explanation: Short names resolve within the caller's own namespace. Use <service>.<namespace> across namespaces.
  - id_key: q5
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What must be running in the cluster for Ingress rules to route real traffic?
    options:
      - text: An ingress controller
        correct: true
      - text: A DaemonSet named ingress
        correct: false
      - text: CoreDNS only
        correct: false
      - text: A StatefulSet for each backend
        correct: false
    explanation: Ingress objects are only rules. An ingress controller (Traefik, HAProxy, a cloud controller, ...) reads them and routes traffic.
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: Which Ingress rule sends every URL of shop.com to the Service shop-svc?
    options:
      - text: host shop.com, path /, pathType Prefix, backend shop-svc
        correct: true
      - text: host shop.com, path /*, pathType Exact, backend shop-svc
        correct: false
      - text: host *, path shop.com, backend shop-svc
        correct: false
      - text: host shop-svc, path /, backend shop.com
        correct: false
    explanation: Prefix / matches every path. Exact would only match the literal path.
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: In Gateway API, which object defines the routing rules that attach to a Gateway?
    options:
      - text: GatewayClass
        correct: false
      - text: HTTPRoute
        correct: true
      - text: IngressClass
        correct: false
      - text: EndpointSlice
        correct: false
    explanation: GatewayClass picks the implementation, Gateway is the entry point, and HTTPRoute holds the rules.
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: Without any NetworkPolicy, what traffic between pods is allowed?
    options:
      - text: None
        correct: false
      - text: Only traffic within one namespace
        correct: false
      - text: All pod-to-pod traffic in the cluster
        correct: true
      - text: Only traffic through Services
        correct: false
    explanation: Kubernetes networking is open by default. NetworkPolicies (enforced by the network plugin) restrict it.
---
