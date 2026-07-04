---
kind: lab
id_key: k8s/scheduling/lab-liveness
course: fast-kubernetes
section: scheduling
section_title: Health & Scheduling
section_position: 6
title: 'Lab: Liveness Probe'
position: 1
estimated_minutes: 30
source:
    - labs/liveness/liveness.yaml
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
    - path: liveness.yaml
      content: "apiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  labels:\r\n    test: liveness\r\n  name: liveness-http\r\nspec:\r\n  containers:\r\n  - name: liveness\r\n    image: k8s.gcr.io/liveness\r\n    args:\r\n    - /server\r\n    livenessProbe:\r\n      httpGet:\r\n        path: /healthz\r\n        port: 8080\r\n        httpHeaders:\r\n        - name: Custom-Header\r\n          value: Awesome\r\n      initialDelaySeconds: 3\r\n      periodSeconds: 3\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  labels:\r\n    test: liveness\r\n  name: liveness-exec\r\nspec:\r\n  containers:\r\n  - name: liveness\r\n    image: k8s.gcr.io/busybox\r\n    args:\r\n    - /bin/sh\r\n    - -c\r\n    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600\r\n    livenessProbe:\r\n      exec:\r\n        command:\r\n        - cat\r\n        - /tmp/healthy\r\n      initialDelaySeconds: 5\r\n      periodSeconds: 5\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: goproxy\r\n  labels:\r\n    app: goproxy\r\nspec:\r\n  containers:\r\n  - name: goproxy\r\n    image: k8s.gcr.io/goproxy:0.1\r\n    ports:\r\n    - containerPort: 8080\r\n    livenessProbe:\r\n      tcpSocket:\r\n        port: 8080\r\n      initialDelaySeconds: 15\r\n      periodSeconds: 20"
tasks:
    - id_key: create-liveness-pods
      title: Create the liveness-http, liveness-exec, and goproxy Pods
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `liveness.yaml` (already in your workdir) to create three Pods, each declaring a
        different liveness probe mechanism: **liveness-http** (`httpGet`), **liveness-exec**
        (`exec`), and **goproxy** (`tcpSocket`).
      verification_script: |
        #!/bin/bash
        for p in liveness-http liveness-exec goproxy; do
          kubectl get pod "$p" --no-headers 2>/dev/null | grep -q Running || exit 1
        done
      hint_context: Use `kubectl apply -f liveness.yaml`.
      explanation_context: |
        `liveness.yaml` bundles three Pod manifests separated by `---`, each demonstrating one of
        the three liveness probe types Kubernetes supports: an HTTP GET request, an exec command
        inside the container, and a raw TCP socket connect. `kubectl apply -f` creates all three
        with a single command.
      solution_script: kubectl apply -f liveness.yaml
    - id_key: verify-liveness-http-probe
      title: Confirm the liveness-http Pod's httpGet probe configuration
      points: 20
      is_optional: false
      is_stateful: false
      description: |
        Confirm that the **liveness-http** Pod's container declares an `httpGet` liveness probe
        targeting path **`/healthz`** on port **`8080`**, with `initialDelaySeconds: 3` and
        `periodSeconds: 3`.
      verification_script: |
        #!/bin/bash
        P='{.spec.containers[0].livenessProbe'
        kubectl get pod liveness-http -o jsonpath="${P}.httpGet.path}" | grep -qx /healthz || exit 1
        kubectl get pod liveness-http -o jsonpath="${P}.httpGet.port}" | grep -qx 8080 || exit 1
        kubectl get pod liveness-http -o jsonpath="${P}.initialDelaySeconds}" | grep -qx 3 || exit 1
        kubectl get pod liveness-http -o jsonpath="${P}.periodSeconds}" | grep -qx 3
      hint_context: |
        Inspect `kubectl get pod liveness-http -o yaml` or query
        `.spec.containers[0].livenessProbe` with `jsonpath`.
      explanation_context: |
        `httpGet` probes ask the kubelet to send a GET request to the container's IP at the given
        path and port on every `periodSeconds` interval, starting `initialDelaySeconds` after the
        container starts. A non-2xx/3xx response (or connection failure) counts as a probe
        failure — after enough consecutive failures (`failureThreshold`, defaulting to 3), the
        kubelet restarts the container.
      solution_script: kubectl get pod liveness-http -o jsonpath='{.spec.containers[0].livenessProbe}'
    - id_key: verify-liveness-exec-probe
      title: Confirm the liveness-exec Pod's exec probe configuration
      points: 20
      is_optional: false
      is_stateful: false
      description: |
        Confirm that the **liveness-exec** Pod's container declares an `exec` liveness probe
        running the command **`cat /tmp/healthy`**, with `initialDelaySeconds: 5` and
        `periodSeconds: 5`.
      verification_script: |
        #!/bin/bash
        P='{.spec.containers[0].livenessProbe'
        kubectl get pod liveness-exec -o jsonpath="${P}.exec.command[0]}" | grep -qx cat || exit 1
        kubectl get pod liveness-exec -o jsonpath="${P}.exec.command[1]}" | grep -qx /tmp/healthy || exit 1
        kubectl get pod liveness-exec -o jsonpath="${P}.initialDelaySeconds}" | grep -qx 5 || exit 1
        kubectl get pod liveness-exec -o jsonpath="${P}.periodSeconds}" | grep -qx 5
      hint_context: |
        Inspect `kubectl get pod liveness-exec -o yaml` or query
        `.spec.containers[0].livenessProbe.exec` with `jsonpath`.
      explanation_context: |
        This Pod's container runs `touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600` —
        on a real kubelet, the `cat /tmp/healthy` exec probe would succeed (exit 0) for the first
        30 seconds, then fail continuously once the file is removed, eventually triggering a
        restart. This lab's cluster is **kwok-simulated**: there is no real container process for
        kwok's fake kubelet to exec into, so it never actually runs the probe command or restarts
        anything — `.status.containerStatuses[].restartCount` will not reflect real probe
        behavior here. That's why this task (and its siblings) verify the **declared probe spec**
        on `.spec.containers[0].livenessProbe` rather than any observed runtime outcome.
      solution_script: kubectl get pod liveness-exec -o jsonpath='{.spec.containers[0].livenessProbe}'
    - id_key: verify-goproxy-tcp-probe
      title: Confirm the goproxy Pod's tcpSocket probe configuration
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that the **goproxy** Pod's container declares a `tcpSocket` liveness probe
        targeting port **`8080`**, with `initialDelaySeconds: 15` and `periodSeconds: 20`.
      verification_script: |
        #!/bin/bash
        P='{.spec.containers[0].livenessProbe'
        kubectl get pod goproxy -o jsonpath="${P}.tcpSocket.port}" | grep -qx 8080 || exit 1
        kubectl get pod goproxy -o jsonpath="${P}.initialDelaySeconds}" | grep -qx 15 || exit 1
        kubectl get pod goproxy -o jsonpath="${P}.periodSeconds}" | grep -qx 20
      hint_context: |
        Inspect `kubectl get pod goproxy -o yaml` or query
        `.spec.containers[0].livenessProbe.tcpSocket` with `jsonpath`.
      explanation_context: |
        `tcpSocket` probes are the cheapest liveness check: the kubelet just attempts a TCP
        connection to the given port and considers it a success if the connection opens. It's
        useful for protocols that don't speak HTTP but does not verify that the application is
        actually functioning correctly — only that something is listening on the port.
      solution_script: kubectl get pod goproxy -o jsonpath='{.spec.containers[0].livenessProbe}'
---
