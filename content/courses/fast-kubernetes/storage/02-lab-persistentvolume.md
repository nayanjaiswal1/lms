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
preview_port: 0
workspace_layout: ""
run_script: ""
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
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/persistentvolume/ for the source manifests this lab is based on
tasks: []
---
