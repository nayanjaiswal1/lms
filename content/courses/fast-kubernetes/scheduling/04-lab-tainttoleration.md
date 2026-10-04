---
kind: lab
id_key: k8s/scheduling/lab-tainttoleration
course: fast-kubernetes
section: scheduling
section_title: Health, Resources & Scheduling
section_position: 7
title: 'Lab: Taints and Tolerations'
position: 3
estimated_minutes: 25
source:
  - labs/tainttoleration/podtoleration.yaml
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
  - path: podtoleration.yaml
    content: |
      apiVersion: v1
      kind: Pod
      metadata:
        name: toleratedpod1
        labels:
          env: test
      spec:
        containers:
        - name: toleratedcontainer1
          image: nginx:1.27
        tolerations:
        - key: "app"
          operator: "Equal"
          value: "production"
          effect: "NoSchedule"
      ---
      apiVersion: v1
      kind: Pod
      metadata:
        name: toleratedpod2
        labels:
          env: test
      spec:
        containers:
        - name: toleratedcontainer2
          image: nginx:1.27
        tolerations:
        - key: "app"
          operator: "Exists"
          effect: "NoSchedule"
tasks:
  - id_key: taint-node
    title: Taint the node
    points: 10
    is_stateful: true
    description: Check the node's taints with `kubectl describe node kwok-node | grep Taints`. Then add the taint `app=production:NoSchedule`.
    verification_script: |
      #!/bin/bash
      kubectl get node kwok-node -o jsonpath='{range .spec.taints[*]}{.key}={.value}:{.effect}{"\n"}{end}' | grep -qx 'app=production:NoSchedule'
    hint_context: "`kubectl taint node <node> key=value:Effect`"
    explanation_context: From now on, new pods without a matching toleration cannot be scheduled on kwok-node.
    solution_script: kubectl taint node kwok-node app=production:NoSchedule
  - id_key: untolerated-pending
    title: Watch an untolerated pod wait
    points: 10
    is_stateful: true
    description: Run a plain pod `test` from `nginx:1.27`. It stays `Pending`. Read why in `kubectl describe pod test`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get pod test -o jsonpath='{.status.phase}')" = "Pending" || exit 1
      kubectl get pod test -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")].message}' | grep -qi taint
    hint_context: "`kubectl run test --image=nginx:1.27`"
    explanation_context: The only node has a taint the pod does not tolerate, so the scheduler reports "untolerated taint" and the pod waits.
    solution_script: kubectl run test --image=nginx:1.27
  - id_key: tolerated-pods
    title: Run pods that tolerate the taint
    points: 15
    is_stateful: true
    description: Apply `podtoleration.yaml`. Both pods should run while `test` keeps waiting. Compare the two tolerations. One uses `Equal`, the other `Exists`.
    verification_script: |
      #!/bin/bash
      for p in toleratedpod1 toleratedpod2; do
        test "$(kubectl get pod $p -o jsonpath='{.status.phase}')" = "Running" || exit 1
      done
      test "$(kubectl get pod test -o jsonpath='{.status.phase}')" = "Pending"
    hint_context: "`kubectl apply -f podtoleration.yaml`"
    explanation_context: toleratedpod1 matches key, value and effect exactly (Equal). toleratedpod2 tolerates any value of the key app (Exists).
    solution_script: kubectl apply -f podtoleration.yaml
  - id_key: noexecute-evicts
    title: Evict running pods with NoExecute
    points: 20
    is_stateful: true
    description: |
      Add a second taint `version=new:NoExecute` to `kwok-node`. Watch `kubectl get pods`: the running pods do not tolerate this one. What happens to them?
    verification_script: |
      #!/bin/bash
      kubectl get node kwok-node -o jsonpath='{range .spec.taints[*]}{.key}:{.effect}{"\n"}{end}' | grep -qx 'version:NoExecute' || exit 1
      ! kubectl get pod toleratedpod1 >/dev/null 2>&1 && ! kubectl get pod toleratedpod2 >/dev/null 2>&1
    hint_context: Same `kubectl taint` command with the NoExecute effect. Give it a few seconds.
    explanation_context: NoExecute evicts running pods that do not tolerate it. NoSchedule never touches pods that are already running. Bare pods are gone after eviction; pods from a Deployment would be recreated on another node.
    solution_script: |
      kubectl taint node kwok-node version=new:NoExecute
      for i in $(seq 1 30); do kubectl get pod toleratedpod1 >/dev/null 2>&1 || break; sleep 1; done
  - id_key: remove-taints
    title: Remove the taints
    points: 10
    is_stateful: false
    description: Remove both taints from `kwok-node`. The `test` pod that was Pending should now be scheduled.
    verification_script: |
      #!/bin/bash
      test -z "$(kubectl get node kwok-node -o jsonpath='{.spec.taints}')" || exit 1
      test "$(kubectl get pod test -o jsonpath='{.status.phase}')" = "Running"
    hint_context: "`kubectl taint node kwok-node app-` removes every taint with key app. Do the same for version."
    explanation_context: With no taints left, the scheduler placed the pending pod. A pending pod is retried automatically; you never have to recreate it.
    solution_script: |
      kubectl taint node kwok-node app-
      kubectl taint node kwok-node version-
---
