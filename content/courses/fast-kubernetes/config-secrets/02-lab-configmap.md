---
kind: lab
id_key: k8s/config-secrets/lab-configmap
course: fast-kubernetes
section: config-secrets
section_title: Configuration & Secrets
section_position: 4
title: 'Lab: ConfigMap'
position: 1
estimated_minutes: 30
source:
    - labs/configmap/configmap.yaml
    - labs/configmap/theme.txt
lab_type: terminal
environment: mindforge/lab-k8s:1.31
preview_port: 0
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
    - path: configmap.yaml
      content: "apiVersion: v1\r\nkind: ConfigMap\r\nmetadata:\r\n  name: myconfigmap\r\ndata:\r\n  db_server: \"db.example.com\"\r\n  database: \"mydatabase\"\r\n  site.settings: |\r\n    color=blue\r\n    padding:25px\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: configmappod\r\nspec:\r\n  containers:\r\n  - name: configmapcontainer\r\n    image: nginx\r\n    env:\r\n      - name: DB_SERVER\r\n        valueFrom:\r\n          configMapKeyRef:\r\n            name: myconfigmap\r\n            key: db_server\r\n      - name: DATABASE\r\n        valueFrom:\r\n          configMapKeyRef:\r\n            name: myconfigmap\r\n            key: database\r\n    volumeMounts:\r\n      - name: config-vol\r\n        mountPath: \"/config\"\r\n        readOnly: true\r\n  volumes:\r\n    - name: config-vol\r\n      configMap:\r\n        name: myconfigmap"
    - path: theme.txt
      content: theme=dark
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/configmap/ for the source manifests this lab is based on
tasks: []
---
