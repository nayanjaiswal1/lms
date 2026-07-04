---
kind: lab
id_key: k8s/pod-fundamentals/lab-pod
course: fast-kubernetes
section: pod-fundamentals
section_title: Pod Fundamentals
section_position: 1
title: 'Lab: Pod'
position: 1
estimated_minutes: 30
source:
    - labs/pod/multicontainer.yaml
    - labs/pod/pod1.yaml
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
    - path: multicontainer.yaml
      content: "apiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: multicontainer\r\nspec:\r\n  containers:\r\n  - name: webcontainer\r\n    image: nginx\r\n    ports:\r\n      - containerPort: 80\r\n    volumeMounts:\r\n    - name: sharedvolume\r\n      mountPath: /usr/share/nginx/html\r\n  - name: sidecarcontainer\r\n    image: busybox\r\n    command: [\"/bin/sh\"]\r\n    args: [\"-c\", \"while true; do wget -O /var/log/index.html https://raw.githubusercontent.com/omerbsezer/Fast-Kubernetes/main/index.html; sleep 15; done\"]\r\n    volumeMounts:\r\n    - name: sharedvolume\r\n      mountPath: /var/log\r\n  volumes:\r\n  - name: sharedvolume\r\n    emptyDir: {}"
    - path: pod1.yaml
      content: "apiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: firstpod\r\n  labels:\r\n    app: frontend\r\nspec:\r\n  containers:\r\n  - name: nginx\r\n    image: nginx:latest\r\n    ports:\r\n    - containerPort: 80\r\n    env: \r\n    - name: USER    \r\n      value: \"username\""
tasks:
    - id_key: create-firstpod
      title: Create the firstpod Pod
      points: 10
      is_optional: false
      is_stateful: true
      description: |
        Apply `pod1.yaml` (already in your workdir) to create a Pod named **firstpod** with
        label `app=frontend`, running image `nginx:latest`.
      verification_script: |
        #!/bin/bash
        kubectl get pod firstpod --no-headers 2>/dev/null | grep -q Running || exit 1
        kubectl get pod firstpod -o jsonpath='{.metadata.labels.app}' | grep -qx frontend
      hint_context: Use `kubectl apply -f pod1.yaml`.
      explanation_context: |
        A bare Pod (no Deployment/ReplicaSet owner) is created directly from the manifest.
        kwok's fast pod-ready stage marks it Running almost immediately once the scheduler
        binds it to the (fake) node.
      solution_script: kubectl apply -f pod1.yaml
    - id_key: verify-env-var
      title: Confirm the USER environment variable
      points: 10
      is_optional: false
      is_stateful: false
      description: |
        Confirm that `firstpod`'s container defines the environment variable `USER` with
        value `username`, as declared in `pod1.yaml`.
      verification_script: |
        #!/bin/bash
        kubectl get pod firstpod -o jsonpath='{.spec.containers[0].env[?(@.name=="USER")].value}' | grep -qx username
      hint_context: |
        Inspect the Pod spec with `kubectl get pod firstpod -o yaml` or a `jsonpath` query
        against `.spec.containers[0].env`.
      explanation_context: |
        Environment variables declared under a container's `env:` list are injected into the
        container's process environment at start — this is the simplest way to pass
        configuration into a container without a ConfigMap or Secret.
      solution_script: kubectl get pod firstpod -o jsonpath='{.spec.containers[0].env}'
    - id_key: create-multicontainer
      title: Create the multicontainer Pod
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `multicontainer.yaml` to create a Pod named **multicontainer** with two
        containers — `webcontainer` (nginx) and `sidecarcontainer` (busybox) — sharing an
        `emptyDir` volume named `sharedvolume`.
      verification_script: |
        #!/bin/bash
        kubectl get pod multicontainer --no-headers 2>/dev/null | grep -q Running || exit 1
        NAMES=$(kubectl get pod multicontainer -o jsonpath='{.spec.containers[*].name}')
        echo "$NAMES" | grep -qw webcontainer || exit 1
        echo "$NAMES" | grep -qw sidecarcontainer
      hint_context: Use `kubectl apply -f multicontainer.yaml`.
      explanation_context: |
        All containers in a Pod share the same network namespace (one IP, localhost between
        containers) and can share storage via volumes — the sidecar pattern uses this to run a
        helper process (here, busybox polling a remote file) alongside the main app container.
      solution_script: kubectl apply -f multicontainer.yaml
    - id_key: verify-shared-volume
      title: Confirm the shared emptyDir volume is mounted in both containers
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that the `sharedvolume` `emptyDir` volume is mounted into both
        `webcontainer` and `sidecarcontainer` in the `multicontainer` Pod.
      verification_script: |
        #!/bin/bash
        kubectl get pod multicontainer -o jsonpath='{.spec.volumes[?(@.name=="sharedvolume")].emptyDir}' >/dev/null 2>&1 || exit 1
        MOUNTS=$(kubectl get pod multicontainer -o jsonpath='{.spec.containers[*].volumeMounts[?(@.name=="sharedvolume")].name}')
        test "$(echo "$MOUNTS" | wc -w)" -ge 2
      hint_context: |
        Inspect `.spec.volumes` for the `emptyDir` definition and each container's
        `.volumeMounts` for a matching `name: sharedvolume` entry.
      explanation_context: |
        An `emptyDir` volume is created fresh when the Pod is scheduled and lives as long as
        the Pod does — every container that mounts it sees the same directory, which is how
        the sidecar in this Pod delivers files to the main nginx container.
      solution_script: kubectl get pod multicontainer -o yaml
---
