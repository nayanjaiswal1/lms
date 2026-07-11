---
kind: lab
id_key: k8s/workloads/lab-job
course: fast-kubernetes
section: workloads
section_title: Workloads & Controllers
section_position: 2
title: 'Lab: Job'
position: 4
estimated_minutes: 30
source:
    - labs/job/job.yaml
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
    - path: job.yaml
      content: "apiVersion: batch/v1\r\nkind: Job\r\nmetadata:\r\n  name: pi\r\nspec:\r\n  parallelism: 2\r\n  completions: 10\r\n  backoffLimit: 5\r\n  activeDeadlineSeconds: 100\r\n  template:\r\n    spec:\r\n      containers:\r\n      - name: pi\r\n        image: perl\r\n        command: [\"perl\",  \"-Mbignum=bpi\", \"-wle\", \"print bpi(2000)\"]\r\n      restartPolicy: Never #OnFailure "
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/job/ for the source manifests this lab is based on
tasks: []
---
