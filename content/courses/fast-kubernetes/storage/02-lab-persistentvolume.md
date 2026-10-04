---
kind: lab
id_key: k8s/storage/lab-persistentvolume
course: fast-kubernetes
section: storage
section_title: Storage
section_position: 6
title: 'Lab: PersistentVolumes and Claims'
position: 1
estimated_minutes: 25
source:
  - labs/persistentvolume/pv.yaml
  - labs/persistentvolume/pvc.yaml
  - labs/persistentvolume/deploy.yaml
lab_type: terminal
environment: mindforge/lab-k8s:1.31
max_duration: 45
max_resets: 3
hint_penalty_pct: 10
is_required: true
setup_script: |
  #!/bin/bash
  set -euo pipefail
  kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
files:
  - path: pv.yaml
    content: |
      apiVersion: v1
      kind: PersistentVolume
      metadata:
        name: mysqlpv
        labels:
          app: mysql
      spec:
        capacity:
          storage: 5Gi
        accessModes:
        - ReadWriteOnce
        persistentVolumeReclaimPolicy: Retain
        nfs:
          path: /
          server: 10.255.255.10
  - path: pvc.yaml
    content: |
      apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: mysqlclaim
      spec:
        accessModes:
        - ReadWriteOnce
        volumeMode: Filesystem
        resources:
          requests:
            storage: 5Gi
        storageClassName: ""
        selector:
          matchLabels:
            app: mysql
  - path: deploy.yaml
    content: |
      apiVersion: v1
      kind: Secret
      metadata:
        name: mysqlsecret
      type: Opaque
      stringData:
        password: P@ssw0rd!
      ---
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: mysqldeployment
        labels:
          app: mysql
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: mysql
        strategy:
          type: Recreate
        template:
          metadata:
            labels:
              app: mysql
          spec:
            containers:
            - name: mysql
              image: mysql:8.4
              ports:
              - containerPort: 3306
              volumeMounts:
              - mountPath: "/var/lib/mysql"
                name: mysqlvolume
              env:
              - name: MYSQL_ROOT_PASSWORD
                valueFrom:
                  secretKeyRef:
                    name: mysqlsecret
                    key: password
            volumes:
            - name: mysqlvolume
              persistentVolumeClaim:
                claimName: mysqlclaim
  - path: bigclaim.yaml
    content: |
      # This claim stays Pending. Find out why.
      apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: bigclaim
      spec:
        accessModes:
        - ReadWriteMany
        resources:
          requests:
            storage: 50Gi
        storageClassName: ""
tasks:
  - id_key: create-pv
    title: Create a PersistentVolume
    points: 10
    is_stateful: true
    description: Apply `pv.yaml` and run `kubectl get pv`. What is its STATUS? Notice that PVs are cluster-wide, so `-n` does not apply to them.
    verification_script: |
      #!/bin/bash
      kubectl get pv mysqlpv -o jsonpath='{.spec.capacity.storage} {.spec.persistentVolumeReclaimPolicy}' | grep -qx '5Gi Retain'
    hint_context: "`kubectl apply -f pv.yaml`"
    explanation_context: The PV is Available, meaning it exists but no claim uses it yet.
    solution_script: kubectl apply -f pv.yaml
  - id_key: bind-pvc
    title: Claim it
    points: 15
    is_stateful: true
    description: Apply `pvc.yaml`. Check `kubectl get pv,pvc`. Both should now show `Bound`, and the claim's VOLUME column should name `mysqlpv`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get pvc mysqlclaim -o jsonpath='{.status.phase} {.spec.volumeName}')" = "Bound mysqlpv"
    hint_context: "`kubectl apply -f pvc.yaml`"
    explanation_context: The claim asked for 5Gi, RWO, no storage class, and a PV labeled app=mysql. mysqlpv matched all four, so they were bound one-to-one.
    solution_script: kubectl apply -f pvc.yaml
  - id_key: deploy-mysql
    title: Run MySQL on the claim
    points: 15
    is_stateful: true
    description: Apply `deploy.yaml` (a Secret plus a MySQL Deployment). Use `kubectl describe pod -l app=mysql` and find the `Volumes:` section. Which claim does it use?
    verification_script: |
      #!/bin/bash
      test "$(kubectl get deployment mysqldeployment -o jsonpath='{.status.readyReplicas}')" = "1" || exit 1
      kubectl get pods -l app=mysql -o jsonpath='{.items[0].spec.volumes[?(@.name=="mysqlvolume")].persistentVolumeClaim.claimName}' | grep -qx mysqlclaim
    hint_context: "`kubectl apply -f deploy.yaml`"
    explanation_context: The pod only knows the claim name. Where the data really lives (here an NFS share) is hidden behind the PV.
    solution_script: kubectl apply -f deploy.yaml
  - id_key: pod-replaced-same-claim
    title: Replace the pod and keep the storage
    points: 10
    is_stateful: true
    description: Delete the MySQL pod. When the Deployment creates a new one, check that it mounts the same claim and that the PVC is still Bound to the same PV.
    verification_script: |
      #!/bin/bash
      D=$(date -d "$(kubectl get deployment mysqldeployment -o jsonpath='{.metadata.creationTimestamp}')" +%s)
      P=$(date -d "$(kubectl get pods -l app=mysql -o jsonpath='{.items[0].metadata.creationTimestamp}')" +%s)
      [ $((P - D)) -ge 3 ] || exit 1
      test "$(kubectl get pvc mysqlclaim -o jsonpath='{.status.phase} {.spec.volumeName}')" = "Bound mysqlpv"
    hint_context: "`kubectl delete pod -l app=mysql`"
    explanation_context: The new pod mounted the same claim, so on a real cluster MySQL would find all its data again.
    solution_script: |
      sleep 3
      kubectl delete pod -l app=mysql --wait=false
  - id_key: debug-pending-claim
    title: Debug a Pending claim
    points: 20
    is_stateful: false
    description: |
      Apply `bigclaim.yaml`. It stays `Pending`. Run `kubectl describe pvc bigclaim` to see why. Then create a PV named `bigpv` that it **can** bind to (use `hostPath: {path: /data/big}` as the storage backend) and check that the claim becomes `Bound`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get pvc bigclaim -o jsonpath='{.status.phase} {.spec.volumeName}')" = "Bound bigpv"
    hint_context: The claim needs at least 50Gi, access mode ReadWriteMany, and no storage class. Your PV must offer all of that.
    explanation_context: A claim binds only when a PV satisfies size, access mode and storage class. mysqlpv was too small, RWO only, and already bound, so nothing matched until you added a suitable PV.
    solution_script: |
      kubectl apply -f bigclaim.yaml
      cat > bigpv.yaml <<'Y'
      apiVersion: v1
      kind: PersistentVolume
      metadata:
        name: bigpv
      spec:
        capacity:
          storage: 50Gi
        accessModes:
        - ReadWriteMany
        hostPath:
          path: /data/big
      Y
      kubectl apply -f bigpv.yaml
  - id_key: retain-policy
    title: See what Retain does
    points: 10
    is_stateful: false
    description: Delete the Deployment `mysqldeployment` and then the claim `mysqlclaim`. Check `kubectl get pv mysqlpv`. What is its STATUS now, and does a new claim get it automatically?
    verification_script: |
      #!/bin/bash
      ! kubectl get pvc mysqlclaim >/dev/null 2>&1 || exit 1
      test "$(kubectl get pv mysqlpv -o jsonpath='{.status.phase}')" = "Released"
    hint_context: "`kubectl delete deployment mysqldeployment`, then `kubectl delete pvc mysqlclaim`."
    explanation_context: With Retain, the PV and its data are kept but the PV becomes Released and is not reused. An admin decides what to do with the data. With Delete, the disk would have been destroyed.
    solution_script: |
      kubectl delete deployment mysqldeployment
      kubectl delete pvc mysqlclaim --wait=false
---
