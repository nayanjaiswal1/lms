---
kind: lab
id_key: k8s/workloads/lab-daemonset
course: fast-kubernetes
section: workloads
section_title: Workloads & Controllers
section_position: 2
title: 'Lab: DaemonSet'
position: 2
estimated_minutes: 30
source:
    - labs/daemonset/daemonset.yaml
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
    - path: daemonset.yaml
      content: "apiVersion: apps/v1\r\nkind: DaemonSet\r\nmetadata:\r\n  name: logdaemonset\r\n  labels:\r\n    app: fluentd-logging\r\nspec:\r\n  selector:\r\n    matchLabels:\r\n      name: fluentd-elasticsearch\r\n  template:\r\n    metadata:\r\n      labels:\r\n        name: fluentd-elasticsearch\r\n    spec:\r\n      tolerations:\r\n      # this toleration is to have the daemonset runnable on master nodes\r\n      # remove it if your masters can't run pods\r\n      - key: node-role.kubernetes.io/master\r\n        effect: NoSchedule\r\n      containers:\r\n      - name: fluentd-elasticsearch\r\n        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2\r\n        resources:\r\n          limits:\r\n            memory: 200Mi\r\n          requests:\r\n            cpu: 100m\r\n            memory: 200Mi\r\n        volumeMounts:\r\n        - name: varlog\r\n          mountPath: /var/log\r\n        - name: varlibdockercontainers\r\n          mountPath: /var/lib/docker/containers\r\n          readOnly: true\r\n      terminationGracePeriodSeconds: 30\r\n      volumes:\r\n      - name: varlog\r\n        hostPath:\r\n          path: /var/log\r\n      - name: varlibdockercontainers\r\n        hostPath:\r\n          path: /var/lib/docker/containers"
# TODO(authoring): add tasks — see content/fast-kubernetes/labs/daemonset/ for the source manifests this lab is based on
tasks: []
---
