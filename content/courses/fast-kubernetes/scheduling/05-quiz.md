---
kind: quiz
id_key: k8s/scheduling/quiz
course: fast-kubernetes
section: scheduling
section_title: Health, Resources & Scheduling
section_position: 7
title: 'Quiz: Health, Resources & Scheduling'
position: 4
estimated_minutes: 12
source:
  - K8s-Liveness-App.md
  - K8s-Node-Affinity.md
  - K8s-Taint-Toleration.md
pass_percentage: 70
duration_minutes: 20
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What does Kubernetes do when a liveness probe keeps failing?
    options:
      - text: Removes the pod from Service endpoints
        correct: false
      - text: Restarts the container
        correct: true
      - text: Moves the pod to another node
        correct: false
      - text: Nothing
        correct: false
    explanation: Liveness failures restart the container. Readiness failures only remove the pod from endpoints.
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: During a rolling update, why does a readiness probe make the update safer?
    options:
      - text: It makes images download faster
        correct: false
      - text: New pods only receive traffic, and only count as available, once they report ready
        correct: true
      - text: It prevents old pods from being deleted
        correct: false
      - text: It increases maxSurge
        correct: false
    explanation: Without readiness, a pod is considered ready as soon as its container starts, even if the app cannot serve yet.
  - id_key: q3
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What does `cpu 500m` mean?
    options:
      - text: 500 CPU cores
        correct: false
      - text: Half of one CPU core
        correct: true
      - text: 500 megabytes
        correct: false
      - text: 500 milliseconds per request
        correct: false
    explanation: m means millicores; 1000m is one core.
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which setting does the scheduler use to decide whether a pod fits on a node?
    options:
      - text: Resource limits
        correct: false
      - text: Resource requests
        correct: true
      - text: The image size
        correct: false
      - text: The number of labels
        correct: false
    explanation: Scheduling is based on requests. Limits are enforced later, at runtime.
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: A node runs out of memory. Pods of which QoS class are evicted first?
    options:
      - text: Guaranteed
        correct: false
      - text: Burstable
        correct: false
      - text: BestEffort
        correct: true
      - text: All at the same time
        correct: false
    explanation: BestEffort pods (no requests or limits) go first, Guaranteed pods last.
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: What is the difference between required and preferred node affinity?
    options:
      - text: Required must be satisfied or the pod stays Pending; preferred is a wish the scheduler tries to honor
        correct: true
      - text: Required is checked continuously; preferred only once
        correct: false
      - text: Preferred evicts running pods
        correct: false
      - text: There is no difference
        correct: false
    explanation: required... is a hard constraint, preferred... is weighted scoring.
  - id_key: q7
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which taint effect also evicts pods that are already running on the node?
    options:
      - text: NoSchedule
        correct: false
      - text: PreferNoSchedule
        correct: false
      - text: NoExecute
        correct: true
      - text: NoRestart
        correct: false
    explanation: NoExecute blocks new pods and evicts running pods without a matching toleration.
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: You want GPU nodes used only by ML pods, and ML pods to run only on GPU nodes. What do you need?
    options:
      - text: Only a toleration on the ML pods
        correct: false
      - text: A taint on the GPU nodes plus a toleration and node affinity on the ML pods
        correct: true
      - text: Only node affinity on the ML pods
        correct: false
      - text: A DaemonSet for the ML pods
        correct: false
    explanation: The taint keeps other pods off, the toleration lets ML pods on, and node affinity makes ML pods go there.
---
