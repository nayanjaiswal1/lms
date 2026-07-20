---
kind: lab
id_key: k8s/scheduling/lab-affinity
course: fast-kubernetes
section: scheduling
section_title: Health & Scheduling
section_position: 6
title: 'Lab: Node Affinity'
position: 2
estimated_minutes: 30
source:
    - labs/affinity/podnodeaffinity.yaml
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
    - path: podnodeaffinity.yaml
      content: "apiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: nodeaffinitypod1\r\nspec:\r\n  containers:\r\n  - name: nodeaffinity1\r\n    image: nginx:latest\r\n  affinity:\r\n    nodeAffinity:\r\n      requiredDuringSchedulingIgnoredDuringExecution:\r\n        nodeSelectorTerms:\r\n        - matchExpressions:\r\n          - key: app\r\n            operator: In #In, NotIn, Exists, DoesNotExist\r\n            values:\r\n            - production\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: nodeaffinitypod2\r\nspec:\r\n  containers:\r\n  - name: nodeaffinity2\r\n    image: nginx:latest\r\n  affinity:\r\n    nodeAffinity:\r\n      preferredDuringSchedulingIgnoredDuringExecution:\r\n      - weight: 1\r\n        preference:\r\n          matchExpressions:\r\n          - key: app\r\n            operator: In\r\n            values:\r\n            - production\r\n      - weight: 2\r\n        preference:\r\n          matchExpressions:\r\n          - key: app\r\n            operator: In\r\n            values:\r\n            - test\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: nodeaffinitypod3\r\nspec:\r\n  containers:\r\n  - name: nodeaffinity3\r\n    image: nginx:latest\r\n  affinity:\r\n    nodeAffinity:\r\n      requiredDuringSchedulingIgnoredDuringExecution:\r\n        nodeSelectorTerms:\r\n        - matchExpressions:\r\n          - key: app\r\n            operator: Exists #In, NotIn, Exists, DoesNotExist"
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/affinity/ for the source manifests this lab is based on
tasks: []
---
