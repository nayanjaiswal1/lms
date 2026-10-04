---
kind: quiz
id_key: k8s/basics/quiz
course: fast-kubernetes
section: basics
section_title: Kubernetes Basics
section_position: 1
title: 'Quiz: Kubernetes Basics'
position: 1
estimated_minutes: 10
source:
  - README.md
pass_percentage: 70
duration_minutes: 15
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What is the job of the kube-apiserver?
    options:
      - text: It runs containers on each node
        correct: false
      - text: It is the single entry point for every read and write to the cluster state
        correct: true
      - text: It balances network traffic between pods
        correct: false
      - text: It builds container images
        correct: false
    explanation: Every client (kubectl, controllers, the scheduler, kubelets) talks to the API server. It validates requests and is the only component that reads and writes etcd directly.
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which component runs on every worker node and makes sure the pods assigned to that node are running?
    options:
      - text: kube-scheduler
        correct: false
      - text: etcd
        correct: false
      - text: kubelet
        correct: true
      - text: kube-controller-manager
        correct: false
    explanation: The kubelet is the node agent. It watches for pods assigned to its node and asks the container runtime to start and restart their containers.
  - id_key: q3
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What does "desired state" mean in Kubernetes?
    options:
      - text: The state the cluster was in when it was first created
        correct: false
      - text: What you declared you want (for example, 3 replicas), which controllers keep comparing with reality and enforcing
        correct: true
      - text: The fastest possible configuration for your app
        correct: false
      - text: A backup of etcd
        correct: false
    explanation: You declare what you want in spec. Controllers run a reconcile loop that compares desired with actual state and acts whenever they differ.
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 1
    prompt: In a manifest, which field is written by Kubernetes rather than by you?
    options:
      - text: spec
        correct: false
      - text: metadata.name
        correct: false
      - text: kind
        correct: false
      - text: status
        correct: true
    explanation: status reports the actual state and is maintained by the cluster. You write apiVersion, kind, metadata and spec.
  - id_key: q5
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which command lists pods in every namespace?
    options:
      - text: kubectl get pods --all
        correct: false
      - text: kubectl get pods -A
        correct: true
      - text: kubectl get pods -n all
        correct: false
      - text: kubectl get namespaces --pods
        correct: false
    explanation: -A is short for --all-namespaces. -n <name> selects one specific namespace.
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 1
    prompt: How does a Service know which pods to send traffic to?
    options:
      - text: By pod name prefix
        correct: false
      - text: By matching its label selector against pod labels
        correct: true
      - text: By creation time
        correct: false
      - text: It sends traffic to every pod in the namespace
        correct: false
    explanation: Selectors match labels. Deployments find their pods and Services find their backends the same way.
  - id_key: q7
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What does `kubectl create deployment web --image=nginx --dry-run=client -o yaml` do?
    options:
      - text: Creates the deployment and prints it
        correct: false
      - text: Prints the YAML for the deployment without creating anything in the cluster
        correct: true
      - text: Validates an existing deployment called web
        correct: false
      - text: Deletes the deployment and prints its last YAML
        correct: false
    explanation: --dry-run=client builds the object on your machine only. It is the usual way to generate a starting manifest.
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: Which of these objects is cluster-wide, meaning it does not belong to any namespace?
    options:
      - text: Pod
        correct: false
      - text: Service
        correct: false
      - text: Node
        correct: true
      - text: ConfigMap
        correct: false
    explanation: Nodes, PersistentVolumes, Namespaces and StorageClasses are cluster-scoped. `kubectl api-resources --namespaced=false` lists them all.
---
