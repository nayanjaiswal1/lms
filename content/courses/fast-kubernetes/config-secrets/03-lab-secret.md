---
kind: lab
id_key: k8s/config-secrets/lab-secret
course: fast-kubernetes
section: config-secrets
section_title: Configuration & Secrets
section_position: 4
title: 'Lab: Secret'
position: 2
estimated_minutes: 30
source:
    - labs/secret/config.json
    - labs/secret/password.txt
    - labs/secret/secret-pods.yaml
    - labs/secret/secret.yaml
    - labs/secret/server.txt
    - labs/secret/username.txt
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
    - path: config.json
      content: "{\r\n    \"apiKey\": \"6bba108d4b2212f2c30c71dfa279e1f77cc5c3b2\",\r\n}"
    - path: password.txt
      content: P@ssw0rd!
    - path: secret-pods.yaml
      content: "apiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: secretvolumepod\r\nspec:\r\n  containers:\r\n  - name: secretcontainer\r\n    image: nginx\r\n    volumeMounts:\r\n    - name: secret-vol\r\n      mountPath: /secret\r\n  volumes:\r\n  - name: secret-vol\r\n    secret:\r\n      secretName: mysecret\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: secretenvpod\r\nspec:\r\n  containers:\r\n  - name: secretcontainer\r\n    image: nginx\r\n    env:\r\n      - name: username\r\n        valueFrom:\r\n          secretKeyRef:\r\n            name: mysecret\r\n            key: db_username\r\n      - name: password\r\n        valueFrom:\r\n          secretKeyRef:\r\n            name: mysecret\r\n            key: db_password\r\n      - name: server\r\n        valueFrom:\r\n          secretKeyRef:\r\n            name: mysecret\r\n            key: db_server\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: secretenvallpod\r\nspec:\r\n  containers:\r\n  - name: secretcontainer\r\n    image: nginx\r\n    envFrom:\r\n    - secretRef:\r\n        name: mysecret"
    - path: secret.yaml
      content: "apiVersion: v1\r\nkind: Secret\r\nmetadata:\r\n  name: mysecret\r\ntype: Opaque\r\nstringData:\r\n  db_server: db.example.com\r\n  db_username: admin\r\n  db_password: P@ssw0rd!"
    - path: server.txt
      content: db.example.com
    - path: username.txt
      content: admin
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/secret/ for the source manifests this lab is based on
tasks: []
---
