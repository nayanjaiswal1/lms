---
kind: lab
id_key: k8s/config-secrets/lab-configmap
course: fast-kubernetes
section: config-secrets
section_title: Configuration & Secrets
section_position: 4
title: 'Lab: ConfigMap'
position: 1
estimated_minutes: 30
source:
    - labs/configmap/configmap.yaml
    - labs/configmap/theme.txt
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
    - path: configmap.yaml
      content: "apiVersion: v1\r\nkind: ConfigMap\r\nmetadata:\r\n  name: myconfigmap\r\ndata:\r\n  db_server: \"db.example.com\"\r\n  database: \"mydatabase\"\r\n  site.settings: |\r\n    color=blue\r\n    padding:25px\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: configmappod\r\nspec:\r\n  containers:\r\n  - name: configmapcontainer\r\n    image: nginx\r\n    env:\r\n      - name: DB_SERVER\r\n        valueFrom:\r\n          configMapKeyRef:\r\n            name: myconfigmap\r\n            key: db_server\r\n      - name: DATABASE\r\n        valueFrom:\r\n          configMapKeyRef:\r\n            name: myconfigmap\r\n            key: database\r\n    volumeMounts:\r\n      - name: config-vol\r\n        mountPath: \"/config\"\r\n        readOnly: true\r\n  volumes:\r\n    - name: config-vol\r\n      configMap:\r\n        name: myconfigmap"
    - path: theme.txt
      content: theme=dark
tasks:
    - id_key: create-myconfigmap-and-pod
      title: Create the myconfigmap ConfigMap and configmappod Pod
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `configmap.yaml` (already in your workdir) to create a ConfigMap named
        **myconfigmap** and a Pod named **configmappod** that consumes it.
      verification_script: |
        #!/bin/bash
        kubectl get configmap myconfigmap >/dev/null 2>&1 || exit 1
        kubectl get pod configmappod --no-headers 2>/dev/null | grep -q Running
      hint_context: Use `kubectl apply -f configmap.yaml`.
      explanation_context: |
        `configmap.yaml` bundles a ConfigMap and a Pod in one manifest separated by `---` —
        `kubectl apply -f` creates both with a single command. The Pod references the
        ConfigMap by name, but Kubernetes does not validate that reference until the kubelet
        actually starts the container.
      solution_script: kubectl apply -f configmap.yaml
    - id_key: verify-configmap-data
      title: Confirm the myconfigmap data keys and values
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that **myconfigmap** holds the data keys declared in `configmap.yaml`:
        `db_server` = `db.example.com`, `database` = `mydatabase`, and a multi-line
        `site.settings` key containing `color=blue` and `padding:25px`.
      verification_script: |
        #!/bin/bash
        DBSERVER=$(kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}' 2>/dev/null)
        test "$DBSERVER" = "db.example.com" || exit 1
        DATABASE=$(kubectl get configmap myconfigmap -o jsonpath='{.data.database}' 2>/dev/null)
        test "$DATABASE" = "mydatabase" || exit 1
        SETTINGS=$(kubectl get configmap myconfigmap -o jsonpath="{.data['site\.settings']}" 2>/dev/null)
        echo "$SETTINGS" | grep -q "color=blue" || exit 1
        echo "$SETTINGS" | grep -q "padding:25px"
      hint_context: |
        Use `kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}'` and the
        equivalent for `database` and `site.settings` — bracket notation
        (`{.data['site\.settings']}`) is required for a key that itself contains a dot.
      explanation_context: |
        A ConfigMap's `data` field is a flat map of string keys to string values. Keys with
        dots (like `site.settings`, used here to mimic a filename) still parse fine, but
        jsonpath needs bracket-escaped notation to disambiguate the dot in the key from the
        path separator.
      solution_script: |
        kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}'
        kubectl get configmap myconfigmap -o jsonpath='{.data.database}'
        kubectl get configmap myconfigmap -o jsonpath="{.data['site\.settings']}"
    - id_key: verify-pod-env-from-configmap
      title: Confirm configmappod's env vars reference myconfigmap
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that `configmapcontainer` in **configmappod** defines environment variables
        `DB_SERVER` and `DATABASE`, each sourced via `configMapKeyRef` from **myconfigmap**'s
        `db_server` and `database` keys respectively.
      verification_script: |
        #!/bin/bash
        kubectl get pod configmappod -o jsonpath='{.spec.containers[0].env[?(@.name=="DB_SERVER")].valueFrom.configMapKeyRef.name}' | grep -qx myconfigmap || exit 1
        kubectl get pod configmappod -o jsonpath='{.spec.containers[0].env[?(@.name=="DB_SERVER")].valueFrom.configMapKeyRef.key}' | grep -qx db_server || exit 1
        kubectl get pod configmappod -o jsonpath='{.spec.containers[0].env[?(@.name=="DATABASE")].valueFrom.configMapKeyRef.name}' | grep -qx myconfigmap || exit 1
        kubectl get pod configmappod -o jsonpath='{.spec.containers[0].env[?(@.name=="DATABASE")].valueFrom.configMapKeyRef.key}' | grep -qx database
      hint_context: |
        Inspect `.spec.containers[0].env` with a jsonpath filter on `@.name` and look at each
        entry's `valueFrom.configMapKeyRef`.
      explanation_context: |
        `configMapKeyRef` injects a single ConfigMap key as one environment variable at
        container start — unlike mounting the whole ConfigMap as a volume, this pattern lets
        each env var pull from a different key (or even a different ConfigMap) independently.
      solution_script: kubectl get pod configmappod -o jsonpath='{.spec.containers[0].env}'
    - id_key: verify-configmap-volume-mount
      title: Confirm configmappod mounts myconfigmap as a read-only volume
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that **configmappod** defines a volume named `config-vol` backed by
        **myconfigmap**, and that `configmapcontainer` mounts it read-only at `/config`.
      verification_script: |
        #!/bin/bash
        kubectl get pod configmappod -o jsonpath='{.spec.volumes[?(@.name=="config-vol")].configMap.name}' | grep -qx myconfigmap || exit 1
        kubectl get pod configmappod -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name=="config-vol")].mountPath}' | grep -qx /config || exit 1
        kubectl get pod configmappod -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name=="config-vol")].readOnly}' | grep -qx true
      hint_context: |
        Check `.spec.volumes` for a `configMap` volume source named `config-vol`, then check
        `.spec.containers[0].volumeMounts` for a matching entry with `mountPath: /config` and
        `readOnly: true`.
      explanation_context: |
        Mounting a ConfigMap as a volume exposes every key as a file inside the mount path
        (here, `/config/db_server`, `/config/database`, `/config/site.settings`) rather than a
        single env var — useful for config files an app reads from disk. `readOnly: true`
        prevents the container from ever writing back into the projected ConfigMap volume.
      solution_script: kubectl get pod configmappod -o jsonpath='{.spec.volumes}{"\n"}{.spec.containers[0].volumeMounts}'
    - id_key: create-configmap-from-file
      title: Create a ConfigMap from the theme.txt file
      points: 20
      is_optional: false
      is_stateful: true
      description: |
        Using `theme.txt` (already in your workdir, containing `theme=dark`), create a new
        ConfigMap named **themeconfig** with `kubectl create configmap --from-file`, so the
        ConfigMap ends up with a data key named `theme.txt` holding the file's contents.
      verification_script: |
        #!/bin/bash
        kubectl get configmap themeconfig >/dev/null 2>&1 || exit 1
        kubectl get configmap themeconfig -o jsonpath="{.data['theme\.txt']}" | grep -q "theme=dark"
      hint_context: Use `kubectl create configmap themeconfig --from-file=theme.txt`.
      explanation_context: |
        `--from-file=theme.txt` (with no `key=` prefix) uses the base filename as the data key
        and the file's full contents as the value — the resulting ConfigMap is functionally
        equivalent to hand-writing a `data` block in YAML, but generated straight from a file
        already on disk.
      solution_script: kubectl create configmap themeconfig --from-file=theme.txt
---
