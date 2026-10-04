---
kind: lesson
id_key: k8s/storage/lesson
course: fast-kubernetes
section: storage
section_title: Storage
section_position: 6
title: Volumes, PersistentVolumes and PersistentVolumeClaims
position: 0
estimated_minutes: 40
source:
  - K8s-PersistantVolume.md
---

A container's own filesystem is thrown away when the container is replaced. That is fine for a web server, but a database that loses its files on every restart is useless. This lesson shows how Kubernetes gives pods storage that outlives them.

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
