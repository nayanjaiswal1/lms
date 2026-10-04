---
kind: lab
id_key: k8s/scheduling/lab-affinity
course: fast-kubernetes
section: scheduling
section_title: Health, Resources & Scheduling
section_position: 7
title: 'Lab: Node Selection and Affinity'
position: 2
estimated_minutes: 25
source:
  - labs/affinity/podnodeaffinity.yaml
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
  - path: podnodeaffinity.yaml
    content: |
      apiVersion: v1
      kind: Pod
      metadata:
        name: nodeaffinitypod1
      spec:
        containers:
        - name: nodeaffinity1
          image: nginx:1.27
        affinity:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
              - matchExpressions:
                - key: app
                  operator: In
                  values:
                  - production
      ---
      apiVersion: v1
      kind: Pod
      metadata:
        name: nodeaffinitypod2
      spec:
        containers:
        - name: nodeaffinity2
          image: nginx:1.27
        affinity:
          nodeAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 1
              preference:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - production
            - weight: 2
              preference:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - test
      ---
      apiVersion: v1
      kind: Pod
      metadata:
        name: nodeaffinitypod3
      spec:
        containers:
        - name: nodeaffinity3
          image: nginx:1.27
        affinity:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
              - matchExpressions:
                - key: app
                  operator: Exists
tasks:
  - id_key: apply-affinity-pods
    title: Create pods with affinity rules
    points: 10
    is_stateful: true
    description: |
      Apply `podnodeaffinity.yaml` and run `kubectl get pods`. Two pods stay `Pending` and one runs. Use `kubectl describe pod nodeaffinitypod1` to read why.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get pod nodeaffinitypod1 -o jsonpath='{.status.phase}')" = "Pending" || exit 1
      test "$(kubectl get pod nodeaffinitypod3 -o jsonpath='{.status.phase}')" = "Pending" || exit 1
      test "$(kubectl get pod nodeaffinitypod2 -o jsonpath='{.status.phase}')" = "Running"
    hint_context: "`kubectl apply -f podnodeaffinity.yaml`"
    explanation_context: Pods 1 and 3 have required rules (app=production, and any app label) that no node satisfies yet. Pod 2 only has preferences, so it runs anywhere.
    solution_script: kubectl apply -f podnodeaffinity.yaml
  - id_key: label-node-production
    title: Label the node so the pending pods can run
    points: 15
    is_stateful: true
    description: Add the label `app=production` to `kwok-node` and watch the two pending pods get scheduled.
    verification_script: |
      #!/bin/bash
      for p in nodeaffinitypod1 nodeaffinitypod3; do
        test "$(kubectl get pod $p -o jsonpath='{.status.phase}')" = "Running" || exit 1
      done
    hint_context: "`kubectl label node kwok-node app=production`"
    explanation_context: Pod 1 needed app In (production) and pod 3 needed the key app to exist. The new label satisfies both, so the scheduler placed them.
    solution_script: kubectl label node kwok-node app=production
  - id_key: remove-label-ignored
    title: Remove the label again
    points: 10
    is_stateful: true
    description: Remove the `app` label from `kwok-node`. Are the pods evicted?
    verification_script: |
      #!/bin/bash
      test -z "$(kubectl get node kwok-node -o jsonpath='{.metadata.labels.app}')" || exit 1
      test "$(kubectl get pod nodeaffinitypod1 -o jsonpath='{.status.phase}')" = "Running"
    hint_context: "`kubectl label node kwok-node app-` (the trailing minus removes a label)"
    explanation_context: The rules end in IgnoredDuringExecution, so they are only checked at scheduling time. Running pods stay where they are.
    solution_script: kubectl label node kwok-node app-
  - id_key: nodeselector-pod
    title: Use a nodeSelector
    points: 15
    is_stateful: false
    description: |
      Label `kwok-node` with `disktype=ssd`. Then create a pod `ssd-pod` (image `nginx:1.27`) that may only run on nodes with that label, using `nodeSelector`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get pod ssd-pod -o jsonpath='{.spec.nodeSelector.disktype} {.spec.nodeName} {.status.phase}')" = "ssd kwok-node Running"
    hint_context: "`nodeSelector:` goes under the pod's `spec`, with `disktype: ssd` below it."
    explanation_context: nodeSelector is the simple form of required node affinity. Every listed label must be present on the node.
    solution_script: |
      kubectl label node kwok-node disktype=ssd
      cat > ssd-pod.yaml <<'Y'
      apiVersion: v1
      kind: Pod
      metadata:
        name: ssd-pod
      spec:
        nodeSelector:
          disktype: ssd
        containers:
        - name: nginx
          image: nginx:1.27
      Y
      kubectl apply -f ssd-pod.yaml
---
