---
kind: lab
id_key: k8s/workloads/lab-deployment
course: fast-kubernetes
section: workloads
section_title: Workloads & Controllers
section_position: 2
title: 'Lab: Deployment'
position: 1
estimated_minutes: 30
source:
    - labs/deployment/deployment1.yaml
    - labs/deployment/recreate-deployment.yaml
    - labs/deployment/rolling-deployment.yaml
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
    - path: deployment1.yaml
      content: "apiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: firstdeployment\r\n  labels:\r\n    team: development\r\nspec:\r\n  replicas: 3\r\n  selector:\r\n    matchLabels:\r\n      app: frontend\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: frontend\r\n    spec:\r\n      containers:\r\n      - name: nginx\r\n        image: nginx:latest\r\n        ports:\r\n        - containerPort: 80"
    - path: recreate-deployment.yaml
      content: "apiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: rcdeployment\r\n  labels:\r\n    team: development\r\nspec:\r\n  replicas: 5\r\n  selector:\r\n    matchLabels:\r\n      app: recreate\r\n  strategy:\r\n    type: Recreate\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: recreate\r\n    spec:\r\n      containers:\r\n      - name: nginx\r\n        image: nginx\r\n        ports:\r\n        - containerPort: 80"
    - path: rolling-deployment.yaml
      content: "apiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: rolldeployment\r\n  labels:\r\n    team: development\r\nspec:\r\n  replicas: 10\r\n  selector:\r\n    matchLabels:\r\n      app: rolling\r\n  strategy:\r\n    type: RollingUpdate\r\n    rollingUpdate:\r\n      maxUnavailable: 2\r\n      maxSurge: 2\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: rolling\r\n    spec:\r\n      containers:\r\n      - name: nginx\r\n        image: nginx\r\n        ports:\r\n        - containerPort: 80"
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/deployment/ for the source manifests this lab is based on
tasks: []
---
