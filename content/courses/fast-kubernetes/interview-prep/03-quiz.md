---
kind: quiz
id_key: k8s/interview-prep/quiz
course: fast-kubernetes
section: interview-prep
section_title: Interview Prep & Production Troubleshooting
section_position: 12
title: 'Final Exam: Kubernetes from Zero to Production'
position: 2
estimated_minutes: 25
source:
  - README.md
pass_percentage: 75
duration_minutes: 35
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which component is the only one that talks to etcd directly?
    options:
      - text: kubelet
        correct: false
      - text: kube-apiserver
        correct: true
      - text: kube-scheduler
        correct: false
      - text: kube-proxy
        correct: false
    explanation: Every other component goes through the API server.
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 1
    prompt: You deleted a pod that belongs to a Deployment with 3 replicas. What happens?
    options:
      - text: The Deployment now has 2 replicas
        correct: false
      - text: The ReplicaSet creates a replacement pod to get back to 3
        correct: true
      - text: The Deployment is deleted too
        correct: false
      - text: The node restarts
        correct: false
    explanation: The desired state is still 3, so the controller recreates the missing pod.
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: New pods of a rollout are Running but never get traffic, and the rollout does not progress. What is the most likely reason?
    options:
      - text: The readiness probe is failing
        correct: true
      - text: The liveness probe is missing
        correct: false
      - text: The Service type is ClusterIP
        correct: false
      - text: The image is too small
        correct: false
    explanation: Pods that never become ready are not added to endpoints and do not count as available, so the rollout waits.
  - id_key: q4
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: Which workload gives each replica a stable name and its own PersistentVolumeClaim?
    options:
      - text: Deployment
        correct: false
      - text: DaemonSet
        correct: false
      - text: StatefulSet
        correct: true
      - text: Job
        correct: false
    explanation: StatefulSets use volumeClaimTemplates and ordinal names.
  - id_key: q5
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What is the full DNS name of Service api in namespace prod?
    options:
      - text: api.prod.svc.cluster.local
        correct: true
      - text: prod.api.cluster.local
        correct: false
      - text: api.svc.prod
        correct: false
      - text: api.cluster.prod.local
        correct: false
    explanation: <service>.<namespace>.svc.<cluster-domain>, usually cluster.local.
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: A container's CPU usage goes above its CPU limit. What happens?
    options:
      - text: It is OOMKilled
        correct: false
      - text: It is throttled
        correct: true
      - text: It is moved to another node
        correct: false
      - text: Nothing
        correct: false
    explanation: CPU is compressible and gets throttled; memory is not and gets OOMKilled.
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: Which is true about Kubernetes Secrets by default?
    options:
      - text: They are encrypted with a cluster key
        correct: false
      - text: They are base64-encoded and must be protected with RBAC and encryption at rest
        correct: true
      - text: They cannot be read once created
        correct: false
      - text: They are stored only on nodes, not in etcd
        correct: false
    explanation: base64 is encoding. Restrict access and enable encryption at rest.
  - id_key: q8
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: A PVC with storageClassName fast-ssd stays Pending in a cluster without that StorageClass. What is the fix?
    options:
      - text: Edit storageClassName on the existing PVC
        correct: false
      - text: Recreate the PVC with an existing class (or "" to bind a pre-created PV), since the field is immutable
        correct: true
      - text: Restart the kubelet
        correct: false
      - text: Add a toleration
        correct: false
    explanation: PVC classes cannot be changed after creation.
  - id_key: q9
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: What does a taint with effect NoExecute do to running pods that do not tolerate it?
    options:
      - text: Nothing
        correct: false
      - text: Evicts them
        correct: true
      - text: Restarts their containers
        correct: false
      - text: Lowers their priority
        correct: false
    explanation: NoExecute both blocks scheduling and evicts non-tolerating pods.
  - id_key: q10
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: An Ingress has no ADDRESS and routes nothing. What is most likely missing?
    options:
      - text: An ingress controller, or the correct ingressClassName
        correct: true
      - text: A StatefulSet
        correct: false
      - text: A ConfigMap
        correct: false
      - text: A PodDisruptionBudget
        correct: false
    explanation: Ingress objects are only rules; a controller implements them.
  - id_key: q11
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: What is the purpose of a PodDisruptionBudget?
    options:
      - text: Limit how many pods of an app voluntary disruptions (drains, upgrades) may take down at once
        correct: true
      - text: Limit CPU usage
        correct: false
      - text: Prevent node crashes
        correct: false
      - text: Schedule pods on specific nodes
        correct: false
    explanation: PDBs protect availability during planned maintenance.
  - id_key: q12
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: Why run 3 etcd members instead of 2?
    options:
      - text: 3 members can lose one and keep quorum; 2 members cannot lose any
        correct: true
      - text: etcd cannot run with 2 members at all
        correct: false
      - text: Reads are 3x faster
        correct: false
      - text: kubeadm requires exactly 3
        correct: false
    explanation: Quorum is a majority, floor(n/2)+1.
  - id_key: q13
    type: mcq
    difficulty: advanced
    points: 1
    prompt: What is the correct upgrade path from 1.30 to 1.32 on a kubeadm cluster?
    options:
      - text: 1.30 → 1.32 in one step, workers first
        correct: false
      - text: 1.30 → 1.31 → 1.32, control plane first then workers at each step
        correct: true
      - text: Upgrade only the kubelets
        correct: false
      - text: Reinstall the cluster on 1.32
        correct: false
    explanation: One minor version at a time, and kubelets must never be newer than the API server.
  - id_key: q14
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: An HPA shows TARGETS <unknown>. Which two things should you check?
    options:
      - text: That metrics-server is installed and the pods have CPU requests
        correct: true
      - text: That the Service is NodePort and the image is small
        correct: false
      - text: That etcd has 3 members and Helm is installed
        correct: false
      - text: That the namespace has a ResourceQuota and a PDB
        correct: false
    explanation: The HPA needs usage metrics and computes utilization against requests.
  - id_key: q15
    type: mcq
    difficulty: advanced
    points: 1
    prompt: A team needs to read pods and logs in namespace team-a only. Which RBAC setup is right?
    options:
      - text: ClusterRoleBinding to cluster-admin
        correct: false
      - text: A Role with get/list/watch on pods and pods/log in team-a, bound with a RoleBinding in team-a
        correct: true
      - text: A ClusterRole bound with a ClusterRoleBinding for all namespaces
        correct: false
      - text: Give them the kubeadm admin.conf
        correct: false
    explanation: Least privilege, scoped to one namespace.
---
