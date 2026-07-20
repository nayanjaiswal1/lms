---
kind: lab
id_key: k8s/scheduling/lab-liveness
course: fast-kubernetes
section: scheduling
section_title: Health & Scheduling
section_position: 6
title: 'Lab: Liveness Probe'
position: 1
estimated_minutes: 30
source:
    - labs/liveness/liveness.yaml
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
    - path: liveness.yaml
      content: "apiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  labels:\r\n    test: liveness\r\n  name: liveness-http\r\nspec:\r\n  containers:\r\n  - name: liveness\r\n    image: k8s.gcr.io/liveness\r\n    args:\r\n    - /server\r\n    livenessProbe:\r\n      httpGet:\r\n        path: /healthz\r\n        port: 8080\r\n        httpHeaders:\r\n        - name: Custom-Header\r\n          value: Awesome\r\n      initialDelaySeconds: 3\r\n      periodSeconds: 3\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  labels:\r\n    test: liveness\r\n  name: liveness-exec\r\nspec:\r\n  containers:\r\n  - name: liveness\r\n    image: k8s.gcr.io/busybox\r\n    args:\r\n    - /bin/sh\r\n    - -c\r\n    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600\r\n    livenessProbe:\r\n      exec:\r\n        command:\r\n        - cat\r\n        - /tmp/healthy\r\n      initialDelaySeconds: 5\r\n      periodSeconds: 5\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: goproxy\r\n  labels:\r\n    app: goproxy\r\nspec:\r\n  containers:\r\n  - name: goproxy\r\n    image: k8s.gcr.io/goproxy:0.1\r\n    ports:\r\n    - containerPort: 8080\r\n    livenessProbe:\r\n      tcpSocket:\r\n        port: 8080\r\n      initialDelaySeconds: 15\r\n      periodSeconds: 20"
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/liveness/ for the source manifests this lab is based on
tasks: []
---
