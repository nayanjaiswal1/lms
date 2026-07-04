---
kind: lab
id_key: k8s/config-secrets/lab-secret
course: fast-kubernetes
section: config-secrets
section_title: Configuration & Secrets
section_position: 4
title: 'Lab: Secret'
position: 2
estimated_minutes: 30
source:
    - labs/secret/config.json
    - labs/secret/password.txt
    - labs/secret/secret-pods.yaml
    - labs/secret/secret.yaml
    - labs/secret/server.txt
    - labs/secret/username.txt
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
    - path: config.json
      content: "{\r\n    \"apiKey\": \"6bba108d4b2212f2c30c71dfa279e1f77cc5c3b2\",\r\n}"
    - path: password.txt
      content: P@ssw0rd!
    - path: secret-pods.yaml
      content: "apiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: secretvolumepod\r\nspec:\r\n  containers:\r\n  - name: secretcontainer\r\n    image: nginx\r\n    volumeMounts:\r\n    - name: secret-vol\r\n      mountPath: /secret\r\n  volumes:\r\n  - name: secret-vol\r\n    secret:\r\n      secretName: mysecret\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: secretenvpod\r\nspec:\r\n  containers:\r\n  - name: secretcontainer\r\n    image: nginx\r\n    env:\r\n      - name: username\r\n        valueFrom:\r\n          secretKeyRef:\r\n            name: mysecret\r\n            key: db_username\r\n      - name: password\r\n        valueFrom:\r\n          secretKeyRef:\r\n            name: mysecret\r\n            key: db_password\r\n      - name: server\r\n        valueFrom:\r\n          secretKeyRef:\r\n            name: mysecret\r\n            key: db_server\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: secretenvallpod\r\nspec:\r\n  containers:\r\n  - name: secretcontainer\r\n    image: nginx\r\n    envFrom:\r\n    - secretRef:\r\n        name: mysecret"
    - path: secret.yaml
      content: "apiVersion: v1\r\nkind: Secret\r\nmetadata:\r\n  name: mysecret\r\ntype: Opaque\r\nstringData:\r\n  db_server: db.example.com\r\n  db_username: admin\r\n  db_password: P@ssw0rd!"
    - path: server.txt
      content: db.example.com
    - path: username.txt
      content: admin
tasks:
    - id_key: create-mysecret
      title: Create the mysecret Secret declaratively
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `secret.yaml` (already in your workdir) to create a Secret named **mysecret** of
        type **Opaque** with keys `db_server`, `db_username`, and `db_password` matching the
        values declared under `stringData`.
      verification_script: |
        #!/bin/bash
        kubectl get secret mysecret >/dev/null 2>&1 || exit 1
        kubectl get secret mysecret -o jsonpath='{.type}' | grep -qx Opaque || exit 1
        kubectl get secret mysecret -o jsonpath='{.data.db_server}' | base64 -d | grep -qx db.example.com || exit 1
        kubectl get secret mysecret -o jsonpath='{.data.db_username}' | base64 -d | grep -qx admin || exit 1
        kubectl get secret mysecret -o jsonpath='{.data.db_password}' | base64 -d | grep -qx 'P@ssw0rd!'
      hint_context: Use `kubectl apply -f secret.yaml`.
      explanation_context: |
        `stringData` is a write-only convenience field — the API server base64-encodes each
        entry into `.data` on creation and never stores `stringData` itself. Every subsequent
        read (`kubectl get secret -o yaml`, jsonpath, etc.) only ever sees the encoded `.data`
        map, which is why verification must decode before comparing.
      solution_script: kubectl apply -f secret.yaml
    - id_key: create-filecreds-literal
      title: Create the filecreds Secret imperatively from literal files
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Create a Secret named **filecreds** imperatively from `username.txt` and `password.txt`
        using `kubectl create secret generic`, mapping them to the keys `username` and
        `password` respectively (`--from-file=username=username.txt --from-file=password=password.txt`).
      verification_script: |
        #!/bin/bash
        kubectl get secret filecreds >/dev/null 2>&1 || exit 1
        kubectl get secret filecreds -o jsonpath='{.data.username}' | base64 -d | grep -qx admin || exit 1
        kubectl get secret filecreds -o jsonpath='{.data.password}' | base64 -d | grep -qx 'P@ssw0rd!'
      hint_context: |
        Use `kubectl create secret generic filecreds --from-file=username=username.txt
        --from-file=password=password.txt`.
      explanation_context: |
        `--from-file=key=path` reads the file's raw bytes and stores them under the given key —
        unlike `--from-file=path` alone, which would use the file's basename (`username.txt`) as
        the key instead. This is the imperative equivalent of hand-writing a Secret manifest.
      solution_script: kubectl create secret generic filecreds --from-file=username=username.txt --from-file=password=password.txt
    - id_key: create-secret-pods
      title: Create the three Secret-consuming Pods
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `secret-pods.yaml` to create three Pods that each consume **mysecret** a
        different way: `secretvolumepod` (volume mount), `secretenvpod` (per-key env vars via
        `secretKeyRef`), and `secretenvallpod` (all keys via `envFrom.secretRef`).
      verification_script: |
        #!/bin/bash
        for p in secretvolumepod secretenvpod secretenvallpod; do
          kubectl get pod "$p" --no-headers 2>/dev/null | grep -q Running || exit 1
        done
      hint_context: Use `kubectl apply -f secret-pods.yaml`. mysecret must already exist.
      explanation_context: |
        All three Pods declare `mysecret` as a dependency, either via `volumes[].secret.secretName`
        or `secretKeyRef`/`secretRef`. If the Secret doesn't exist yet, kubelet blocks the volume
        mount and env injection until it appears — so `mysecret` must be created before this step.
      solution_script: kubectl apply -f secret-pods.yaml
    - id_key: verify-secret-volume-mount
      title: Confirm secretvolumepod mounts mysecret at /secret
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that `secretvolumepod`'s `secret-vol` volume is backed by the **mysecret**
        Secret and mounted into `secretcontainer` at path `/secret`.
      verification_script: |
        #!/bin/bash
        kubectl get pod secretvolumepod -o jsonpath='{.spec.volumes[?(@.name=="secret-vol")].secret.secretName}' | grep -qx mysecret || exit 1
        kubectl get pod secretvolumepod -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name=="secret-vol")].mountPath}' | grep -qx /secret
      hint_context: |
        Inspect `.spec.volumes` for the `secret.secretName` field and
        `.spec.containers[0].volumeMounts` for a matching `name: secret-vol` entry.
      explanation_context: |
        A `secret`-type volume tells kubelet to project every key in the referenced Secret as a
        file inside the mount path — `db_server`, `db_username`, and `db_password` each become
        a file named after the key, containing the decoded value, under `/secret`.
      solution_script: kubectl get pod secretvolumepod -o yaml
    - id_key: verify-secret-env-refs
      title: Confirm secretenvpod and secretenvallpod reference mysecret correctly
      points: 20
      is_optional: false
      is_stateful: false
      description: |
        Confirm that `secretenvpod`'s `username`, `password`, and `server` environment variables
        resolve via `secretKeyRef` to `mysecret`'s `db_username`, `db_password`, and `db_server`
        keys, and that `secretenvallpod` imports every key from `mysecret` via `envFrom.secretRef`.
      verification_script: |
        #!/bin/bash
        kubectl get pod secretenvpod -o jsonpath='{.spec.containers[0].env[?(@.name=="username")].valueFrom.secretKeyRef.key}' | grep -qx db_username || exit 1
        kubectl get pod secretenvpod -o jsonpath='{.spec.containers[0].env[?(@.name=="password")].valueFrom.secretKeyRef.key}' | grep -qx db_password || exit 1
        kubectl get pod secretenvpod -o jsonpath='{.spec.containers[0].env[?(@.name=="server")].valueFrom.secretKeyRef.key}' | grep -qx db_server || exit 1
        kubectl get pod secretenvallpod -o jsonpath='{.spec.containers[0].envFrom[0].secretRef.name}' | grep -qx mysecret
      hint_context: |
        Inspect `.spec.containers[0].env[].valueFrom.secretKeyRef` on `secretenvpod` and
        `.spec.containers[0].envFrom[].secretRef` on `secretenvallpod`.
      explanation_context: |
        `secretKeyRef` injects one Secret key as one env var, letting you rename it freely (here
        `db_username` becomes `$username`); `envFrom.secretRef` instead injects every key in the
        Secret as an env var using the key name verbatim, trading control for brevity.
      solution_script: |
        kubectl get pod secretenvpod -o yaml
        kubectl get pod secretenvallpod -o yaml
---
