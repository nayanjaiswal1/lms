---
kind: lab
id_key: k8s/networking/lab-ingress
course: fast-kubernetes
section: networking
section_title: Services & Networking
section_position: 4
title: 'Lab: Ingress'
position: 2
estimated_minutes: 25
source:
  - labs/ingress/deploy.yaml
  - labs/ingress/appingress.yaml
  - labs/ingress/todoingress.yaml
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
  - path: deploy.yaml
    content: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: blueapp
        labels:
          app: blue
      spec:
        replicas: 2
        selector:
          matchLabels:
            app: blue
        template:
          metadata:
            labels:
              app: blue
          spec:
            containers:
            - name: blueapp
              image: ozgurozturknet/k8s:blue
              ports:
              - containerPort: 80
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: bluesvc
      spec:
        selector:
          app: blue
        ports:
        - protocol: TCP
          port: 80
          targetPort: 80
      ---
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: greenapp
        labels:
          app: green
      spec:
        replicas: 2
        selector:
          matchLabels:
            app: green
        template:
          metadata:
            labels:
              app: green
          spec:
            containers:
            - name: greenapp
              image: ozgurozturknet/k8s:green
              ports:
              - containerPort: 80
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: greensvc
      spec:
        selector:
          app: green
        ports:
        - protocol: TCP
          port: 80
          targetPort: 80
      ---
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: todoapp
        labels:
          app: todo
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: todo
        template:
          metadata:
            labels:
              app: todo
          spec:
            containers:
            - name: todoapp
              image: ozgurozturknet/samplewebapp:latest
              ports:
              - containerPort: 80
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: todosvc
      spec:
        selector:
          app: todo
        ports:
        - protocol: TCP
          port: 80
          targetPort: 80
  - path: appingress.yaml
    content: |
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: appingress
      spec:
        ingressClassName: nginx
        rules:
        - host: webapp.com
          http:
            paths:
            - path: /blue
              pathType: Prefix
              backend:
                service:
                  name: bluesvc
                  port:
                    number: 80
            - path: /green
              pathType: Prefix
              backend:
                service:
                  name: greensvc
                  port:
                    number: 80
tasks:
  - id_key: create-backends
    title: Create the apps and their Services
    points: 5
    is_stateful: true
    description: Apply `deploy.yaml`. It creates three apps (blue, green, todo), each with a ClusterIP Service. Check with `kubectl get deploy,svc`.
    verification_script: |
      #!/bin/bash
      for s in bluesvc greensvc todosvc; do
        test -n "$(kubectl get endpoints $s -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)" || exit 1
      done
    hint_context: "`kubectl apply -f deploy.yaml`"
    explanation_context: All three Services are ClusterIP, so none of them is reachable from outside yet. The Ingress will be the single way in.
    solution_script: kubectl apply -f deploy.yaml
  - id_key: path-ingress
    title: Route by path
    points: 15
    is_stateful: true
    description: |
      Apply `appingress.yaml` and run `kubectl describe ingress appingress` to read its rules: `webapp.com/blue` goes to `bluesvc` and `webapp.com/green` to `greensvc`.

      This sandbox has no ingress controller, so the ADDRESS column stays empty and no traffic flows. The rules are still stored and validated, exactly as on a real cluster.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get ingress appingress -o jsonpath='{.spec.rules[0].host} {.spec.rules[0].http.paths[*].backend.service.name}')" = "webapp.com bluesvc greensvc"
    hint_context: "`kubectl apply -f appingress.yaml`"
    explanation_context: One host, two paths, two Services. An ingress controller (installed once per cluster) would read these rules and route traffic.
    solution_script: kubectl apply -f appingress.yaml
  - id_key: host-ingress
    title: Write a host-based Ingress
    points: 20
    is_stateful: true
    description: |
      Write `todoingress.yaml`: an Ingress named `todoingress` with `ingressClassName: nginx` that sends **all** paths of the host `todoapp.com` to the Service `todosvc` on port 80. Apply it.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get ingress todoingress -o jsonpath='{.spec.rules[0].host} {.spec.rules[0].http.paths[0].path} {.spec.rules[0].http.paths[0].pathType} {.spec.rules[0].http.paths[0].backend.service.name} {.spec.rules[0].http.paths[0].backend.service.port.number}')" = "todoapp.com / Prefix todosvc 80"
    hint_context: Copy the structure of appingress.yaml. Use path `/` with pathType `Prefix` to match everything.
    explanation_context: "`path: /` with `pathType: Prefix` matches every URL on that host. Different hosts can share one ingress controller and one public IP."
    solution_script: |
      cat > todoingress.yaml <<'Y'
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: todoingress
      spec:
        ingressClassName: nginx
        rules:
        - host: todoapp.com
          http:
            paths:
            - path: /
              pathType: Prefix
              backend:
                service:
                  name: todosvc
                  port:
                    number: 80
      Y
      kubectl apply -f todoingress.yaml
  - id_key: tls-ingress
    title: Add HTTPS
    points: 20
    is_stateful: false
    description: |
      Create a self-signed certificate and store it in a TLS Secret named `todo-tls`:
      ```
      openssl req -x509 -nodes -days 30 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=todoapp.com"
      kubectl create secret tls todo-tls --cert=tls.crt --key=tls.key
      ```
      Then add a `tls` section to `todoingress` for host `todoapp.com` using that Secret, and apply it again.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get secret todo-tls -o jsonpath='{.type}')" = "kubernetes.io/tls" || exit 1
      test "$(kubectl get ingress todoingress -o jsonpath='{.spec.tls[0].secretName} {.spec.tls[0].hosts[0]}')" = "todo-tls todoapp.com"
    hint_context: "Under `spec`, add `tls:` with a list item that has `hosts: [\"todoapp.com\"]` and `secretName: todo-tls`."
    explanation_context: The ingress controller would serve HTTPS for todoapp.com with that certificate. In real clusters cert-manager creates and renews these Secrets for you.
    solution_script: |
      openssl req -x509 -nodes -days 30 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=todoapp.com" 2>/dev/null
      kubectl create secret tls todo-tls --cert=tls.crt --key=tls.key
      kubectl patch ingress todoingress --type=merge -p '{"spec":{"tls":[{"hosts":["todoapp.com"],"secretName":"todo-tls"}]}}'
---
