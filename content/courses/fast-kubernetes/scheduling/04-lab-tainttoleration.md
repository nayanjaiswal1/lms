---
kind: lab
id_key: k8s/scheduling/lab-tainttoleration
course: fast-kubernetes
section: scheduling
section_title: Health & Scheduling
section_position: 6
title: 'Lab: Taint & Toleration'
position: 3
estimated_minutes: 30
source:
    - labs/tainttoleration/podtoleration.yaml
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
    - path: podtoleration.yaml
      content: "apiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: toleratedpod1\r\n  labels:\r\n    env: test\r\nspec:\r\n  containers:\r\n  - name: toleratedcontainer1\r\n    image: nginx:latest\r\n  tolerations:\r\n  - key: \"platform\"\r\n    operator: \"Equal\"\r\n    value: \"production\"\r\n    effect: \"NoSchedule\"\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: toleratedpod2\r\n  labels:\r\n    env: test\r\nspec:\r\n  containers:\r\n  - name: toleratedcontainer2\r\n    image: nginx\r\n  tolerations:\r\n  - key: \"platform\"\r\n    operator: \"Exists\"\r\n    effect: \"NoSchedule\""
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/tainttoleration/ for the source manifests this lab is based on
tasks: []
---
