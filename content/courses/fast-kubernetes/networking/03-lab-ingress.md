---
kind: lab
id_key: k8s/networking/lab-ingress
course: fast-kubernetes
section: networking
section_title: Networking
section_position: 3
title: 'Lab: Ingress'
position: 2
estimated_minutes: 30
source:
    - labs/ingress/appingress.yaml
    - labs/ingress/deploy.yaml
    - labs/ingress/todoingress.yaml
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
    - path: appingress.yaml
      content: "apiVersion: networking.k8s.io/v1\r\nkind: Ingress\r\nmetadata:\r\n  name: appingress\r\n  annotations:\r\n    nginx.ingress.kubernetes.io/rewrite-target: /$1\r\nspec:\r\n  rules:\r\n    - host: webapp.com\r\n      http:\r\n        paths:\r\n          - path: /blue\r\n            pathType: Prefix\r\n            backend:\r\n              service:\r\n                name: bluesvc\r\n                port:\r\n                  number: 80\r\n          - path: /green\r\n            pathType: Prefix\r\n            backend:\r\n              service:\r\n                name: greensvc\r\n                port:\r\n                  number: 80"
    - path: deploy.yaml
      content: "apiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: blueapp\r\n  labels:\r\n    app: blue\r\nspec:\r\n  replicas: 2\r\n  selector:\r\n    matchLabels:\r\n      app: blue\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: blue\r\n    spec:\r\n      containers:\r\n      - name: blueapp\r\n        image: ozgurozturknet/k8s:blue\r\n        ports:\r\n        - containerPort: 80\r\n        livenessProbe:\r\n          httpGet:\r\n            path: /healthcheck\r\n            port: 80\r\n          initialDelaySeconds: 5\r\n          periodSeconds: 5\r\n        readinessProbe:\r\n          httpGet:\r\n            path: /ready\r\n            port: 80\r\n          initialDelaySeconds: 5\r\n          periodSeconds: 3\r\n---\r\napiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  name: bluesvc\r\nspec:\r\n  selector:\r\n    app: blue\r\n  ports:\r\n    - protocol: TCP\r\n      port: 80\r\n      targetPort: 80\r\n---\r\napiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: greenapp\r\n  labels:\r\n    app: green\r\nspec:\r\n  replicas: 2\r\n  selector:\r\n    matchLabels:\r\n      app: green\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: green\r\n    spec:\r\n      containers:\r\n      - name: greenapp\r\n        image: ozgurozturknet/k8s:green\r\n        ports:\r\n        - containerPort: 80\r\n        livenessProbe:\r\n          httpGet:\r\n            path: /healthcheck\r\n            port: 80\r\n          initialDelaySeconds: 5\r\n          periodSeconds: 5\r\n        readinessProbe:\r\n          httpGet:\r\n            path: /ready\r\n            port: 80\r\n          initialDelaySeconds: 5\r\n          periodSeconds: 3\r\n---\r\napiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  name: greensvc\r\nspec:\r\n  selector:\r\n    app: green\r\n  ports:\r\n    - protocol: TCP\r\n      port: 80\r\n      targetPort: 80\r\n---\r\napiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: todoapp\r\n  labels:\r\n    app: todo\r\nspec:\r\n  replicas: 1\r\n  selector:\r\n    matchLabels:\r\n      app: todo\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: todo\r\n    spec:\r\n      containers:\r\n      - name: todoapp\r\n        image: ozgurozturknet/samplewebapp:latest\r\n        ports:\r\n        - containerPort: 80\r\n---\r\napiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  name: todosvc\r\nspec:\r\n  selector:\r\n    app: todo\r\n  ports:\r\n    - protocol: TCP\r\n      port: 80\r\n      targetPort: 80"
    - path: todoingress.yaml
      content: "apiVersion: networking.k8s.io/v1\r\nkind: Ingress\r\nmetadata:\r\n  name: todoingress\r\nspec:\r\n  rules:\r\n    - host: todoapp.com\r\n      http:\r\n        paths:\r\n          - path: /\r\n            pathType: Prefix\r\n            backend:\r\n              service:\r\n                name: todosvc\r\n                port:\r\n                  number: 80"
tasks:
    - id_key: create-blue-green-todo-workloads
      title: Create the blue, green, and todo Deployments and Services
      points: 20
      is_optional: false
      is_stateful: true
      description: |
        Apply `deploy.yaml` to create three Deployment+Service pairs: **blueapp**/**bluesvc**
        (2 replicas, image `ozgurozturknet/k8s:blue`, label `app=blue`),
        **greenapp**/**greensvc** (2 replicas, image `ozgurozturknet/k8s:green`, label
        `app=green`), and **todoapp**/**todosvc** (1 replica, image
        `ozgurozturknet/samplewebapp:latest`, label `app=todo`).
      verification_script: |
        #!/bin/bash
        kubectl get deployment blueapp >/dev/null 2>&1 || exit 1
        kubectl get deployment greenapp >/dev/null 2>&1 || exit 1
        kubectl get deployment todoapp >/dev/null 2>&1 || exit 1
        BREADY=$(kubectl get deployment blueapp -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        GREADY=$(kubectl get deployment greenapp -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        TREADY=$(kubectl get deployment todoapp -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        test "${BREADY:-0}" -ge 2 || exit 1
        test "${GREADY:-0}" -ge 2 || exit 1
        test "${TREADY:-0}" -ge 1 || exit 1
        kubectl get svc bluesvc >/dev/null 2>&1 || exit 1
        kubectl get svc greensvc >/dev/null 2>&1 || exit 1
        kubectl get svc todosvc >/dev/null 2>&1
      hint_context: Use `kubectl apply -f deploy.yaml`.
      explanation_context: |
        `deploy.yaml` bundles three Deployment/Service pairs in one manifest separated by `---`
        — `kubectl apply -f` creates all six objects with a single command, giving the Ingress
        resources you create next real backends to route to.
      solution_script: kubectl apply -f deploy.yaml
    - id_key: create-appingress
      title: Create the appingress Ingress for the blue/green apps
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `appingress.yaml` to create an Ingress named **appingress** carrying the
        `nginx.ingress.kubernetes.io/rewrite-target` annotation, routing host `webapp.com`'s
        `/blue` path to **bluesvc**:80 and `/green` path to **greensvc**:80.
      verification_script: |
        #!/bin/bash
        kubectl get ingress appingress >/dev/null 2>&1 || exit 1
        kubectl get ingress appingress -o jsonpath='{.spec.rules[0].host}' | grep -qx webapp.com || exit 1
        kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' | grep -qx bluesvc || exit 1
        kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[1].backend.service.name}' | grep -qx greensvc
      hint_context: Use `kubectl apply -f appingress.yaml`.
      explanation_context: |
        An Ingress declares HTTP routing rules that an Ingress controller (not the API server)
        implements — here a single host `webapp.com` fans out to two independent backend
        Services based on URL path prefix, letting one entrypoint front both Deployments.
      solution_script: kubectl apply -f appingress.yaml
    - id_key: create-todoingress
      title: Create the todoingress Ingress for the todo app
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `todoingress.yaml` to create an Ingress named **todoingress** routing host
        `todoapp.com`'s `/` path to **todosvc**:80.
      verification_script: |
        #!/bin/bash
        kubectl get ingress todoingress >/dev/null 2>&1 || exit 1
        kubectl get ingress todoingress -o jsonpath='{.spec.rules[0].host}' | grep -qx todoapp.com || exit 1
        kubectl get ingress todoingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' | grep -qx todosvc || exit 1
        kubectl get ingress todoingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' | grep -qx 80
      hint_context: Use `kubectl apply -f todoingress.yaml`.
      explanation_context: |
        Unlike `appingress`, `todoingress` carries no `rewrite-target` annotation — its single
        `/` path maps directly to the backend with no prefix to strip, so no rewrite is needed.
      solution_script: kubectl apply -f todoingress.yaml
    - id_key: verify-appingress-paths
      title: Confirm both appingress path rules are wired correctly
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm both path rules on **appingress** are configured correctly — `/blue` routes to
        **bluesvc** on port `80` with `pathType: Prefix`, and `/green` routes to **greensvc** on
        port `80` with `pathType: Prefix`.
      verification_script: |
        #!/bin/bash
        kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[0].path}' | grep -qx /blue || exit 1
        kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[0].pathType}' | grep -qx Prefix || exit 1
        kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' | grep -qx 80 || exit 1
        kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[1].path}' | grep -qx /green || exit 1
        kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[1].pathType}' | grep -qx Prefix || exit 1
        kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[1].backend.service.port.number}' | grep -qx 80
      hint_context: |
        Inspect `.spec.rules[0].http.paths` with `kubectl get ingress appingress -o yaml`.
      explanation_context: |
        `pathType: Prefix` means the path segment must match as a full URL element (or a prefix
        of it) rather than an exact string or unconstrained regex — this is what lets `/blue`
        also match `/blue/anything` without spilling into `/green`'s traffic.
      solution_script: kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths}'
    - id_key: verify-rewrite-target-annotation
      title: Confirm the rewrite-target annotation on appingress
      points: 10
      is_optional: false
      is_stateful: false
      description: |
        Confirm **appingress** carries the annotation
        `nginx.ingress.kubernetes.io/rewrite-target` set to `/$1`, which rewrites the matched
        path before forwarding to the backend.
      verification_script: |
        #!/bin/bash
        VAL=$(kubectl get ingress appingress -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/rewrite-target}' 2>/dev/null)
        test "$VAL" = '/$1'
      hint_context: |
        Use `kubectl get ingress appingress -o jsonpath='{.metadata.annotations}'`.
      explanation_context: |
        The `rewrite-target` annotation is an nginx-ingress-controller-specific extension (not
        part of the core Ingress API) — combined with the path match, `/$1` strips the `/blue`
        or `/green` prefix before proxying, so the backend app sees requests at its own root
        path instead of under `/blue` or `/green`.
      solution_script: kubectl get ingress appingress -o jsonpath='{.metadata.annotations}'
    - id_key: verify-service-selectors-match
      title: Confirm each Ingress backend Service targets the right Deployment's Pods
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm **bluesvc**, **greensvc**, and **todosvc** each select Pods by the same label
        their corresponding Deployment's Pod template sets — `bluesvc` → `app=blue`
        (`blueapp`), `greensvc` → `app=green` (`greenapp`), and `todosvc` → `app=todo`
        (`todoapp`).
      verification_script: |
        #!/bin/bash
        BSEL=$(kubectl get svc bluesvc -o jsonpath='{.spec.selector.app}' 2>/dev/null)
        BLBL=$(kubectl get deployment blueapp -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
        test -n "$BSEL" && test "$BSEL" = "$BLBL" || exit 1
        GSEL=$(kubectl get svc greensvc -o jsonpath='{.spec.selector.app}' 2>/dev/null)
        GLBL=$(kubectl get deployment greenapp -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
        test -n "$GSEL" && test "$GSEL" = "$GLBL" || exit 1
        TSEL=$(kubectl get svc todosvc -o jsonpath='{.spec.selector.app}' 2>/dev/null)
        TLBL=$(kubectl get deployment todoapp -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
        test -n "$TSEL" && test "$TSEL" = "$TLBL"
      hint_context: |
        Compare each Service's `.spec.selector` against its Deployment's
        `.spec.template.metadata.labels`.
      explanation_context: |
        An Ingress only ever forwards to a Service by name — it has no visibility into whether
        that Service actually has healthy endpoints. If a Service's `selector` drifted from its
        backing Deployment's Pod template labels, the Ingress and Service would both look
        "created" while traffic silently hit zero endpoints.
      solution_script: |
        kubectl get svc bluesvc -o jsonpath='{.spec.selector}'
        kubectl get deployment blueapp -o jsonpath='{.spec.template.metadata.labels}'
        kubectl get svc greensvc -o jsonpath='{.spec.selector}'
        kubectl get deployment greenapp -o jsonpath='{.spec.template.metadata.labels}'
        kubectl get svc todosvc -o jsonpath='{.spec.selector}'
        kubectl get deployment todoapp -o jsonpath='{.spec.template.metadata.labels}'
---
