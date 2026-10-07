---
kind: lab
id_key: k8s/config-secrets/lab-configmap
course: fast-kubernetes
section: config-secrets
section_title: ConfigMaps & Secrets
section_position: 5
title: 'Lab: ConfigMaps'
position: 1
estimated_minutes: 20
source:
  - labs/configmap/configmap.yaml
  - labs/configmap/theme.txt
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
  - path: configmap.yaml
    content: |
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: myconfigmap
      data:
        db_server: "db.mindforge.test"
        database: "mydatabase"
        site.settings: |
          color=blue
          padding:25px
      ---
      apiVersion: v1
      kind: Pod
      metadata:
        name: configmappod
      spec:
        containers:
        - name: configmapcontainer
          image: nginx:1.27
          env:
          - name: DB_SERVER
            valueFrom:
              configMapKeyRef:
                name: myconfigmap
                key: db_server
          - name: DATABASE
            valueFrom:
              configMapKeyRef:
                name: myconfigmap
                key: database
          volumeMounts:
          - name: config-vol
            mountPath: "/config"
            readOnly: true
        volumes:
        - name: config-vol
          configMap:
            name: myconfigmap
  - path: theme.txt
    content: |
      theme=dark
tasks:
  - id_key: apply-configmap
    title: Create a ConfigMap and a pod that uses it
    points: 10
    is_stateful: true
    description: Apply `configmap.yaml`. Then run `kubectl describe configmap myconfigmap` and `kubectl describe pod configmappod`. Find where the pod gets `DB_SERVER` from and where `/config` is mounted.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}')" = "db.mindforge.test" || exit 1
      test "$(kubectl get pod configmappod -o jsonpath='{.status.phase}')" = "Running"
    hint_context: "`kubectl apply -f configmap.yaml`"
    explanation_context: On a real cluster, `kubectl exec configmappod -- printenv DB_SERVER` prints db.mindforge.test and `kubectl exec configmappod -- cat /config/site.settings` prints the settings file.
    solution_script: kubectl apply -f configmap.yaml
  - id_key: imperative-configmap
    title: Create a ConfigMap from the command line
    points: 15
    is_stateful: true
    description: Create a ConfigMap named `myconfigmap2` with a literal key `background=red` and the file `theme.txt`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get configmap myconfigmap2 -o jsonpath='{.data.background}')" = "red" || exit 1
      kubectl get configmap myconfigmap2 -o jsonpath='{.data.theme\.txt}' | grep -qx 'theme=dark'
    hint_context: "`kubectl create configmap <name> --from-literal=key=value --from-file=<file>`"
    explanation_context: "--from-literal adds one key directly. --from-file uses the file name (theme.txt) as the key and its content as the value."
    solution_script: kubectl create configmap myconfigmap2 --from-literal=background=red --from-file=theme.txt
  - id_key: envfrom-pod
    title: Load every key as environment variables
    points: 20
    is_stateful: false
    description: |
      Write and apply a pod named `envpod` (image `nginx:1.27`, container name `app`) that loads **all** keys of `myconfigmap2` as environment variables with `envFrom`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get pod envpod -o jsonpath='{.spec.containers[0].envFrom[0].configMapRef.name}')" = "myconfigmap2"
    hint_context: "Under the container, add `envFrom:` with a list item `- configMapRef:` whose `name:` is myconfigmap2."
    explanation_context: envFrom imports every key at once. Keys that are not valid variable names (like theme.txt, which contains a dot) are skipped, and an event reports it.
    solution_script: |
      cat > envpod.yaml <<'Y'
      apiVersion: v1
      kind: Pod
      metadata:
        name: envpod
      spec:
        containers:
        - name: app
          image: nginx:1.27
          envFrom:
          - configMapRef:
              name: myconfigmap2
      Y
      kubectl apply -f envpod.yaml
  - id_key: update-configmap
    title: Change a value
    points: 10
    is_stateful: false
    description: Change `db_server` in `myconfigmap` to `db2.mindforge.test` (edit the file and re-apply, or use `kubectl edit configmap myconfigmap`).
    verification_script: |
      #!/bin/bash
      test "$(kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}')" = "db2.mindforge.test"
    hint_context: Edit configmap.yaml and run `kubectl apply -f configmap.yaml` again.
    explanation_context: The file mounted at /config/db_server updates within about a minute, but the DB_SERVER environment variable in the running pod keeps the old value until the pod is recreated.
    solution_script: |
      sed -i 's/db.mindforge.test/db2.mindforge.test/' configmap.yaml
      kubectl apply -f configmap.yaml
---
