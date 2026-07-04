---
kind: lab
id_key: k8s/storage/lab-persistentvolume
course: fast-kubernetes
section: storage
section_title: Storage
section_position: 5
title: 'Lab: Persistent Volume'
position: 1
estimated_minutes: 30
source:
    - labs/persistentvolume/deploy.yaml
    - labs/persistentvolume/pv.yaml
    - labs/persistentvolume/pvc.yaml
lab_type: terminal
environment: mindforge/lab-k8s:1.31
max_duration: 60
max_resets: 3
hint_penalty_pct: 10
is_required: true
setup_script: |
    #!/bin/bash
    set -euo pipefail
    kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
files:
    - path: deploy.yaml
      content: "apiVersion: v1\r\nkind: Secret\r\nmetadata:\r\n  name: mysqlsecret\r\ntype: Opaque\r\nstringData:\r\n  password: P@ssw0rd!\r\n---\r\napiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: mysqldeployment\r\n  labels:\r\n    app: mysql\r\nspec:\r\n  replicas: 1\r\n  selector:\r\n    matchLabels:\r\n      app: mysql\r\n  strategy:\r\n    type: Recreate\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: mysql\r\n    spec:\r\n      containers:\r\n        - name: mysql\r\n          image: mysql\r\n          ports:\r\n            - containerPort: 3306\r\n          volumeMounts:\r\n            - mountPath: \"/var/lib/mysql\"\r\n              name: mysqlvolume\r\n          env:\r\n            - name: MYSQL_ROOT_PASSWORD\r\n              valueFrom:\r\n                secretKeyRef:\r\n                  name: mysqlsecret\r\n                  key: password\r\n      volumes:\r\n        - name: mysqlvolume\r\n          persistentVolumeClaim:\r\n            claimName: mysqlclaim"
    - path: pv.yaml
      content: "apiVersion: v1\r\nkind: PersistentVolume\r\nmetadata:\r\n   name: mysqlpv\r\n   labels:\r\n     app: mysql\r\nspec:\r\n  capacity:\r\n    storage: 5Gi\r\n  accessModes:\r\n    - ReadWriteOnce\r\n  persistentVolumeReclaimPolicy: Recycle\r\n  nfs:\r\n    path: /\r\n    server: 10.255.255.10"
    - path: pvc.yaml
      content: "apiVersion: v1\r\nkind: PersistentVolumeClaim\r\nmetadata:\r\n  name: mysqlclaim\r\nspec:\r\n  accessModes:\r\n    - ReadWriteOnce\r\n  volumeMode: Filesystem          \r\n  resources:\r\n    requests:\r\n      storage: 5Gi\r\n  storageClassName: \"\"\r\n  selector:\r\n    matchLabels:\r\n      app: mysql"
tasks:
    - id_key: create-mysqlpv
      title: Create the mysqlpv PersistentVolume
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `pv.yaml` (already in your workdir) to create a PersistentVolume named
        **mysqlpv** with **5Gi** capacity, access mode `ReadWriteOnce`, reclaim policy
        `Recycle`, and an NFS backend (`server: 10.255.255.10`, `path: /`).
      verification_script: |
        #!/bin/bash
        kubectl get pv mysqlpv >/dev/null 2>&1 || exit 1
        kubectl get pv mysqlpv -o jsonpath='{.spec.capacity.storage}' | grep -qx 5Gi || exit 1
        kubectl get pv mysqlpv -o jsonpath='{.spec.accessModes[0]}' | grep -qx ReadWriteOnce || exit 1
        kubectl get pv mysqlpv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' | grep -qx Recycle || exit 1
        kubectl get pv mysqlpv -o jsonpath='{.spec.nfs.server}' | grep -qx 10.255.255.10
      hint_context: Use `kubectl apply -f pv.yaml`.
      explanation_context: |
        A PersistentVolume is a cluster-scoped storage resource provisioned ahead of demand
        (static provisioning) — its `capacity`, `accessModes`, and `persistentVolumeReclaimPolicy`
        describe what it offers, and its `nfs` block (or another volume source) describes where
        the bytes actually live. No Pod references a PV directly; a PersistentVolumeClaim does.
      solution_script: kubectl apply -f pv.yaml
    - id_key: create-mysqlclaim
      title: Create the mysqlclaim PersistentVolumeClaim
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `pvc.yaml` to create a PersistentVolumeClaim named **mysqlclaim** requesting
        **5Gi** of `ReadWriteOnce` storage, with `storageClassName: ""` (static provisioning,
        no dynamic provisioner) and a `selector` matching label `app=mysql`.
      verification_script: |
        #!/bin/bash
        kubectl get pvc mysqlclaim >/dev/null 2>&1 || exit 1
        kubectl get pvc mysqlclaim -o jsonpath='{.spec.accessModes[0]}' | grep -qx ReadWriteOnce || exit 1
        kubectl get pvc mysqlclaim -o jsonpath='{.spec.resources.requests.storage}' | grep -qx 5Gi || exit 1
        kubectl get pvc mysqlclaim -o jsonpath='{.spec.selector.matchLabels.app}' | grep -qx mysql
      hint_context: Use `kubectl apply -f pvc.yaml`.
      explanation_context: |
        A PersistentVolumeClaim is a namespaced request for storage — a Pod mounts a PVC, never
        a PV directly. Leaving `storageClassName` empty (rather than omitting it) opts the claim
        out of dynamic provisioning entirely, so it can only bind to a pre-existing PV whose
        capacity, access modes, and (if set) `selector` match.
      solution_script: kubectl apply -f pvc.yaml
    - id_key: verify-pv-pvc-bindable
      title: Confirm mysqlpv and mysqlclaim are compatible for binding
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that **mysqlpv** and **mysqlclaim** are wired to bind to each other: the PV's
        `app` label matches the PVC's `selector.matchLabels.app`, and their capacity and access
        mode agree.

        This lab's control plane does not run the `persistentvolume-binder` controller, so
        `status.phase` never transitions to `Bound` here — this check instead confirms the
        spec-level fields that a running binder controller would use to make that decision.
      verification_script: |
        #!/bin/bash
        PV_LABEL=$(kubectl get pv mysqlpv -o jsonpath='{.metadata.labels.app}' 2>/dev/null)
        PVC_SEL=$(kubectl get pvc mysqlclaim -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
        test -n "$PV_LABEL" && test "$PV_LABEL" = "$PVC_SEL" || exit 1
        PV_CAP=$(kubectl get pv mysqlpv -o jsonpath='{.spec.capacity.storage}' 2>/dev/null)
        PVC_REQ=$(kubectl get pvc mysqlclaim -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
        test -n "$PV_CAP" && test "$PV_CAP" = "$PVC_REQ" || exit 1
        PV_MODE=$(kubectl get pv mysqlpv -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null)
        PVC_MODE=$(kubectl get pvc mysqlclaim -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null)
        test -n "$PV_MODE" && test "$PV_MODE" = "$PVC_MODE"
      hint_context: |
        Compare `kubectl get pv mysqlpv -o jsonpath='{.metadata.labels}'` against
        `kubectl get pvc mysqlclaim -o jsonpath='{.spec.selector}'`, and compare
        `.spec.capacity.storage` / `.spec.resources.requests.storage` on each.
      explanation_context: |
        The PersistentVolumeController binds a PVC to the first PV whose `capacity` is
        sufficient, whose `accessModes` are a superset of the claim's, and whose labels satisfy
        the claim's `selector` (if any) — matching `storageClassName` too. Get any of those wrong
        and a claim sits `Pending` forever even with a PV that looks superficially available.
      solution_script: |
        kubectl get pv mysqlpv -o jsonpath='{.metadata.labels}'
        kubectl get pvc mysqlclaim -o jsonpath='{.spec.selector}'
    - id_key: create-mysqldeployment
      title: Create the mysqldeployment Deployment
      points: 20
      is_optional: false
      is_stateful: true
      description: |
        Apply `deploy.yaml` to create the **mysqlsecret** Secret and the **mysqldeployment**
        Deployment (`strategy.type: Recreate`, image `mysql`) in one shot.
      verification_script: |
        #!/bin/bash
        kubectl get secret mysqlsecret >/dev/null 2>&1 || exit 1
        kubectl get deployment mysqldeployment >/dev/null 2>&1 || exit 1
        kubectl get deployment mysqldeployment -o jsonpath='{.spec.strategy.type}' | grep -qx Recreate || exit 1
        IMAGE=$(kubectl get deployment mysqldeployment -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
        echo "$IMAGE" | grep -q '^mysql' || exit 1
        READY=$(kubectl get deployment mysqldeployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        test "${READY:-0}" -ge 1
      hint_context: Use `kubectl apply -f deploy.yaml`.
      explanation_context: |
        `deploy.yaml` bundles a Secret and a Deployment separated by `---` — `kubectl apply -f`
        creates both together. The `Recreate` strategy matters for anything backed by a
        `ReadWriteOnce` volume: the old Pod is fully terminated (releasing the volume) before a
        replacement is created, avoiding two Pods fighting over the same non-shareable mount.
      solution_script: kubectl apply -f deploy.yaml
    - id_key: verify-deployment-volume-reference
      title: Confirm mysqldeployment correctly mounts mysqlclaim
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that **mysqldeployment**'s Pod template mounts a volume named `mysqlvolume`
        backed by claim `mysqlclaim` at path `/var/lib/mysql`, and that its
        `MYSQL_ROOT_PASSWORD` environment variable is sourced from the `mysqlsecret` Secret.
      verification_script: |
        #!/bin/bash
        CLAIM=$(kubectl get deployment mysqldeployment -o jsonpath='{.spec.template.spec.volumes[?(@.name=="mysqlvolume")].persistentVolumeClaim.claimName}' 2>/dev/null)
        test "$CLAIM" = "mysqlclaim" || exit 1
        MOUNT=$(kubectl get deployment mysqldeployment -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.name=="mysqlvolume")].mountPath}' 2>/dev/null)
        test "$MOUNT" = "/var/lib/mysql" || exit 1
        SECRETREF=$(kubectl get deployment mysqldeployment -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="MYSQL_ROOT_PASSWORD")].valueFrom.secretKeyRef.name}' 2>/dev/null)
        test "$SECRETREF" = "mysqlsecret"
      hint_context: |
        Inspect `.spec.template.spec.volumes` for the `persistentVolumeClaim.claimName`, and each
        container's `.volumeMounts` and `.env` for the matching entries.
      explanation_context: |
        A Pod claims storage by name: `volumes[].persistentVolumeClaim.claimName` points at a
        PVC in the same namespace, and `containers[].volumeMounts[].name` links a container's
        mount path back to that volume entry. A typo in either name silently drops the mount
        instead of failing loudly, which is why this wiring is worth checking explicitly.
      solution_script: kubectl get deployment mysqldeployment -o jsonpath='{.spec.template.spec}'
---
