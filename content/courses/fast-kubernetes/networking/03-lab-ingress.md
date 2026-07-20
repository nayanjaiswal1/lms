---
kind: lab
id_key: k8s/networking/lab-ingress
course: fast-kubernetes
section: networking
section_title: Networking
section_position: 3
title: 'Lab: Ingress'
position: 2
estimated_minutes: 30
source:
    - labs/ingress/appingress.yaml
    - labs/ingress/deploy.yaml
    - labs/ingress/todoingress.yaml
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
    - path: appingress.yaml
      content: "apiVersion: networking.k8s.io/v1\r\nkind: Ingress\r\nmetadata:\r\n  name: appingress\r\n  annotations:\r\n    nginx.ingress.kubernetes.io/rewrite-target: /$1\r\nspec:\r\n  rules:\r\n    - host: webapp.com\r\n      http:\r\n        paths:\r\n          - path: /blue\r\n            pathType: Prefix\r\n            backend:\r\n              service:\r\n                name: bluesvc\r\n                port:\r\n                  number: 80\r\n          - path: /green\r\n            pathType: Prefix\r\n            backend:\r\n              service:\r\n                name: greensvc\r\n                port:\r\n                  number: 80"
    - path: deploy.yaml
      content: "apiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: blueapp\r\n  labels:\r\n    app: blue\r\nspec:\r\n  replicas: 2\r\n  selector:\r\n    matchLabels:\r\n      app: blue\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: blue\r\n    spec:\r\n      containers:\r\n      - name: blueapp\r\n        image: ozgurozturknet/k8s:blue\r\n        ports:\r\n        - containerPort: 80\r\n        livenessProbe:\r\n          httpGet:\r\n            path: /healthcheck\r\n            port: 80\r\n          initialDelaySeconds: 5\r\n          periodSeconds: 5\r\n        readinessProbe:\r\n          httpGet:\r\n            path: /ready\r\n            port: 80\r\n          initialDelaySeconds: 5\r\n          periodSeconds: 3\r\n---\r\napiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  name: bluesvc\r\nspec:\r\n  selector:\r\n    app: blue\r\n  ports:\r\n    - protocol: TCP\r\n      port: 80\r\n      targetPort: 80\r\n---\r\napiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: greenapp\r\n  labels:\r\n    app: green\r\nspec:\r\n  replicas: 2\r\n  selector:\r\n    matchLabels:\r\n      app: green\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: green\r\n    spec:\r\n      containers:\r\n      - name: greenapp\r\n        image: ozgurozturknet/k8s:green\r\n        ports:\r\n        - containerPort: 80\r\n        livenessProbe:\r\n          httpGet:\r\n            path: /healthcheck\r\n            port: 80\r\n          initialDelaySeconds: 5\r\n          periodSeconds: 5\r\n        readinessProbe:\r\n          httpGet:\r\n            path: /ready\r\n            port: 80\r\n          initialDelaySeconds: 5\r\n          periodSeconds: 3\r\n---\r\napiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  name: greensvc\r\nspec:\r\n  selector:\r\n    app: green\r\n  ports:\r\n    - protocol: TCP\r\n      port: 80\r\n      targetPort: 80\r\n---\r\napiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: todoapp\r\n  labels:\r\n    app: todo\r\nspec:\r\n  replicas: 1\r\n  selector:\r\n    matchLabels:\r\n      app: todo\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: todo\r\n    spec:\r\n      containers:\r\n      - name: todoapp\r\n        image: ozgurozturknet/samplewebapp:latest\r\n        ports:\r\n        - containerPort: 80\r\n---\r\napiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  name: todosvc\r\nspec:\r\n  selector:\r\n    app: todo\r\n  ports:\r\n    - protocol: TCP\r\n      port: 80\r\n      targetPort: 80"
    - path: todoingress.yaml
      content: "apiVersion: networking.k8s.io/v1\r\nkind: Ingress\r\nmetadata:\r\n  name: todoingress\r\nspec:\r\n  rules:\r\n    - host: todoapp.com\r\n      http:\r\n        paths:\r\n          - path: /\r\n            pathType: Prefix\r\n            backend:\r\n              service:\r\n                name: todosvc\r\n                port:\r\n                  number: 80"
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/ingress/ for the source manifests this lab is based on
tasks: []
---
