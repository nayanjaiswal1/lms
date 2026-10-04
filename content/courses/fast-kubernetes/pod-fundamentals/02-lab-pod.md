---
kind: lab
id_key: k8s/pod-fundamentals/lab-pod
course: fast-kubernetes
section: pod-fundamentals
section_title: Pods
section_position: 2
title: 'Lab: Create and Inspect Pods'
position: 1
estimated_minutes: 25
source:
  - labs/pod/multicontainer.yaml
  - labs/pod/pod1.yaml
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
  - path: pod1.yaml
    content: |
      apiVersion: v1
      kind: Pod
      metadata:
        name: firstpod
        labels:
          app: frontend
      spec:
        containers:
        - name: nginx
          image: nginx:1.27
          ports:
          - containerPort: 80
          env:
          - name: USER
            value: "username"
  - path: multicontainer.yaml
    content: |
      apiVersion: v1
      kind: Pod
      metadata:
        name: multicontainer
      spec:
        containers:
        - name: webcontainer
          image: nginx:1.27
          ports:
          - containerPort: 80
          volumeMounts:
          - name: sharedvolume
            mountPath: /usr/share/nginx/html
        - name: sidecarcontainer
          image: busybox:1.36
          command: ["/bin/sh", "-c"]
          args: ["while true; do echo \"<h1>Updated at $(date)</h1>\" > /var/log/index.html; sleep 15; done"]
          volumeMounts:
          - name: sharedvolume
            mountPath: /var/log
        volumes:
        - name: sharedvolume
          emptyDir: {}
tasks:
  - id_key: run-imperative
    title: Run a pod with one command
    points: 10
    is_stateful: true
    description: |
      Create a pod called `mypod` from the image `nginx:1.27` using `kubectl run`. Then look at it with `kubectl get pods -o wide`.

      Note: nodes in this sandbox are simulated. Pods really get scheduled and become `Running`, but no real process runs inside them, so `kubectl logs`, `exec` and `port-forward` will not work here.
    verification_script: |
      #!/bin/bash
      kubectl get pod mypod -o jsonpath='{.spec.containers[0].image} {.status.phase}' | grep -qx 'nginx:1.27 Running'
    hint_context: "`kubectl run <name> --image=<image>`"
    explanation_context: "`kubectl run mypod --image=nginx:1.27` creates a Pod object. The scheduler assigns it to a node and the node reports it as Running."
    solution_script: kubectl run mypod --image=nginx:1.27
  - id_key: apply-firstpod
    title: Create a pod from a YAML file
    points: 10
    is_stateful: true
    description: Your work folder already has `pod1.yaml`. Read it with `cat pod1.yaml`, then create the pod from it. Use `kubectl describe pod firstpod` to find its labels and environment variables.
    verification_script: |
      #!/bin/bash
      kubectl get pod firstpod -o jsonpath='{.metadata.labels.app} {.spec.containers[0].env[?(@.name=="USER")].value} {.status.phase}' | grep -qx 'frontend username Running'
    hint_context: "`kubectl apply -f <file>`"
    explanation_context: "`kubectl apply -f pod1.yaml` sends the manifest to the API server. Because it is a file, you can apply it again later and get the same pod."
    solution_script: kubectl apply -f pod1.yaml
  - id_key: label-pod
    title: Add a label to a running pod
    points: 10
    is_stateful: false
    description: Add the label `tier=web` to `firstpod`. Then list only pods with that label using a selector.
    verification_script: |
      #!/bin/bash
      kubectl get pods -l tier=web -o name | grep -qx pod/firstpod
    hint_context: "`kubectl label pod <name> key=value`, then `kubectl get pods -l key=value`."
    explanation_context: Labels can be added or removed at any time without restarting the pod. Selectors like `-l tier=web` are exactly how Services and Deployments find pods.
    solution_script: kubectl label pod firstpod tier=web
  - id_key: apply-multicontainer
    title: Run a pod with a sidecar container
    points: 15
    is_stateful: true
    description: Create the pod in `multicontainer.yaml`. Check that it shows `READY 2/2`, and use `kubectl describe pod multicontainer` to see that both containers mount the same `sharedvolume`.
    verification_script: |
      #!/bin/bash
      kubectl get pod multicontainer -o jsonpath='{.spec.containers[*].name}' | grep -qx 'webcontainer sidecarcontainer' || exit 1
      kubectl get pod multicontainer -o jsonpath='{.spec.volumes[0].emptyDir}' | grep -q '{}' || exit 1
      kubectl get pod multicontainer -o jsonpath='{.status.phase}' | grep -qx Running
    hint_context: Apply the file the same way as `pod1.yaml`.
    explanation_context: Both containers mount the `sharedvolume` emptyDir, so a file written by the sidecar is served by nginx. READY 2/2 means both containers are ready.
    solution_script: kubectl apply -f multicontainer.yaml
  - id_key: write-init-pod
    title: Write a pod with an init container
    points: 20
    is_stateful: false
    description: |
      Write your own manifest `initpod.yaml` for a pod named `initpod` that has:
      - an init container named `setup` using image `busybox:1.36` with command `["sh", "-c", "echo preparing"]`
      - an app container named `app` using image `nginx:1.27`

      Apply it. Tip: start from `kubectl run initpod --image=nginx:1.27 --dry-run=client -o yaml > initpod.yaml` and add the `initContainers` list under `spec`.
    verification_script: |
      #!/bin/bash
      kubectl get pod initpod -o jsonpath='{.spec.initContainers[0].name} {.spec.initContainers[0].image} {.spec.containers[0].image}' | grep -qx 'setup busybox:1.36 nginx:1.27'
    hint_context: "`initContainers` is a list at the same level as `containers` inside `spec`, and each entry has name, image and command."
    explanation_context: Init containers run to completion, one by one, before any app container starts. They are the right place for setup work such as waiting for a dependency.
    solution_script: |
      cat > initpod.yaml <<'EOF'
      apiVersion: v1
      kind: Pod
      metadata:
        name: initpod
      spec:
        initContainers:
        - name: setup
          image: busybox:1.36
          command: ["sh", "-c", "echo preparing"]
        containers:
        - name: app
          image: nginx:1.27
      EOF
      kubectl apply -f initpod.yaml
  - id_key: delete-pod
    title: Delete a pod
    points: 10
    is_stateful: false
    description: Delete `mypod`. Notice that nothing recreates it, because no controller owns a bare pod.
    verification_script: |
      #!/bin/bash
      kubectl get pod firstpod >/dev/null 2>&1 || exit 1
      ! kubectl get pod mypod >/dev/null 2>&1
    hint_context: "`kubectl delete pod <name>`"
    explanation_context: A bare pod is gone for good once deleted. In the next section a Deployment will recreate deleted pods automatically.
    solution_script: kubectl delete pod mypod --wait=false
---
