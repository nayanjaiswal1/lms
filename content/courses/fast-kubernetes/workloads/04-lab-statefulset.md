---
kind: lab
id_key: k8s/workloads/lab-statefulset
course: fast-kubernetes
section: workloads
section_title: Workloads & Controllers
section_position: 2
title: 'Lab: StatefulSet'
position: 3
estimated_minutes: 30
source:
    - labs/statefulset/statefulset.yaml
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
    - path: statefulset.yaml
      content: "apiVersion: v1\r\nkind: Service\r\nmetadata:\r\n  labels:\r\n    app: cassandra\r\n  name: cassandra\r\nspec:\r\n  clusterIP: None\r\n  ports:\r\n  - port: 9042\r\n  selector:\r\n    app: cassandra\r\n---\r\napiVersion: apps/v1\r\nkind: StatefulSet\r\nmetadata:\r\n  name: cassandra\r\n  labels:\r\n    app: cassandra\r\nspec:\r\n  serviceName: cassandra\r\n  replicas: 2\r\n  selector:\r\n    matchLabels:\r\n      app: cassandra\r\n  template:\r\n    metadata:\r\n      labels:\r\n        app: cassandra\r\n    spec:\r\n      terminationGracePeriodSeconds: 1800\r\n      containers:\r\n      - name: cassandra\r\n        image: gcr.io/google-samples/cassandra:v13\r\n        imagePullPolicy: Always\r\n        ports:\r\n        - containerPort: 7000\r\n          name: intra-node\r\n        - containerPort: 7001\r\n          name: tls-intra-node\r\n        - containerPort: 7199\r\n          name: jmx\r\n        - containerPort: 9042\r\n          name: cql\r\n        resources:\r\n          limits:\r\n            cpu: \"500m\"\r\n            memory: 1Gi\r\n          requests:\r\n            cpu: \"500m\"\r\n            memory: 1Gi\r\n        securityContext:\r\n          capabilities:\r\n            add:\r\n              - IPC_LOCK\r\n        lifecycle:\r\n          preStop:\r\n            exec:\r\n              command: \r\n              - /bin/sh\r\n              - -c\r\n              - nodetool drain\r\n        env:\r\n          - name: MAX_HEAP_SIZE\r\n            value: 512M\r\n          - name: HEAP_NEWSIZE\r\n            value: 100M\r\n          - name: CASSANDRA_SEEDS\r\n            value: \"cassandra-0.cassandra.default.svc.cluster.local\"\r\n          - name: CASSANDRA_CLUSTER_NAME\r\n            value: \"K8Demo\"\r\n          - name: CASSANDRA_DC\r\n            value: \"DC1-K8Demo\"\r\n          - name: CASSANDRA_RACK\r\n            value: \"Rack1-K8Demo\"\r\n          - name: POD_IP\r\n            valueFrom:\r\n              fieldRef:\r\n                fieldPath: status.podIP\r\n        readinessProbe:\r\n          exec:\r\n            command:\r\n            - /bin/bash\r\n            - -c\r\n            - /ready-probe.sh\r\n          initialDelaySeconds: 15\r\n          timeoutSeconds: 5\r\n        volumeMounts:\r\n        - name: cassandra-data\r\n          mountPath: /cassandra_data\r\n  volumeClaimTemplates:\r\n  - metadata:\r\n      name: cassandra-data\r\n    spec:\r\n      accessModes: [ \"ReadWriteOnce\" ]\r\n      storageClassName: standard\r\n      resources:\r\n        requests:\r\n          storage: 1Gi"
tasks:
    - id_key: create-cassandra-statefulset
      title: Create the cassandra headless Service and StatefulSet
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `statefulset.yaml` (already in your workdir) to create the headless Service and
        the StatefulSet, both named **cassandra**, with **2 replicas**.
      verification_script: |
        #!/bin/bash
        kubectl get statefulset cassandra >/dev/null 2>&1 || exit 1
        REPLICAS=$(kubectl get statefulset cassandra -o jsonpath='{.spec.replicas}' 2>/dev/null)
        test "${REPLICAS:-0}" -eq 2
      hint_context: Use `kubectl apply -f statefulset.yaml`.
      explanation_context: |
        `kubectl apply` creates both objects declared in the multi-document manifest — the
        headless Service `cassandra` and the StatefulSet `cassandra` with `replicas: 2`. This
        lab's cluster runs `kube-controller-manager` with a restricted `--controllers` allowlist
        that excludes `statefulset` (see the note on the last task below), so this check verifies
        the object was accepted and its desired spec is correct rather than that any Pod actually
        started — on a real cluster the StatefulSet controller would additionally create Pods one
        at a time, in order, waiting for each to become Ready before starting the next.
      solution_script: kubectl apply -f statefulset.yaml
    - id_key: verify-headless-service
      title: Confirm the cassandra Service is headless and governs the StatefulSet
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that the **cassandra** Service has `clusterIP: None` (headless), selects Pods
        labeled `app=cassandra`, and forwards port `9042`.
      verification_script: |
        #!/bin/bash
        kubectl get svc cassandra -o jsonpath='{.spec.clusterIP}' | grep -qx None || exit 1
        kubectl get svc cassandra -o jsonpath='{.spec.selector.app}' | grep -qx cassandra || exit 1
        kubectl get svc cassandra -o jsonpath='{.spec.ports[0].port}' | grep -qx 9042
      hint_context: |
        Inspect `kubectl get svc cassandra -o jsonpath='{.spec.clusterIP}'` — a headless Service
        has no cluster-assigned virtual IP.
      explanation_context: |
        A headless Service (`clusterIP: None`) skips load-balancing and virtual-IP allocation
        entirely — instead it publishes one DNS record per ready backing Pod
        (`<pod>.<svc>.<namespace>.svc.cluster.local`). A StatefulSet's `spec.serviceName` must
        point at a headless Service like this one to get per-Pod stable network identities.
      solution_script: kubectl get svc cassandra -o yaml
    - id_key: verify-container-and-security-spec
      title: Confirm the cassandra container's ports and security context
      points: 20
      is_optional: false
      is_stateful: false
      description: |
        Confirm the `cassandra` container in the Pod template declares its four named ports
        (`intra-node` 7000, `tls-intra-node` 7001, `jmx` 7199, `cql` 9042) and requests the
        `IPC_LOCK` capability (Cassandra uses it to lock memory pages and avoid swapping).
      verification_script: |
        #!/bin/bash
        PORTS=$(kubectl get statefulset cassandra -o jsonpath='{.spec.template.spec.containers[0].ports[*].name}')
        for p in intra-node tls-intra-node jmx cql; do
          echo "$PORTS" | grep -qw "$p" || exit 1
        done
        kubectl get statefulset cassandra -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.add[0]}' | grep -qx IPC_LOCK
      hint_context: |
        Inspect `.spec.template.spec.containers[0].ports` and
        `.spec.template.spec.containers[0].securityContext.capabilities.add` on the StatefulSet.
      explanation_context: |
        These fields live on the StatefulSet's own Pod template, so they're verifiable
        immediately after `kubectl apply` — independent of whether any Pod actually got created
        from that template (see the note on the last task in this lab).
      solution_script: kubectl get statefulset cassandra -o jsonpath='{.spec.template.spec.containers[0]}'
    - id_key: verify-stable-network-id
      title: Confirm the governing service wiring and predictable per-Pod DNS
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that the StatefulSet's `spec.serviceName` is set to `cassandra` (the headless
        Service), and that the container's `CASSANDRA_SEEDS` environment variable is pinned to
        the predictable per-Pod DNS name `cassandra-0.cassandra.default.svc.cluster.local` —
        proof that StatefulSet Pods get stable, resolvable hostnames that Deployment Pods never
        do.
      verification_script: |
        #!/bin/bash
        kubectl get statefulset cassandra -o jsonpath='{.spec.serviceName}' | grep -qx cassandra || exit 1
        kubectl get statefulset cassandra -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="CASSANDRA_SEEDS")].value}' | grep -qx cassandra-0.cassandra.default.svc.cluster.local
      hint_context: |
        Check `.spec.serviceName` on the StatefulSet, and `.spec.template.spec.containers[0].env`
        for the `CASSANDRA_SEEDS` entry.
      explanation_context: |
        `spec.serviceName` wires the StatefulSet to its governing headless Service, which is what
        makes `<pod>.<serviceName>.<namespace>.svc.cluster.local` resolvable per Pod. This
        manifest hardcodes `CASSANDRA_SEEDS` to `cassandra-0.cassandra...` specifically because
        `cassandra-0` is guaranteed to exist at a fixed name — every other Cassandra node
        bootstraps by gossiping to that one stable address.
      solution_script: |
        kubectl get statefulset cassandra -o jsonpath='{.spec.serviceName}'
        kubectl get statefulset cassandra -o jsonpath='{.spec.template.spec.containers[0].env}'
    - id_key: verify-volume-claim-template
      title: Confirm the per-replica volumeClaimTemplates declaration
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that the StatefulSet's `volumeClaimTemplates` declares a `cassandra-data` claim
        template with `ReadWriteOnce` access mode, `storageClassName: standard`, and a `1Gi`
        storage request — the template Kubernetes uses to provision one separate,
        stably-named PersistentVolumeClaim per replica (`cassandra-data-cassandra-0`,
        `cassandra-data-cassandra-1`, ...) on a cluster where the StatefulSet controller runs.
      verification_script: |
        #!/bin/bash
        kubectl get statefulset cassandra -o jsonpath='{.spec.volumeClaimTemplates[0].metadata.name}' | grep -qx cassandra-data || exit 1
        kubectl get statefulset cassandra -o jsonpath='{.spec.volumeClaimTemplates[0].spec.accessModes[0]}' | grep -qx ReadWriteOnce || exit 1
        kubectl get statefulset cassandra -o jsonpath='{.spec.volumeClaimTemplates[0].spec.storageClassName}' | grep -qx standard || exit 1
        kubectl get statefulset cassandra -o jsonpath='{.spec.volumeClaimTemplates[0].spec.resources.requests.storage}' | grep -qx 1Gi
      hint_context: |
        Inspect `.spec.volumeClaimTemplates[0]` on the StatefulSet object itself.
      explanation_context: |
        A Deployment's Pods sharing a single `PersistentVolumeClaim` would all mount the *same*
        volume — rarely what a stateful workload wants. `volumeClaimTemplates` instead provisions
        one PVC per ordinal, and each PVC survives Pod rescheduling because it is bound to the
        ordinal, not to any one Pod instance — `cassandra-1` always reattaches to
        `cassandra-data-cassandra-1` on a cluster where the controller actually creates them.
      solution_script: kubectl get statefulset cassandra -o jsonpath='{.spec.volumeClaimTemplates[0]}'
    - id_key: scale-cassandra-statefulset
      title: Scale the cassandra StatefulSet's desired replica count to 3
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Scale the **cassandra** StatefulSet's desired replica count up to **3** using
        `kubectl scale`.
      verification_script: |
        #!/bin/bash
        DESIRED=$(kubectl get statefulset cassandra -o jsonpath='{.spec.replicas}' 2>/dev/null)
        test "${DESIRED:-0}" -eq 3
      hint_context: Use `kubectl scale statefulset cassandra --replicas=3`.
      explanation_context: |
        `kubectl scale` only ever updates `.spec.replicas` — the desired state. On a real cluster
        the StatefulSet controller reconciles that desired state by adding the *next* ordinal
        (here `cassandra-2`) without renumbering or replacing existing Pods, and provisions a
        matching `cassandra-data-cassandra-2` PVC from `volumeClaimTemplates`.
      solution_script: kubectl scale statefulset cassandra --replicas=3
    - id_key: verify-controller-not-reconciling
      title: Understand why no Pods appear for this StatefulSet
      points: 10
      is_optional: false
      is_stateful: false
      description: |
        Confirm that, despite `.spec.replicas` being set, **no Pods with label `app=cassandra`
        exist** in this lab's cluster.
      verification_script: |
        #!/bin/bash
        COUNT=$(kubectl get pods -l app=cassandra --no-headers 2>/dev/null | wc -l)
        test "${COUNT:-1}" -eq 0
      hint_context: Run `kubectl get pods -l app=cassandra` and count the results.
      explanation_context: |
        This lab's control plane starts `kube-controller-manager` with an explicit
        `--controllers` allowlist (deployment, replicaset, namespace, endpoint, endpointslice,
        endpointslicemirroring, resourcequota, garbagecollector) that does **not** include
        `statefulset` — so nothing ever reconciles a StatefulSet's desired replica count into
        real Pods here, no matter how long you wait. Every task in this lab therefore checks the
        StatefulSet/Service's own declared spec, which the API server accepts and stores
        immediately, rather than runtime Pod/PVC state that only a running StatefulSet
        controller would produce. On a real cluster (or one with the controller enabled), the
        same manifests would produce real, ordered `cassandra-0`/`cassandra-1` Pods with their
        own PVCs.
      solution_script: kubectl get pods -l app=cassandra
---
