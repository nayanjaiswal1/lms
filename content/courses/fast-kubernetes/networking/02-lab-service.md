---
kind: lab
id_key: k8s/networking/lab-service
course: fast-kubernetes
section: networking
section_title: Networking
section_position: 3
title: 'Lab: Service'
position: 1
estimated_minutes: 30
source:
    - labs/service/backend_clusterip.yaml
    - labs/service/backend_loadbalancer.yaml
    - labs/service/backend_nodeport.yaml
    - labs/service/deploy.yaml
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
    - path: backend_clusterip.yaml
      content: "apiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  name: backend\r\nspec:\r\n  type: ClusterIP\r\n  selector:\r\n    app: backend\r\n  ports:\r\n    - protocol: TCP\r\n      port: 5000\r\n      targetPort: 5000"
    - path: backend_loadbalancer.yaml
      content: "apiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  name: frontendlb\r\nspec:\r\n  type: LoadBalancer\r\n  selector:\r\n    app: frontend\r\n  ports:\r\n    - protocol: TCP\r\n      port: 80\r\n      targetPort: 80"
    - path: backend_nodeport.yaml
      content: "apiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  name: frontend\r\nspec:\r\n  type: NodePort\r\n  selector:\r\n    app: frontend\r\n  ports:\r\n    - protocol: TCP\r\n      port: 80\r\n      targetPort: 80"
    - path: deploy.yaml
      content: "apiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: frontend\r\n  labels:\r\n    team: development\r\nspec:\r\n  replicas: 3\r\n  selector:\r\n    matchLabels:\r\n      app: frontend\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: frontend\r\n    spec:\r\n      containers:\r\n      - name: frontend\r\n        image: nginx:latest\r\n        ports:\r\n        - containerPort: 80\r\n---\r\napiVersion: apps/v1\r\nkind: Deployment\r\nmetadata:\r\n  name: backend\r\n  labels:\r\n    team: development\r\nspec:\r\n  replicas: 3\r\n  selector:\r\n    matchLabels:\r\n      app: backend\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: backend\r\n    spec:\r\n      containers:\r\n      - name: backend\r\n        image: ozgurozturknet/k8s:backend\r\n        ports:\r\n        - containerPort: 5000"
tasks:
    - id_key: create-deployments
      title: Create the frontend and backend Deployments
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `deploy.yaml` to create two Deployments: **frontend** (3 replicas, image
        `nginx:latest`, label `app=frontend`) and **backend** (3 replicas, image
        `ozgurozturknet/k8s:backend`, label `app=backend`).
      verification_script: |
        #!/bin/bash
        kubectl get deployment frontend >/dev/null 2>&1 || exit 1
        kubectl get deployment backend >/dev/null 2>&1 || exit 1
        FREADY=$(kubectl get deployment frontend -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        BREADY=$(kubectl get deployment backend -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        test "${FREADY:-0}" -ge 3 && test "${BREADY:-0}" -ge 3
      hint_context: Use `kubectl apply -f deploy.yaml`.
      explanation_context: |
        `deploy.yaml` bundles two Deployments in one manifest separated by `---` — `kubectl apply
        -f` creates both with a single command, each producing its own ReplicaSet and Pods
        matching its own selector.
      solution_script: kubectl apply -f deploy.yaml
    - id_key: create-backend-clusterip
      title: Expose backend via a ClusterIP Service
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `backend_clusterip.yaml` to create a Service named **backend** of type
        **ClusterIP** that selects Pods labeled `app=backend` and forwards port `5000` to
        `targetPort 5000`.
      verification_script: |
        #!/bin/bash
        kubectl get svc backend >/dev/null 2>&1 || exit 1
        kubectl get svc backend -o jsonpath='{.spec.type}' | grep -qx ClusterIP || exit 1
        kubectl get svc backend -o jsonpath='{.spec.selector.app}' | grep -qx backend || exit 1
        kubectl get svc backend -o jsonpath='{.spec.ports[0].port}' | grep -qx 5000
      hint_context: Use `kubectl apply -f backend_clusterip.yaml`.
      explanation_context: |
        ClusterIP is the default Service type — it allocates a stable virtual IP reachable only
        inside the cluster, and its `selector` determines which Pods' endpoints get
        load-balanced behind it.
      solution_script: kubectl apply -f backend_clusterip.yaml
    - id_key: create-frontend-nodeport
      title: Expose frontend via a NodePort Service
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `backend_nodeport.yaml` to create a Service named **frontend** of type
        **NodePort** that selects Pods labeled `app=frontend` and forwards port `80`.
      verification_script: |
        #!/bin/bash
        kubectl get svc frontend >/dev/null 2>&1 || exit 1
        kubectl get svc frontend -o jsonpath='{.spec.type}' | grep -qx NodePort || exit 1
        kubectl get svc frontend -o jsonpath='{.spec.selector.app}' | grep -qx frontend || exit 1
        kubectl get svc frontend -o jsonpath='{.spec.ports[0].port}' | grep -qx 80
      hint_context: Use `kubectl apply -f backend_nodeport.yaml`.
      explanation_context: |
        NodePort builds on ClusterIP by additionally opening the same port on every cluster node
        (default range 30000-32767), making the Service reachable from outside the cluster
        without a cloud load balancer.
      solution_script: kubectl apply -f backend_nodeport.yaml
    - id_key: create-frontendlb
      title: Expose frontend via a LoadBalancer Service
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `backend_loadbalancer.yaml` to create a Service named **frontendlb** of type
        **LoadBalancer** that selects Pods labeled `app=frontend` and forwards port `80`.
      verification_script: |
        #!/bin/bash
        kubectl get svc frontendlb >/dev/null 2>&1 || exit 1
        kubectl get svc frontendlb -o jsonpath='{.spec.type}' | grep -qx LoadBalancer || exit 1
        kubectl get svc frontendlb -o jsonpath='{.spec.selector.app}' | grep -qx frontend
      hint_context: Use `kubectl apply -f backend_loadbalancer.yaml`.
      explanation_context: |
        LoadBalancer builds on NodePort and asks the cloud provider's controller to provision an
        external load balancer forwarding to the node ports — on a local cluster the external IP
        typically stays `<pending>`, but the Service object and its declared type are what this
        check confirms.
      solution_script: kubectl apply -f backend_loadbalancer.yaml
    - id_key: verify-backend-selector-matches
      title: Confirm the backend Service targets the backend Deployment's Pods
      points: 10
      is_optional: false
      is_stateful: false
      description: |
        Confirm that the **backend** Service's selector (`app=backend`) matches the Pod template
        labels on the **backend** Deployment, so traffic sent to the Service actually reaches
        those Pods.
      verification_script: |
        #!/bin/bash
        SVC_SEL=$(kubectl get svc backend -o jsonpath='{.spec.selector.app}' 2>/dev/null)
        DEP_LABEL=$(kubectl get deployment backend -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
        test -n "$SVC_SEL" && test "$SVC_SEL" = "$DEP_LABEL"
      hint_context: |
        Compare `kubectl get svc backend -o jsonpath='{.spec.selector}'` against
        `kubectl get deployment backend -o jsonpath='{.spec.template.metadata.labels}'`.
      explanation_context: |
        A Service has no idea what a "Deployment" is — it only watches for Pods whose labels
        match its `selector` and adds their IPs to its Endpoints/EndpointSlice. If the selector
        and Pod template labels drift apart, the Service silently ends up with zero endpoints.
      solution_script: |
        kubectl get svc backend -o jsonpath='{.spec.selector}'
        kubectl get deployment backend -o jsonpath='{.spec.template.metadata.labels}'
    - id_key: verify-nodeport-range
      title: Confirm the frontend Service was allocated a valid NodePort
      points: 10
      is_optional: false
      is_stateful: false
      description: |
        Confirm that the **frontend** NodePort Service was allocated a `nodePort` value in the
        default range `30000-32767`.
      verification_script: |
        #!/bin/bash
        NP=$(kubectl get svc frontend -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
        test -n "$NP" && test "$NP" -ge 30000 && test "$NP" -le 32767
      hint_context: Use `kubectl get svc frontend -o jsonpath='{.spec.ports[0].nodePort}'`.
      explanation_context: |
        When a NodePort Service's manifest doesn't pin `nodePort` explicitly, the API server
        auto-allocates one from the cluster's configured range — confirming this shows the
        Service is fully provisioned, not just accepted by `kubectl apply`.
      solution_script: kubectl get svc frontend -o jsonpath='{.spec.ports[0].nodePort}'
---
