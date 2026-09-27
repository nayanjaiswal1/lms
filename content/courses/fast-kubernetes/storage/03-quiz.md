---
kind: quiz
id_key: k8s/storage/quiz
course: fast-kubernetes
section: storage
section_title: Storage
section_position: 6
title: 'Quiz: Storage'
position: 2
estimated_minutes: 10
source:
  - K8s-PersistantVolume.md
pass_percentage: 70
duration_minutes: 15
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which object does a pod reference to use persistent storage?
    options:
      - text: The PersistentVolume, by name
        correct: false
      - text: The PersistentVolumeClaim, by name
        correct: true
      - text: The StorageClass
        correct: false
      - text: The node's disk path
        correct: false
    explanation: Pods reference claims. The claim is bound to a PV, which hides the storage details.
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which of these is namespaced?
    options:
      - text: PersistentVolume
        correct: false
      - text: StorageClass
        correct: false
      - text: PersistentVolumeClaim
        correct: true
      - text: Node
        correct: false
    explanation: PVCs live in a namespace next to the pods that use them. PVs and StorageClasses are cluster-wide.
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: A PVC stays Pending and no StorageClass provisioner exists. Which is a likely cause?
    options:
      - text: No PV offers enough capacity with a matching access mode and storage class
        correct: true
      - text: The pod has too many containers
        correct: false
      - text: The namespace has no Service
        correct: false
      - text: The PVC name is too long
        correct: false
    explanation: Static binding needs a PV that satisfies size, access mode, class, and any label selector.
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which access mode lets pods on several nodes write to the same volume?
    options:
      - text: ReadWriteOnce
        correct: false
      - text: ReadOnlyMany
        correct: false
      - text: ReadWriteMany
        correct: true
      - text: ReadWriteOncePod
        correct: false
    explanation: RWX allows read-write from many nodes; the backend (for example NFS) must support it.
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: What does the Retain reclaim policy do when the PVC is deleted?
    options:
      - text: Deletes the disk immediately
        correct: false
      - text: Keeps the PV and its data; the PV becomes Released and must be handled by an admin
        correct: true
      - text: Binds the PV to the next PVC automatically
        correct: false
      - text: Wipes the data but keeps the PV Available
        correct: false
    explanation: Retain protects the data. A Released PV is not reused until an admin cleans it up.
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What does a StorageClass enable?
    options:
      - text: Dynamic provisioning, where a PV is created automatically for each matching PVC
        correct: true
      - text: Encryption of Secrets
        correct: false
      - text: Sharing emptyDir between pods
        correct: false
      - text: Faster container startup
        correct: false
    explanation: The StorageClass's provisioner (a CSI driver) creates volumes on demand.
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: Can you shrink a PVC from 20Gi to 10Gi by editing it?
    options:
      - text: Yes, always
        correct: false
      - text: No; volumes can only be expanded (if the StorageClass allows it), never shrunk
        correct: true
      - text: Yes, but only for NFS
        correct: false
      - text: Only by deleting the StorageClass
        correct: false
    explanation: allowVolumeExpansion lets you grow a claim. Shrinking is not supported; copy the data to a new, smaller volume instead.
---
