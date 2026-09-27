---
kind: lab
id_key: k8s/workloads/lab-deployment
course: fast-kubernetes
section: workloads
section_title: Deployments & Workload Controllers
section_position: 3
title: 'Lab: Deployments, Scaling and Rollbacks'
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
    content: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: firstdeployment
        labels:
          team: development
      spec:
        replicas: 3
        selector:
          matchLabels:
            app: frontend
        template:
          metadata:
            labels:
              app: frontend
          spec:
            containers:
            - name: nginx
              image: nginx:1.27
              ports:
              - containerPort: 80
  - path: recreate-deployment.yaml
    content: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: rcdeployment
        labels:
          team: development
      spec:
        replicas: 5
        selector:
          matchLabels:
            app: recreate
        strategy:
          type: Recreate
        template:
          metadata:
            labels:
              app: recreate
          spec:
            containers:
            - name: nginx
              image: nginx:1.27
              ports:
              - containerPort: 80
  - path: rolling-deployment.yaml
    content: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: rolldeployment
        labels:
          team: development
      spec:
        replicas: 10
        selector:
          matchLabels:
            app: rolling
        strategy:
          type: RollingUpdate
          rollingUpdate:
            maxUnavailable: 2
            maxSurge: 2
        template:
          metadata:
            labels:
              app: rolling
          spec:
            containers:
            - name: nginx
              image: nginx:1.27
              ports:
              - containerPort: 80
tasks:
  - id_key: create-deployment
    title: Create a Deployment
    points: 10
    is_stateful: true
    description: Apply `deployment1.yaml`. Check that `kubectl get deployments` shows `3/3` ready and look at the ReplicaSet it created with `kubectl get rs`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get deployment firstdeployment -o jsonpath='{.status.readyReplicas}')" = "3"
    hint_context: "`kubectl apply -f deployment1.yaml`"
    explanation_context: The Deployment created a ReplicaSet, and the ReplicaSet created 3 pods with the `app=frontend` label.
    solution_script: kubectl apply -f deployment1.yaml
  - id_key: self-healing
    title: Watch a Deployment heal itself
    points: 10
    is_stateful: true
    description: |
      Write down the pod names (`kubectl get pods -l app=frontend`), then delete **all** of them with one command:
      `kubectl delete pods -l app=frontend`. Run `kubectl get pods -l app=frontend` again and compare the names.
    verification_script: |
      #!/bin/bash
      # every current frontend pod must be younger than the deployment by a few seconds (i.e. replacements)
      D=$(date -d "$(kubectl get deployment firstdeployment -o jsonpath='{.metadata.creationTimestamp}')" +%s)
      N=$(kubectl get pods -l app=frontend -o jsonpath='{range .items[*]}{.metadata.creationTimestamp}{"\n"}{end}' | while read t; do [ $(( $(date -d "$t" +%s) - D )) -ge 3 ] && echo new; done | wc -l)
      test "$N" -ge 3
    hint_context: Deleting by label selector (`-l`) removes every matching pod at once.
    explanation_context: The ReplicaSet saw 0 of 3 pods and immediately created 3 new ones with new names. This is the reconcile loop at work.
    solution_script: |
      sleep 4
      kubectl delete pods -l app=frontend --wait=false
  - id_key: scale-deployment
    title: Scale up
    points: 10
    is_stateful: true
    description: Scale `firstdeployment` to 5 replicas.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get deployment firstdeployment -o jsonpath='{.spec.replicas}/{.status.readyReplicas}')" = "5/5"
    hint_context: "`kubectl scale deployment <name> --replicas=<n>`"
    explanation_context: Scaling only changes `spec.replicas`. The ReplicaSet then creates the missing pods.
    solution_script: kubectl scale deployment firstdeployment --replicas=5
  - id_key: rolling-update
    title: Roll out a new image
    points: 15
    is_stateful: true
    description: |
      Apply `rolling-deployment.yaml` (10 replicas, maxSurge 2, maxUnavailable 2). When it is ready, change the image of its `nginx` container to `httpd:2.4` with `kubectl set image`. Watch it with `kubectl rollout status deployment/rolldeployment` and `kubectl get rs`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get deployment rolldeployment -o jsonpath='{.spec.template.spec.containers[0].image}')" = "httpd:2.4" || exit 1
      test "$(kubectl get rs -l app=rolling --no-headers | wc -l)" -ge 2 || exit 1
      test "$(kubectl get deployment rolldeployment -o jsonpath='{.status.updatedReplicas}')" = "10"
    hint_context: "`kubectl set image deployment/rolldeployment nginx=httpd:2.4`"
    explanation_context: The new image created a second ReplicaSet. The Deployment moved pods over at most 2 at a time. The old ReplicaSet stays at 0 replicas so you can roll back.
    solution_script: |
      kubectl apply -f rolling-deployment.yaml
      kubectl rollout status deployment/rolldeployment --timeout=60s
      kubectl set image deployment/rolldeployment nginx=httpd:2.4
      kubectl rollout status deployment/rolldeployment --timeout=60s
  - id_key: rollback
    title: Roll back
    points: 15
    is_stateful: true
    description: The new version is "broken". Look at `kubectl rollout history deployment/rolldeployment`, then roll back to the previous revision.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get deployment rolldeployment -o jsonpath='{.spec.template.spec.containers[0].image}')" = "nginx:1.27" || exit 1
      kubectl rollout history deployment/rolldeployment | grep -q '^3 '
    hint_context: "`kubectl rollout undo deployment/<name>`"
    explanation_context: The rollback reused the old ReplicaSet's template. It shows up as a new revision (3) in the history, because a rollback is just another rollout.
    solution_script: |
      kubectl rollout undo deployment/rolldeployment
      kubectl rollout status deployment/rolldeployment --timeout=60s
  - id_key: recreate-strategy
    title: Use the Recreate strategy
    points: 10
    is_stateful: false
    description: Apply `recreate-deployment.yaml`, then change its image to `httpd:2.4`. Run `kubectl get pods -l app=recreate -w` right after the change to see all old pods terminate before new ones start (Ctrl+C to stop watching).
    verification_script: |
      #!/bin/bash
      kubectl get deployment rcdeployment -o jsonpath='{.spec.strategy.type} {.spec.template.spec.containers[0].image}' | grep -qx 'Recreate httpd:2.4'
    hint_context: Same `kubectl set image` command, but with the deployment `rcdeployment`.
    explanation_context: With Recreate there is a gap where no pods run. That is why RollingUpdate is the default.
    solution_script: |
      kubectl apply -f recreate-deployment.yaml
      kubectl set image deployment/rcdeployment nginx=httpd:2.4
---
