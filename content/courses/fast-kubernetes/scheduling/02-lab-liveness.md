---
kind: lab
id_key: k8s/scheduling/lab-liveness
course: fast-kubernetes
section: scheduling
section_title: Health, Resources & Scheduling
section_position: 7
title: 'Lab: Probes and Resources'
position: 1
estimated_minutes: 30
source:
  - labs/liveness/liveness.yaml
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
  - path: liveness.yaml
    content: |
      apiVersion: v1
      kind: Pod
      metadata:
        labels:
          test: liveness
        name: liveness-http
      spec:
        containers:
        - name: liveness
          image: registry.k8s.io/e2e-test-images/agnhost:2.40
          args: ["liveness"]
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
              httpHeaders:
              - name: Custom-Header
                value: Awesome
            initialDelaySeconds: 3
            periodSeconds: 3
      ---
      apiVersion: v1
      kind: Pod
      metadata:
        labels:
          test: liveness
        name: liveness-exec
      spec:
        containers:
        - name: liveness
          image: busybox:1.36
          args:
          - /bin/sh
          - -c
          - touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600
          livenessProbe:
            exec:
              command:
              - cat
              - /tmp/healthy
            initialDelaySeconds: 5
            periodSeconds: 5
      ---
      apiVersion: v1
      kind: Pod
      metadata:
        name: goproxy
        labels:
          app: goproxy
      spec:
        containers:
        - name: goproxy
          image: registry.k8s.io/goproxy:0.1
          ports:
          - containerPort: 8080
          livenessProbe:
            tcpSocket:
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 20
  - path: web.yaml
    content: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: web
      spec:
        replicas: 2
        selector:
          matchLabels:
            app: web
        template:
          metadata:
            labels:
              app: web
          spec:
            containers:
            - name: nginx
              image: nginx:1.27
              ports:
              - containerPort: 80
tasks:
  - id_key: apply-liveness
    title: Create pods with the three probe types
    points: 10
    is_stateful: true
    description: |
      Apply `liveness.yaml`. Use `kubectl describe pod liveness-http`, `liveness-exec` and `goproxy` and find the `Liveness:` line for each: HTTP, exec and TCP.

      On a real cluster, `liveness-exec` deletes its health file after 30 seconds, so its RESTARTS counter starts climbing. Simulated nodes do not run probes, so here you only inspect the configuration.
    verification_script: |
      #!/bin/bash
      kubectl get pod liveness-http -o jsonpath='{.spec.containers[0].livenessProbe.httpGet.path}' | grep -qx /healthz || exit 1
      kubectl get pod liveness-exec -o jsonpath='{.spec.containers[0].livenessProbe.exec.command[1]}' | grep -qx /tmp/healthy || exit 1
      kubectl get pod goproxy -o jsonpath='{.spec.containers[0].livenessProbe.tcpSocket.port}' | grep -qx 8080
    hint_context: "`kubectl apply -f liveness.yaml`"
    explanation_context: httpGet passes on a 200-399 status, exec passes on exit code 0, and tcpSocket passes when the port accepts a connection.
    solution_script: kubectl apply -f liveness.yaml
  - id_key: add-probes
    title: Add readiness and liveness probes to a Deployment
    points: 20
    is_stateful: true
    description: |
      Edit `web.yaml` so the `nginx` container has:
      - a **readinessProbe**: `httpGet` on path `/` port `80`, `periodSeconds: 5`
      - a **livenessProbe**: `tcpSocket` on port `80`, `initialDelaySeconds: 10`

      Apply it.
    verification_script: |
      #!/bin/bash
      C='{.spec.template.spec.containers[0]'
      test "$(kubectl get deploy web -o jsonpath="$C.readinessProbe.httpGet.path}|$C.readinessProbe.httpGet.port}|$C.readinessProbe.periodSeconds}")" = "/|80|5" || exit 1
      test "$(kubectl get deploy web -o jsonpath="$C.livenessProbe.tcpSocket.port}|$C.livenessProbe.initialDelaySeconds}")" = "80|10"
    hint_context: Both probes go inside the container entry, at the same level as `image` and `ports`.
    explanation_context: Readiness keeps a pod out of Service endpoints until nginx answers on /. Liveness restarts the container if port 80 stops accepting connections.
    solution_script: |
      cat > web.yaml <<'Y'
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: web
      spec:
        replicas: 2
        selector:
          matchLabels:
            app: web
        template:
          metadata:
            labels:
              app: web
          spec:
            containers:
            - name: nginx
              image: nginx:1.27
              ports:
              - containerPort: 80
              readinessProbe:
                httpGet:
                  path: /
                  port: 80
                periodSeconds: 5
              livenessProbe:
                tcpSocket:
                  port: 80
                initialDelaySeconds: 10
      Y
      kubectl apply -f web.yaml
  - id_key: set-resources
    title: Give the Deployment the Guaranteed QoS class
    points: 20
    is_stateful: true
    description: |
      Set resources on the `nginx` container of `web` so its pods get the **Guaranteed** QoS class: CPU `250m` and memory `128Mi` for both requests and limits. Check with `kubectl get pods -l app=web -o jsonpath='{.items[*].status.qosClass}'`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get deploy web -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}|{.spec.template.spec.containers[0].resources.limits.memory}')" = "250m|128Mi" || exit 1
      Q=$(kubectl get pods -l app=web -o jsonpath='{range .items[*]}{.status.qosClass}{"\n"}{end}' | sort -u)
      test "$Q" = "Guaranteed"
    hint_context: "`kubectl set resources deployment web -c nginx --requests=cpu=250m,memory=128Mi --limits=cpu=250m,memory=128Mi` works, or edit the YAML."
    explanation_context: Requests equal to limits for both CPU and memory make the pod Guaranteed. Changing resources changes the pod template, so the Deployment rolled out new pods.
    solution_script: |
      kubectl set resources deployment web -c nginx --requests=cpu=250m,memory=128Mi --limits=cpu=250m,memory=128Mi
      kubectl rollout status deployment/web --timeout=60s
      sleep 5
  - id_key: pending-too-big
    title: Ask for more than any node has
    points: 15
    is_stateful: false
    description: |
      Create a pod `hungry` (image `nginx:1.27`) that requests `cpu: 64`. Nodes here have 32 CPUs. Check its status and read the reason in `kubectl describe pod hungry`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get pod hungry -o jsonpath='{.status.phase}')" = "Pending" || exit 1
      kubectl get pod hungry -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")].message}' | grep -qi 'insufficient cpu'
    hint_context: "`kubectl run hungry --image=nginx:1.27 --overrides='{\"spec\":{\"containers\":[{\"name\":\"hungry\",\"image\":\"nginx:1.27\",\"resources\":{\"requests\":{\"cpu\":\"64\"}}}]}}'`, or write a small YAML file."
    explanation_context: The scheduler only places a pod where its requests fit. The Events show "Insufficient cpu", the message you will see on real clusters when nodes are full.
    solution_script: |
      cat > hungry.yaml <<'Y'
      apiVersion: v1
      kind: Pod
      metadata:
        name: hungry
      spec:
        containers:
        - name: hungry
          image: nginx:1.27
          resources:
            requests:
              cpu: "64"
      Y
      kubectl apply -f hungry.yaml
---
