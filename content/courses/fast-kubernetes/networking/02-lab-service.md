---
kind: lab
id_key: k8s/networking/lab-service
course: fast-kubernetes
section: networking
section_title: Services & Networking
section_position: 4
title: 'Lab: Services'
position: 1
estimated_minutes: 30
source:
  - labs/service/deploy.yaml
  - labs/service/backend_clusterip.yaml
  - labs/service/backend_nodeport.yaml
  - labs/service/backend_loadbalancer.yaml
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
  - path: deploy.yaml
    content: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: frontend
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
            - name: frontend
              image: nginx:1.27
              ports:
              - containerPort: 80
      ---
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: backend
        labels:
          team: development
      spec:
        replicas: 3
        selector:
          matchLabels:
            app: backend
        template:
          metadata:
            labels:
              app: backend
          spec:
            containers:
            - name: backend
              image: ozgurozturknet/k8s:backend
              ports:
              - containerPort: 5000
  - path: backend_clusterip.yaml
    content: |
      apiVersion: v1
      kind: Service
      metadata:
        name: backend
      spec:
        type: ClusterIP
        selector:
          app: backend
        ports:
        - protocol: TCP
          port: 5000
          targetPort: 5000
  - path: frontend_lb.yaml
    content: |
      apiVersion: v1
      kind: Service
      metadata:
        name: frontendlb
      spec:
        type: LoadBalancer
        selector:
          app: frontend
        ports:
        - protocol: TCP
          port: 80
          targetPort: 80
  - path: broken-svc.yaml
    content: |
      # This Service "doesn't work". Find out why and fix it.
      apiVersion: v1
      kind: Service
      metadata:
        name: api
      spec:
        selector:
          app: backnd
        ports:
        - port: 80
          targetPort: 5000
tasks:
  - id_key: create-deployments
    title: Create the frontend and backend
    points: 5
    is_stateful: true
    description: Apply `deploy.yaml`. It creates two Deployments with 3 pods each. Run `kubectl get pods -o wide --show-labels` and note that each pod has its own IP.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get deployment frontend -o jsonpath='{.status.readyReplicas}')" = "3" || exit 1
      test "$(kubectl get deployment backend -o jsonpath='{.status.readyReplicas}')" = "3"
    hint_context: "`kubectl apply -f deploy.yaml`"
    explanation_context: Six pods, six different IPs. These IPs change whenever pods are replaced, which is why you need Services.
    solution_script: kubectl apply -f deploy.yaml
  - id_key: clusterip-service
    title: Put a ClusterIP Service in front of the backend
    points: 15
    is_stateful: true
    description: Apply `backend_clusterip.yaml`. Then run `kubectl get endpoints backend` and compare the IPs with `kubectl get pods -l app=backend -o wide`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get svc backend -o jsonpath='{.spec.type}')" = "ClusterIP" || exit 1
      test "$(kubectl get endpoints backend -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)" = "3"
    hint_context: "`kubectl apply -f backend_clusterip.yaml`, then `kubectl get endpoints backend`."
    explanation_context: The Service matched the 3 pods labeled app=backend. Their IPs appear as endpoints. Inside the cluster, other pods can now call http://backend:5000.
    solution_script: kubectl apply -f backend_clusterip.yaml
  - id_key: nodeport-expose
    title: Expose the frontend with a NodePort
    points: 15
    is_stateful: false
    description: Create a NodePort Service named `frontend` for the `frontend` Deployment on port 80, using `kubectl expose`. Look at the PORT(S) column of `kubectl get svc frontend` to find the node port it got.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get svc frontend -o jsonpath='{.spec.type} {.spec.ports[0].port} {.spec.selector.app}')" = "NodePort 80 frontend" || exit 1
      P=$(kubectl get svc frontend -o jsonpath='{.spec.ports[0].nodePort}'); [ "$P" -ge 30000 ] && [ "$P" -le 32767 ]
    hint_context: "`kubectl expose deployment <name> --type=NodePort --port=<port>`"
    explanation_context: expose copied the Deployment's selector (app=frontend). The PORT(S) column shows 80:3xxxx, meaning Service port 80 and node port 3xxxx, which is opened on every node.
    solution_script: kubectl expose deployment frontend --type=NodePort --port=80
  - id_key: loadbalancer-service
    title: Create a LoadBalancer Service
    points: 10
    is_stateful: false
    description: Apply `frontend_lb.yaml` and look at `kubectl get svc frontendlb`. Why is EXTERNAL-IP stuck on `<pending>`?
    verification_script: |
      #!/bin/bash
      test "$(kubectl get svc frontendlb -o jsonpath='{.spec.type}')" = "LoadBalancer"
    hint_context: "`kubectl apply -f frontend_lb.yaml`"
    explanation_context: There is no cloud provider in this sandbox (or on a laptop), so nobody creates the external load balancer. On EKS/GKE/AKS a public IP would appear within a minute or two.
    solution_script: kubectl apply -f frontend_lb.yaml
  - id_key: fix-broken-service
    title: Debug a broken Service
    points: 20
    is_stateful: false
    description: |
      Apply `broken-svc.yaml`. The `api` Service should send traffic to the backend pods, but `kubectl get endpoints api` is empty. Find the bug, fix the file, and apply it again.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get endpoints api -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)" = "3"
    hint_context: Compare the Service's selector with the labels on the backend pods (`kubectl get pods --show-labels`).
    explanation_context: The selector said `app=backnd` (a typo), which matches no pods, so the Service had no endpoints. Label/selector mismatches are the most common reason a Service "does not work".
    solution_script: |
      sed -i 's/app: backnd/app: backend/' broken-svc.yaml
      kubectl apply -f broken-svc.yaml
---
