---
kind: lab
id_key: k8s/networking/lab-service
course: fast-kubernetes
section: networking
section_title: Networking
section_position: 3
title: 'Lab: Service'
position: 1
estimated_minutes: 30
source:
    - labs/service/backend_clusterip.yaml
    - labs/service/backend_loadbalancer.yaml
    - labs/service/backend_nodeport.yaml
    - labs/service/deploy.yaml
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
    - path: backend_clusterip.yaml
      content: "apiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  name: backend\r\nspec:\r\n  type: ClusterIP\r\n  selector:\r\n    app: backend\r\n  ports:\r\n    - protocol: TCP\r\n      port: 5000\r\n      targetPort: 5000"
    - path: backend_loadbalancer.yaml
      content: "apiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  name: frontendlb\r\nspec:\r\n  type: LoadBalancer\r\n  selector:\r\n    app: frontend\r\n  ports:\r\n    - protocol: TCP\r\n      port: 80\r\n      targetPort: 80"
    - path: backend_nodeport.yaml
      content: "apiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  name: frontend\r\nspec:\r\n  type: NodePort\r\n  selector:\r\n    app: frontend\r\n  ports:\r\n    - protocol: TCP\r\n      port: 80\r\n      targetPort: 80"
    - path: deploy.yaml
      content: "apiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: frontend\r\n  labels:\r\n    team: development\r\nspec:\r\n  replicas: 3\r\n  selector:\r\n    matchLabels:\r\n      app: frontend\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: frontend\r\n    spec:\r\n      containers:\r\n      - name: frontend\r\n        image: nginx:latest\r\n        ports:\r\n        - containerPort: 80\r\n---\r\napiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: backend\r\n  labels:\r\n    team: development\r\nspec:\r\n  replicas: 3\r\n  selector:\r\n    matchLabels:\r\n      app: backend\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: backend\r\n    spec:\r\n      containers:\r\n      - name: backend\r\n        image: ozgurozturknet/k8s:backend\r\n        ports:\r\n        - containerPort: 5000"
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/service/ for the source manifests this lab is based on
tasks: []
---
