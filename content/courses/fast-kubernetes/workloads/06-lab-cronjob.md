---
kind: lab
id_key: k8s/workloads/lab-cronjob
course: fast-kubernetes
section: workloads
section_title: Workloads & Controllers
section_position: 2
title: 'Lab: CronJob'
position: 5
estimated_minutes: 30
source:
    - labs/cronjob/cronjob.yaml
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
    - path: cronjob.yaml
      content: "# https://crontab.guru/\r\napiVersion: batch/v1\r\nkind: CronJob\r\nmetadata:\r\n  name: hello\r\nspec:\r\n  schedule: \"*/1 * * * *\"\r\n  jobTemplate:\r\n    spec:\r\n      template:\r\n        spec:\r\n          containers:\r\n          - name: hello\r\n            image: busybox\r\n            imagePullPolicy: IfNotPresent\r\n            command:\r\n            - /bin/sh\r\n            - -c\r\n            - date; echo Hello from the Kubernetes cluster\r\n          restartPolicy: OnFailure"
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/cronjob/ for the source manifests this lab is based on
tasks: []
---
