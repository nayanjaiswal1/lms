---
kind: lab
id_key: k8s/pod-fundamentals/lab-pod
course: fast-kubernetes
section: pod-fundamentals
section_title: Pod Fundamentals
section_position: 1
title: 'Lab: Pod'
position: 1
estimated_minutes: 30
source:
    - labs/pod/multicontainer.yaml
    - labs/pod/pod1.yaml
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
    - path: multicontainer.yaml
      content: "apiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: multicontainer\r\nspec:\r\n  containers:\r\n  - name: webcontainer\r\n    image: nginx\r\n    ports:\r\n      - containerPort: 80\r\n    volumeMounts:\r\n    - name: sharedvolume\r\n      mountPath: /usr/share/nginx/html\r\n  - name: sidecarcontainer\r\n    image: busybox\r\n    command: [\"/bin/sh\"]\r\n    args: [\"-c\", \"while true; do wget -O /var/log/index.html https://raw.githubusercontent.com/omerbsezer/Fast-Kubernetes/main/index.html; sleep 15; done\"]\r\n    volumeMounts:\r\n    - name: sharedvolume\r\n      mountPath: /var/log\r\n  volumes:\r\n  - name: sharedvolume\r\n    emptyDir: {}"
    - path: pod1.yaml
      content: "apiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: firstpod\r\n  labels:\r\n    app: frontend\r\nspec:\r\n  containers:\r\n  - name: nginx\r\n    image: nginx:latest\r\n    ports:\r\n    - containerPort: 80\r\n    env: \r\n    - name: USER    \r\n      value: \"username\""
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/pod/ for the source manifests this lab is based on
tasks: []
---
