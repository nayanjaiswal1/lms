---
kind: quiz
id_key: k8s/cluster-ops/quiz
course: fast-kubernetes
section: cluster-ops
section_title: 'Real Clusters: Setup, Security and Operations'
section_position: 10
title: 'Quiz: Real Clusters'
position: 3
estimated_minutes: 12
source:
  - K8s-Kubeadm-Cluster-Setup.md
  - K8s-Kubeadm-Cluster-Docker.md
pass_percentage: 70
duration_minutes: 20
questions:
  - id_key: q1
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: Why must containerd be configured with SystemdCgroup = true on a kubeadm cluster?
    options:
      - text: It makes images download faster
        correct: false
      - text: The kubelet uses the systemd cgroup driver, and the runtime must use the same one or pods and the control plane become unstable
        correct: true
      - text: It enables NetworkPolicy
        correct: false
      - text: It is only needed on Windows
        correct: false
    explanation: Mismatched cgroup drivers are a classic cause of random restarts on new kubeadm clusters.
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which command prints a fresh join command for adding a worker node?
    options:
      - text: kubeadm init --join
        correct: false
      - text: kubeadm token create --print-join-command
        correct: true
      - text: kubectl join node
        correct: false
      - text: kubeadm reset
        correct: false
    explanation: Join tokens expire after 24 hours; this creates a new token and prints the full command.
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: A RoleBinding in namespace dev references the ClusterRole admin. What can its subjects do?
    options:
      - text: Administer the whole cluster
        correct: false
      - text: Administer objects in namespace dev only
        correct: true
      - text: Nothing, because the kinds do not match
        correct: false
      - text: Only read objects
        correct: false
    explanation: RoleBindings scope a ClusterRole's permissions to their own namespace.
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: An app never calls the Kubernetes API. What is a good hardening step for its pods?
    options:
      - text: Give it cluster-admin just in case
        correct: false
      - text: Set automountServiceAccountToken false
        correct: true
      - text: Run it as root
        correct: false
      - text: Use hostNetwork
        correct: false
    explanation: Without a mounted token, an attacker in the container cannot use it to talk to the API.
  - id_key: q5
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What does `kubectl drain node1 --ignore-daemonsets` do?
    options:
      - text: Deletes node1 from the cluster
        correct: false
      - text: Marks node1 unschedulable and evicts its pods (except DaemonSet pods) so they move elsewhere
        correct: true
      - text: Restarts all containers on node1
        correct: false
      - text: Upgrades the kubelet
        correct: false
    explanation: Drain prepares a node for maintenance. Uncordon it afterwards.
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: What does a PodDisruptionBudget protect against?
    options:
      - text: Node hardware failures
        correct: false
      - text: Too many pods of an app being evicted at once during voluntary disruptions such as drains and upgrades
        correct: true
      - text: Pods using too much memory
        correct: false
      - text: Image pull errors
        correct: false
    explanation: PDBs only cover voluntary evictions. Crashes and node failures are involuntary.
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: What is the correct order when upgrading a kubeadm cluster by one minor version?
    options:
      - text: Workers first, then the control plane
        correct: false
      - text: Control plane first (kubeadm upgrade apply), then each worker one at a time (drain, upgrade, uncordon)
        correct: true
      - text: All nodes at the same moment
        correct: false
      - text: Only the kubelets need upgrading
        correct: false
    explanation: Kubelets must never be newer than the API server, so the control plane goes first.
  - id_key: q8
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What does an etcd snapshot let you recover?
    options:
      - text: The cluster's objects (Deployments, Services, Secrets, RBAC)
        correct: true
      - text: The files stored in PersistentVolumes
        correct: false
      - text: Container images
        correct: false
      - text: Node operating systems
        correct: false
    explanation: etcd stores the API objects. Volume contents and images need separate backups.
  - id_key: q9
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: A namespace should reject pods that run as root or keep all capabilities. Which built-in feature does this?
    options:
      - text: NetworkPolicy
        correct: false
      - text: Pod Security Admission with enforce=restricted on the namespace
        correct: true
      - text: ResourceQuota
        correct: false
      - text: PodDisruptionBudget
        correct: false
    explanation: Labeling the namespace with the restricted Pod Security Standard makes the API server reject non-compliant pods.
---
