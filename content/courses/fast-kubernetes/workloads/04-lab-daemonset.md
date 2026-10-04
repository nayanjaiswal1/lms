---
kind: lab
id_key: k8s/workloads/lab-daemonset
course: fast-kubernetes
section: workloads
section_title: Deployments & Workload Controllers
section_position: 3
title: 'Lab: DaemonSet'
position: 3
estimated_minutes: 20
source:
  - labs/daemonset/daemonset.yaml
lab_type: terminal
environment: mindforge/lab-k8s:1.31
max_duration: 45
max_resets: 3
hint_penalty_pct: 10
is_required: true
setup_script: |
  #!/bin/bash
  set -euo pipefail
  kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
files:
  - path: daemonset.yaml
    content: |
      apiVersion: apps/v1
      kind: DaemonSet
      metadata:
        name: logdaemonset
        labels:
          app: fluentd-logging
      spec:
        selector:
          matchLabels:
            name: fluentd-elasticsearch
        template:
          metadata:
            labels:
              name: fluentd-elasticsearch
          spec:
            tolerations:
            - key: node-role.kubernetes.io/control-plane
              effect: NoSchedule
            containers:
            - name: fluentd-elasticsearch
              image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
              resources:
                limits:
                  memory: 200Mi
                requests:
                  cpu: 100m
                  memory: 200Mi
              volumeMounts:
              - name: varlog
                mountPath: /var/log
              - name: varlibdockercontainers
                mountPath: /var/lib/docker/containers
                readOnly: true
            terminationGracePeriodSeconds: 30
            volumes:
            - name: varlog
              hostPath:
                path: /var/log
            - name: varlibdockercontainers
              hostPath:
                path: /var/lib/docker/containers
  - path: node2.yaml
    content: |
      # A simulated worker node. In a real cluster a node joins with `kubeadm join`;
      # here we register a fake one so you can watch the DaemonSet react.
      apiVersion: v1
      kind: Node
      metadata:
        name: node2
        labels:
          kubernetes.io/hostname: node2
          kubernetes.io/os: linux
          type: kwok
        annotations:
          kwok.x-k8s.io/node: fake
      status:
        allocatable:
          cpu: "8"
          memory: 32Gi
          pods: "110"
        capacity:
          cpu: "8"
          memory: 32Gi
          pods: "110"
tasks:
  - id_key: create-daemonset
    title: Create the DaemonSet
    points: 10
    is_stateful: true
    description: Apply `daemonset.yaml`. Run `kubectl get daemonset` and `kubectl get pods -o wide`. How many pods are there, and on which node?
    verification_script: |
      #!/bin/bash
      test "$(kubectl get daemonset logdaemonset -o jsonpath='{.status.numberReady}')" = "1"
    hint_context: "`kubectl apply -f daemonset.yaml`"
    explanation_context: The cluster has one node, so the DaemonSet runs exactly one pod. There is no replicas field; the number of nodes decides.
    solution_script: kubectl apply -f daemonset.yaml
  - id_key: add-node
    title: Add a node and watch the DaemonSet follow
    points: 15
    is_stateful: true
    description: Register a second node with `kubectl apply -f node2.yaml`. Wait a few seconds, then check `kubectl get nodes` and `kubectl get pods -o wide` again.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get daemonset logdaemonset -o jsonpath='{.status.numberReady}')" = "2" || exit 1
      kubectl get pods -l name=fluentd-elasticsearch -o jsonpath='{.items[*].spec.nodeName}' | grep -q node2
    hint_context: Apply the node file, then give the DaemonSet controller a few seconds.
    explanation_context: As soon as node2 was Ready, the DaemonSet controller created a pod for it. You did not change the DaemonSet at all.
    solution_script: kubectl apply -f node2.yaml
  - id_key: delete-ds-pod
    title: Delete a DaemonSet pod
    points: 10
    is_stateful: false
    description: Delete the DaemonSet pod that runs on `node2` and check that a new one is created on the same node.
    verification_script: |
      #!/bin/bash
      P=$(kubectl get pods -l name=fluentd-elasticsearch --field-selector spec.nodeName=node2 -o jsonpath='{.items[0].metadata.creationTimestamp}')
      N=$(kubectl get node node2 -o jsonpath='{.metadata.creationTimestamp}')
      test -n "$P" && [ $(( $(date -d "$P" +%s) - $(date -d "$N" +%s) )) -ge 3 ]
    hint_context: "`kubectl get pods -o wide` shows the node of each pod; then `kubectl delete pod <name>`."
    explanation_context: The DaemonSet saw node2 without its pod and created a new one there.
    solution_script: |
      sleep 4
      kubectl delete $(kubectl get pods -l name=fluentd-elasticsearch --field-selector spec.nodeName=node2 -o name | head -1) --wait=false
---
