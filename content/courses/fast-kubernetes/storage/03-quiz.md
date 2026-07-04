---
kind: quiz
id_key: k8s/storage/quiz
course: fast-kubernetes
section: storage
section_title: Storage
section_position: 5
title: 'Quiz: Storage'
position: 2
estimated_minutes: 15
source: []
pass_percentage: 60
duration_minutes: 15
questions:
    - id_key: q1
      type: mcq
      difficulty: intermediate
      points: 2
      prompt: |
          In the lesson's PV/PVC lab, the mysqlpv PersistentVolume is created with
          `persistentVolumeReclaimPolicy: Retain`. What happens to the underlying storage
          when the bound PersistentVolumeClaim (mysqlclaim) is deleted?
      multiple: false
      options:
          - text: The PV is automatically deleted along with its data
            correct: false
          - text: The PV is not deleted; it enters a Released state and the data is preserved for manual reclamation by an administrator
            correct: true
          - text: The PV is automatically recycled and immediately rebound to a new PVC
            correct: false
          - text: Deleting the PVC has no effect on the PV's lifecycle at all
            correct: false
      explanation: |
          With persistentVolumeReclaimPolicy set to Retain, deleting the PVC does not delete
          the PV or its underlying NFS-backed data. The PV transitions to a Released state and
          must be manually reclaimed (or deleted) by a cluster administrator — this differs from
          the Delete policy, which removes the underlying storage automatically.
    - id_key: q2
      type: mcq
      difficulty: intermediate
      points: 2
      prompt: |
          The lesson's pv.yaml defines `accessModes: - ReadWriteOnce` for the mysqlpv
          PersistentVolume. What does the ReadWriteOnce access mode mean?
      multiple: false
      options:
          - text: The volume can be mounted as read-write by many nodes simultaneously
            correct: false
          - text: The volume can be mounted as read-write by a single node at a time
            correct: true
          - text: The volume can only ever be mounted read-only, by any number of nodes
            correct: false
          - text: The volume can be mounted read-write by one Pod but read-only by all other Pods at the same time
            correct: false
      explanation: |
          ReadWriteOnce (RWO) means the volume can be mounted read-write by a single node at a
          time (multiple Pods on that same node can still share it). The other standard access
          modes are ReadOnlyMany (ROX), for read-only mounts across many nodes, and
          ReadWriteMany (RWX), for read-write mounts across many nodes simultaneously.
    - id_key: q3
      type: mcq
      difficulty: intermediate
      points: 3
      prompt: |
          In the lesson, the PersistentVolumeClaim (mysqlclaim) uses a label selector
          matching `app: mysql` to bind to a specific PersistentVolume. What determines
          that the PVC binds specifically to mysqlpv rather than some other PV in the cluster?
      multiple: false
      options:
          - text: PVCs always bind to the first available PV in creation order; labels are ignored
            correct: false
          - text: The PVC's selector matches the app=mysql label on the PV, and the PV's capacity and access modes satisfy the PVC's request
            correct: true
          - text: Binding requires the PV and PVC to share the exact same metadata.name value
            correct: false
          - text: Binding is decided randomly by the scheduler among all PVs with sufficient capacity
            correct: false
      explanation: |
          A PVC with a label selector only binds to a PV whose labels satisfy that selector
          (here app=mysql) and whose capacity, access modes, and storage class also satisfy the
          PVC's request. This is why mysqlclaim binds specifically to mysqlpv instead of any
          other PersistentVolume that might exist in the cluster.
---
