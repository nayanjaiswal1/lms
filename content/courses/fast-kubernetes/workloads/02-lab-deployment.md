---
kind: lab
id_key: k8s/workloads/lab-deployment
course: fast-kubernetes
section: workloads
section_title: Workloads & Controllers
section_position: 2
title: 'Lab: Deployment'
position: 1
estimated_minutes: 30
source:
    - labs/deployment/deployment1.yaml
    - labs/deployment/recreate-deployment.yaml
    - labs/deployment/rolling-deployment.yaml
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
    - path: deployment1.yaml
      content: "apiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: firstdeployment\r\n  labels:\r\n    team: development\r\nspec:\r\n  replicas: 3\r\n  selector:\r\n    matchLabels:\r\n      app: frontend\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: frontend\r\n    spec:\r\n      containers:\r\n      - name: nginx\r\n        image: nginx:latest\r\n        ports:\r\n        - containerPort: 80"
    - path: recreate-deployment.yaml
      content: "apiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: rcdeployment\r\n  labels:\r\n    team: development\r\nspec:\r\n  replicas: 5\r\n  selector:\r\n    matchLabels:\r\n      app: recreate\r\n  strategy:\r\n    type: Recreate\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: recreate\r\n    spec:\r\n      containers:\r\n      - name: nginx\r\n        image: nginx\r\n        ports:\r\n        - containerPort: 80"
    - path: rolling-deployment.yaml
      content: "apiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: rolldeployment\r\n  labels:\r\n    team: development\r\nspec:\r\n  replicas: 10\r\n  selector:\r\n    matchLabels:\r\n      app: rolling\r\n  strategy:\r\n    type: RollingUpdate\r\n    rollingUpdate:\r\n      maxUnavailable: 2\r\n      maxSurge: 2\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: rolling\r\n    spec:\r\n      containers:\r\n      - name: nginx\r\n        image: nginx\r\n        ports:\r\n        - containerPort: 80"
tasks:
    - id_key: create-firstdeployment
      title: Create the firstdeployment Deployment
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `deployment1.yaml` (already in your workdir) to create a Deployment named
        **firstdeployment** with **3 replicas**, image `nginx:latest`, and label `app=frontend`.
      verification_script: |
        #!/bin/bash
        kubectl get deployment firstdeployment >/dev/null 2>&1 || exit 1
        READY=$(kubectl get deployment firstdeployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        test "${READY:-0}" -ge 3
      hint_context: Use `kubectl apply -f deployment1.yaml`.
      explanation_context: |
        `kubectl apply` reconciles the cluster to match the manifest declaratively. The
        Deployment controller creates a ReplicaSet, which creates 3 Pods matching the
        `app=frontend` selector.
      solution_script: kubectl apply -f deployment1.yaml
    - id_key: create-rcdeployment
      title: Create the rcdeployment Deployment (Recreate strategy)
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `recreate-deployment.yaml` to create a Deployment named **rcdeployment** with
        **5 replicas** and `strategy.type: Recreate`.
      verification_script: |
        #!/bin/bash
        kubectl get deployment rcdeployment >/dev/null 2>&1 || exit 1
        kubectl get deployment rcdeployment -o jsonpath='{.spec.strategy.type}' | grep -q Recreate || exit 1
        READY=$(kubectl get deployment rcdeployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        test "${READY:-0}" -ge 5
      hint_context: Use `kubectl apply -f recreate-deployment.yaml`.
      explanation_context: |
        The `Recreate` strategy kills every existing Pod before creating replacements — unlike
        `RollingUpdate`, there is a window with zero available Pods, but it guarantees no two
        versions ever run simultaneously.
      solution_script: kubectl apply -f recreate-deployment.yaml
    - id_key: create-rolldeployment
      title: Create the rolldeployment Deployment (RollingUpdate strategy)
      points: 20
      is_optional: false
      is_stateful: true
      description: |
        Apply `rolling-deployment.yaml` to create a Deployment named **rolldeployment** with
        **10 replicas** and a `RollingUpdate` strategy configured with `maxSurge: 2` and
        `maxUnavailable: 2`.
      verification_script: |
        #!/bin/bash
        kubectl get deployment rolldeployment >/dev/null 2>&1 || exit 1
        kubectl get deployment rolldeployment -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' | grep -qx 2 || exit 1
        kubectl get deployment rolldeployment -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' | grep -qx 2 || exit 1
        READY=$(kubectl get deployment rolldeployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        test "${READY:-0}" -ge 10
      hint_context: Use `kubectl apply -f rolling-deployment.yaml`.
      explanation_context: |
        `maxSurge` caps how many extra Pods above the desired count may exist during a rollout;
        `maxUnavailable` caps how many desired Pods may be missing. Both default to 25% when
        unset — this manifest sets them explicitly to absolute counts instead.
      solution_script: kubectl apply -f rolling-deployment.yaml
    - id_key: scale-firstdeployment
      title: Scale firstdeployment down to 1 replica
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Scale the **firstdeployment** Deployment down to **1 replica** using `kubectl scale`.
      verification_script: |
        #!/bin/bash
        DESIRED=$(kubectl get deployment firstdeployment -o jsonpath='{.spec.replicas}' 2>/dev/null)
        READY=$(kubectl get deployment firstdeployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        test "${DESIRED:-0}" -eq 1 && test "${READY:-0}" -le 1
      hint_context: Use `kubectl scale deployment firstdeployment --replicas=1`.
      explanation_context: |
        Scaling updates `.spec.replicas`; the Deployment controller adjusts the ReplicaSet's
        replica count, which schedules or terminates Pods to match.
      solution_script: kubectl scale deployment firstdeployment --replicas=1
    - id_key: rollout-firstdeployment
      title: Roll out a new image on firstdeployment
      points: 20
      is_optional: false
      is_stateful: true
      description: |
        Update `firstdeployment`'s container image to `nginx:1.27` and wait for the rollout to
        finish. Use `kubectl set image` and `kubectl rollout status`.
      verification_script: |
        #!/bin/bash
        IMAGE=$(kubectl get deployment firstdeployment -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
        test "$IMAGE" = "nginx:1.27" || exit 1
        kubectl rollout status deployment/firstdeployment --timeout=30s >/dev/null 2>&1
      hint_context: |
        Use `kubectl set image deployment/firstdeployment nginx=nginx:1.27`, then
        `kubectl rollout status deployment/firstdeployment`.
      explanation_context: |
        `kubectl set image` patches `.spec.template.spec.containers[].image`, which changes the
        Pod template hash and triggers a new ReplicaSet. `kubectl rollout status` blocks until
        the new ReplicaSet is fully available — the same mechanism `kubectl rollout undo` reverses.
      solution_script: |
        kubectl set image deployment/firstdeployment nginx=nginx:1.27
        kubectl rollout status deployment/firstdeployment
---
