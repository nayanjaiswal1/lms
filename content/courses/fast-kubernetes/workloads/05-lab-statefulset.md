---
kind: lab
id_key: k8s/workloads/lab-statefulset
course: fast-kubernetes
section: workloads
section_title: Deployments & Workload Controllers
section_position: 3
title: 'Lab: StatefulSet'
position: 4
estimated_minutes: 25
source:
  - labs/statefulset/statefulset.yaml
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
  - path: pvs.yaml
    content: |
      # This sandbox has no storage provisioner, so we create the disks (PersistentVolumes)
      # up front. On a cloud cluster a StorageClass creates them on demand.
      apiVersion: v1
      kind: PersistentVolume
      metadata:
        name: pv-1
      spec:
        capacity:
          storage: 1Gi
        accessModes: ["ReadWriteOnce"]
        hostPath:
          path: /data/pv-1
      ---
      apiVersion: v1
      kind: PersistentVolume
      metadata:
        name: pv-2
      spec:
        capacity:
          storage: 1Gi
        accessModes: ["ReadWriteOnce"]
        hostPath:
          path: /data/pv-2
      ---
      apiVersion: v1
      kind: PersistentVolume
      metadata:
        name: pv-3
      spec:
        capacity:
          storage: 1Gi
        accessModes: ["ReadWriteOnce"]
        hostPath:
          path: /data/pv-3
      ---
      apiVersion: v1
      kind: PersistentVolume
      metadata:
        name: pv-4
      spec:
        capacity:
          storage: 1Gi
        accessModes: ["ReadWriteOnce"]
        hostPath:
          path: /data/pv-4
  - path: statefulset.yaml
    content: |
      apiVersion: v1
      kind: Service
      metadata:
        name: nginx
        labels:
          app: nginx
      spec:
        ports:
        - port: 80
          name: web
        clusterIP: None
        selector:
          app: nginx
      ---
      apiVersion: apps/v1
      kind: StatefulSet
      metadata:
        name: web
      spec:
        serviceName: nginx
        replicas: 3
        selector:
          matchLabels:
            app: nginx
        template:
          metadata:
            labels:
              app: nginx
          spec:
            containers:
            - name: nginx
              image: nginx:1.27
              ports:
              - containerPort: 80
                name: web
              volumeMounts:
              - name: www
                mountPath: /usr/share/nginx/html
        volumeClaimTemplates:
        - metadata:
            name: www
          spec:
            accessModes: ["ReadWriteOnce"]
            resources:
              requests:
                storage: 512Mi
tasks:
  - id_key: create-pvs
    title: Create the disks
    points: 5
    is_stateful: true
    description: Apply `pvs.yaml` and check `kubectl get pv`. All four should be `Available`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get pv pv-1 pv-2 pv-3 pv-4 --no-headers 2>/dev/null | wc -l)" = "4"
    hint_context: "`kubectl apply -f pvs.yaml`"
    explanation_context: A PersistentVolume is a piece of storage in the cluster. The storage section covers them in detail.
    solution_script: kubectl apply -f pvs.yaml
  - id_key: create-statefulset
    title: Create the StatefulSet
    points: 15
    is_stateful: true
    description: Apply `statefulset.yaml`. Look at the pod names (`kubectl get pods`) and the claims (`kubectl get pvc`). Notice the pattern `web-0`, `web-1`, `web-2` and `www-web-0`, `www-web-1`, `www-web-2`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get statefulset web -o jsonpath='{.status.readyReplicas}')" = "3" || exit 1
      for i in 0 1 2; do kubectl get pvc www-web-$i -o jsonpath='{.status.phase}' | grep -qx Bound || exit 1; done
      kubectl get svc nginx -o jsonpath='{.spec.clusterIP}' | grep -qx None
    hint_context: "`kubectl apply -f statefulset.yaml`, then `kubectl get pods,pvc`"
    explanation_context: Each pod got a stable numbered name and its own PVC from the volumeClaimTemplate. The headless Service (clusterIP None) gives each pod a DNS name like web-0.nginx.
    solution_script: kubectl apply -f statefulset.yaml
  - id_key: scale-up-sts
    title: Scale up
    points: 10
    is_stateful: true
    description: Scale the StatefulSet `web` to 4 replicas. What is the new pod called?
    verification_script: |
      #!/bin/bash
      kubectl get pod web-3 -o jsonpath='{.status.phase}' | grep -qx Running && kubectl get pvc www-web-3 >/dev/null 2>&1
    hint_context: "`kubectl scale statefulset web --replicas=4`"
    explanation_context: The next number is used (web-3), never a random name, and it gets its own claim www-web-3.
    solution_script: kubectl scale statefulset web --replicas=4
  - id_key: scale-down-keeps-pvc
    title: Scale down and keep the data
    points: 15
    is_stateful: true
    description: Scale `web` down to 2 replicas. Which pods were removed? Now check `kubectl get pvc`. Were any claims deleted?
    verification_script: |
      #!/bin/bash
      ! kubectl get pod web-2 >/dev/null 2>&1 || exit 1
      ! kubectl get pod web-3 >/dev/null 2>&1 || exit 1
      kubectl get pvc www-web-2 www-web-3 >/dev/null 2>&1
    hint_context: Scale the same way. Scaling down removes the highest numbers first.
    explanation_context: web-3 and web-2 were removed (highest first), but their claims still exist. Scale back up and those pods get their old data back.
    solution_script: |
      kubectl scale statefulset web --replicas=2
      for i in $(seq 1 30); do kubectl get pod web-2 >/dev/null 2>&1 || break; sleep 1; done
  - id_key: stable-identity
    title: Delete a pod and check its identity
    points: 15
    is_stateful: false
    description: Delete pod `web-0`. When it comes back, check its name and which claim it uses with `kubectl get pod web-0 -o yaml | grep claimName`.
    verification_script: |
      #!/bin/bash
      S=$(kubectl get statefulset web -o jsonpath='{.metadata.creationTimestamp}')
      P=$(kubectl get pod web-0 -o jsonpath='{.metadata.creationTimestamp}')
      [ $(( $(date -d "$P" +%s) - $(date -d "$S" +%s) )) -ge 3 ] || exit 1
      kubectl get pod web-0 -o jsonpath='{.spec.volumes[?(@.name=="www")].persistentVolumeClaim.claimName}' | grep -qx www-web-0
    hint_context: "`kubectl delete pod web-0`"
    explanation_context: The new pod has the same name (web-0) and reattached the same claim (www-web-0). This stable identity is what databases need.
    solution_script: |
      sleep 3
      kubectl delete pod web-0 --wait=false
---
