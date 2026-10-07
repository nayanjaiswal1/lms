---
kind: lab
id_key: k8s/config-secrets/lab-secret
course: fast-kubernetes
section: config-secrets
section_title: ConfigMaps & Secrets
section_position: 5
title: 'Lab: Secrets'
position: 2
estimated_minutes: 25
source:
  - labs/secret/secret.yaml
  - labs/secret/secret-pods.yaml
  - labs/secret/config.json
  - labs/secret/username.txt
  - labs/secret/password.txt
  - labs/secret/server.txt
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
  - path: secret.yaml
    content: |
      apiVersion: v1
      kind: Secret
      metadata:
        name: mysecret
      type: Opaque
      stringData:
        db_server: db.mindforge.test
        db_username: admin
        db_password: P@ssw0rd!
  - path: secret-pods.yaml
    content: |
      apiVersion: v1
      kind: Pod
      metadata:
        name: secretvolumepod
      spec:
        containers:
        - name: secretcontainer
          image: nginx:1.27
          volumeMounts:
          - name: secret-vol
            mountPath: /secret
        volumes:
        - name: secret-vol
          secret:
            secretName: mysecret
      ---
      apiVersion: v1
      kind: Pod
      metadata:
        name: secretenvpod
      spec:
        containers:
        - name: secretcontainer
          image: nginx:1.27
          env:
          - name: username
            valueFrom:
              secretKeyRef:
                name: mysecret
                key: db_username
          - name: password
            valueFrom:
              secretKeyRef:
                name: mysecret
                key: db_password
          - name: server
            valueFrom:
              secretKeyRef:
                name: mysecret
                key: db_server
      ---
      apiVersion: v1
      kind: Pod
      metadata:
        name: secretenvallpod
      spec:
        containers:
        - name: secretcontainer
          image: nginx:1.27
          envFrom:
          - secretRef:
              name: mysecret
  - path: username.txt
    content: admin
  - path: password.txt
    content: S3cure-Pa55
  - path: server.txt
    content: db.mindforge.test
  - path: config.json
    content: |
      {
        "apiKey": "7ac4108d4b2212f2c30c71dfa279e1f77dd12356"
      }
tasks:
  - id_key: apply-secret
    title: Create a Secret and three pods that use it
    points: 10
    is_stateful: true
    description: Apply `secret.yaml`, then `secret-pods.yaml`. The three pods read the same Secret as files, as chosen variables, and as all variables. Run `kubectl describe secret mysecret`. Notice it shows sizes, not values.
    verification_script: |
      #!/bin/bash
      kubectl get secret mysecret >/dev/null 2>&1 || exit 1
      for p in secretvolumepod secretenvpod secretenvallpod; do
        test "$(kubectl get pod $p -o jsonpath='{.status.phase}')" = "Running" || exit 1
      done
    hint_context: Apply both files with `kubectl apply -f`, secret first.
    explanation_context: On a real cluster, `kubectl exec secretvolumepod -- cat /secret/db_password` and `kubectl exec secretenvpod -- printenv password` both show the password.
    solution_script: |
      kubectl apply -f secret.yaml
      kubectl apply -f secret-pods.yaml
  - id_key: decode-secret
    title: See that base64 is not encryption
    points: 10
    is_stateful: false
    description: |
      Read the stored password with `kubectl get secret mysecret -o jsonpath='{.data.db_password}'` and decode it with `base64 -d`. Save the decoded value to `~/work/decoded.txt`.
    verification_script: |
      #!/bin/bash
      grep -qx 'P@ssw0rd!' /home/labuser/work/decoded.txt
    hint_context: Pipe the jsonpath output into `base64 -d` and redirect it to decoded.txt.
    explanation_context: Anyone with read access to Secrets can decode them in one line. That is why access to Secrets must be limited with RBAC, and real values must not be stored in Git as plain manifests.
    solution_script: kubectl get secret mysecret -o jsonpath='{.data.db_password}' | base64 -d > /home/labuser/work/decoded.txt
  - id_key: secret-from-files
    title: Create a Secret from files
    points: 15
    is_stateful: false
    description: Create a Secret named `mysecret3` with the keys `db_server`, `db_username` and `db_password`, taken from `server.txt`, `username.txt` and `password.txt`. This keeps the password out of your shell history.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get secret mysecret3 -o jsonpath='{.data.db_password}' | base64 -d)" = "S3cure-Pa55" || exit 1
      test "$(kubectl get secret mysecret3 -o jsonpath='{.data.db_username}' | base64 -d)" = "admin"
    hint_context: "`--from-file=<key>=<file>` sets the key name. Repeat it for each key."
    explanation_context: "`kubectl create secret generic mysecret3 --from-file=db_server=server.txt --from-file=db_username=username.txt --from-file=db_password=password.txt`"
    solution_script: kubectl create secret generic mysecret3 --from-file=db_server=server.txt --from-file=db_username=username.txt --from-file=db_password=password.txt
  - id_key: secret-json-file
    title: Store a whole file as a Secret
    points: 10
    is_stateful: false
    description: Create a Secret named `mysecret4` from `config.json` (the key should be the file name).
    verification_script: |
      #!/bin/bash
      kubectl get secret mysecret4 -o jsonpath='{.data.config\.json}' | base64 -d | grep -q apiKey
    hint_context: "`kubectl create secret generic <name> --from-file=<file>`"
    explanation_context: Mounted as a volume, this becomes a file config.json that the app can read directly.
    solution_script: kubectl create secret generic mysecret4 --from-file=config.json
  - id_key: registry-secret
    title: Create a registry login Secret
    points: 15
    is_stateful: false
    description: |
      Create a `docker-registry` Secret named `regcred` for the server `registry.mindforge.test`, user `ci`, password `token123`. Then create a pod `private-pod` (image `registry.mindforge.test/team/app:1.0`) that uses it through `imagePullSecrets`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get secret regcred -o jsonpath='{.type}')" = "kubernetes.io/dockerconfigjson" || exit 1
      test "$(kubectl get pod private-pod -o jsonpath='{.spec.imagePullSecrets[0].name}')" = "regcred"
    hint_context: "`kubectl create secret docker-registry regcred --docker-server=... --docker-username=... --docker-password=...`. In the pod spec, `imagePullSecrets:` is a list of `- name:` entries at the same level as `containers`."
    explanation_context: The kubelet uses the credentials in regcred to pull the private image. Without it the pod would end up in ImagePullBackOff.
    solution_script: |
      kubectl create secret docker-registry regcred --docker-server=registry.mindforge.test --docker-username=ci --docker-password=token123
      cat > private-pod.yaml <<'Y'
      apiVersion: v1
      kind: Pod
      metadata:
        name: private-pod
      spec:
        imagePullSecrets:
        - name: regcred
        containers:
        - name: app
          image: registry.mindforge.test/team/app:1.0
      Y
      kubectl apply -f private-pod.yaml
---
