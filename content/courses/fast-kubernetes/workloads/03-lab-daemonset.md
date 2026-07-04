---
kind: lab
id_key: k8s/workloads/lab-daemonset
course: fast-kubernetes
section: workloads
section_title: Workloads & Controllers
section_position: 2
title: 'Lab: DaemonSet'
position: 2
estimated_minutes: 30
source:
    - labs/daemonset/daemonset.yaml
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
    - path: daemonset.yaml
      content: "apiVersion: apps/v1\r\nkind: DaemonSet\r\nmetadata:\r\n  name: logdaemonset\r\n  labels:\r\n    app: fluentd-logging\r\nspec:\r\n  selector:\r\n    matchLabels:\r\n      name: fluentd-elasticsearch\r\n  template:\r\n    metadata:\r\n      labels:\r\n        name: fluentd-elasticsearch\r\n    spec:\r\n      tolerations:\r\n      # this toleration is to have the daemonset runnable on master nodes\r\n      # remove it if your masters can't run pods\r\n      - key: node-role.kubernetes.io/master\r\n        effect: NoSchedule\r\n      containers:\r\n      - name: fluentd-elasticsearch\r\n        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2\r\n        resources:\r\n          limits:\r\n            memory: 200Mi\r\n          requests:\r\n            cpu: 100m\r\n            memory: 200Mi\r\n        volumeMounts:\r\n        - name: varlog\r\n          mountPath: /var/log\r\n        - name: varlibdockercontainers\r\n          mountPath: /var/lib/docker/containers\r\n          readOnly: true\r\n      terminationGracePeriodSeconds: 30\r\n      volumes:\r\n      - name: varlog\r\n        hostPath:\r\n          path: /var/log\r\n      - name: varlibdockercontainers\r\n        hostPath:\r\n          path: /var/lib/docker/containers"
tasks:
    - id_key: create-logdaemonset
      title: Create the logdaemonset DaemonSet
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `daemonset.yaml` (already in your workdir) to create a DaemonSet named
        **logdaemonset** with label `app=fluentd-logging` and pod selector
        `matchLabels: name=fluentd-elasticsearch`.
      verification_script: |
        #!/bin/bash
        kubectl get daemonset logdaemonset >/dev/null 2>&1 || exit 1
        kubectl get daemonset logdaemonset -o jsonpath='{.metadata.labels.app}' | grep -qx fluentd-logging || exit 1
        kubectl get daemonset logdaemonset -o jsonpath='{.spec.selector.matchLabels.name}' | grep -qx fluentd-elasticsearch
      hint_context: Use `kubectl apply -f daemonset.yaml`.
      explanation_context: |
        `kubectl apply` creates the DaemonSet API object from the manifest. Unlike a Deployment, a
        DaemonSet has no `replicas` field — its `.spec.selector` must match
        `.spec.template.metadata.labels` exactly, and the DaemonSet controller normally uses that
        template to run one Pod per eligible node.
      solution_script: kubectl apply -f daemonset.yaml
    - id_key: verify-pod-template-container
      title: Confirm the fluentd-elasticsearch container spec
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that `logdaemonset`'s pod template defines a single container named
        **fluentd-elasticsearch** running image `quay.io/fluentd_elasticsearch/fluentd:v2.5.2`,
        with a memory limit of `200Mi` and requests of `cpu: 100m` / `memory: 200Mi`.
      verification_script: |
        #!/bin/bash
        NAME=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].name}')
        IMAGE=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].image}')
        LIMIT=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')
        REQCPU=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
        REQMEM=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}')
        echo "$NAME" | grep -qx fluentd-elasticsearch || exit 1
        echo "$IMAGE" | grep -qx "quay.io/fluentd_elasticsearch/fluentd:v2.5.2" || exit 1
        echo "$LIMIT" | grep -qx 200Mi || exit 1
        echo "$REQCPU" | grep -qx 100m || exit 1
        echo "$REQMEM" | grep -qx 200Mi
      hint_context: |
        Inspect `.spec.template.spec.containers[0]` with `kubectl get daemonset logdaemonset -o yaml`.
      explanation_context: |
        A DaemonSet's `.spec.template` is the Pod template every node-local copy is stamped from —
        it is structurally identical to a Deployment's template. Setting `resources.limits.memory`
        without a matching `resources.limits.cpu` leaves the container's CPU unbounded while still
        capping memory.
      solution_script: kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0]}'
    - id_key: verify-hostpath-volumes
      title: Confirm the hostPath volumes and mounts
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm `logdaemonset` declares two `hostPath` volumes — **varlog** (`/var/log`) and
        **varlibdockercontainers** (`/var/lib/docker/containers`) — and that the container mounts
        `varlibdockercontainers` as `readOnly`.
      verification_script: |
        #!/bin/bash
        VARLOG=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.volumes[?(@.name=="varlog")].hostPath.path}')
        VARLIB=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.volumes[?(@.name=="varlibdockercontainers")].hostPath.path}')
        echo "$VARLOG" | grep -qx /var/log || exit 1
        echo "$VARLIB" | grep -qx /var/lib/docker/containers || exit 1
        RO=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.name=="varlibdockercontainers")].readOnly}')
        echo "$RO" | grep -qx true
      hint_context: |
        Inspect `.spec.template.spec.volumes` and `.spec.template.spec.containers[0].volumeMounts`
        with `kubectl get daemonset logdaemonset -o yaml`.
      explanation_context: |
        `hostPath` volumes mount a path from the **node's own filesystem** into the Pod — this is
        how a logging DaemonSet like fluentd reads every other Pod's log files (`/var/log`) and
        container runtime state (`/var/lib/docker/containers`) without those files ever going
        through the container image. Mounting the containers directory `readOnly: true` stops the
        log shipper from ever mutating runtime state it only needs to read.
      solution_script: kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.volumes}'
    - id_key: verify-master-toleration
      title: Confirm the master-node toleration
      points: 10
      is_optional: false
      is_stateful: false
      description: |
        Confirm `logdaemonset`'s pod template tolerates the `node-role.kubernetes.io/master` taint
        with effect `NoSchedule`, as declared in `daemonset.yaml`.
      verification_script: |
        #!/bin/bash
        KEY=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.tolerations[0].key}')
        EFFECT=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.tolerations[0].effect}')
        echo "$KEY" | grep -qx node-role.kubernetes.io/master || exit 1
        echo "$EFFECT" | grep -qx NoSchedule
      hint_context: |
        Use `kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.tolerations}'`.
      explanation_context: |
        DaemonSets commonly tolerate the control-plane's `NoSchedule` taint because node-local
        agents — log shippers, CNI plugins, monitoring agents — need to run on every node,
        including control-plane nodes that regular workloads are excluded from. This lab's single
        fake node carries the `node-role.kubernetes.io/agent` label and no taints at all, so the
        toleration is inert here — it exists purely to demonstrate the pattern.
      solution_script: kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.tolerations}'
    - id_key: verify-status-not-reconciled
      title: Confirm the DaemonSet controller never reconciles Pods in this lab
      points: 20
      is_optional: false
      is_stateful: false
      description: |
        This lab's `kube-controller-manager` is started with an explicit `--controllers` allowlist
        that does **not** include `daemonset` — so, unlike the Deployment lab, no controller ever
        reads `logdaemonset`'s spec and turns it into Pods. Confirm this:
        `.status.desiredNumberScheduled` and `.status.numberReady` on `logdaemonset` both remain
        `0`, and no Pod carrying the `name=fluentd-elasticsearch` selector label exists anywhere in
        the cluster — even though the single fake node would otherwise be perfectly eligible (no
        `nodeSelector`, no unsatisfied taint).
      verification_script: |
        #!/bin/bash
        DESIRED=$(kubectl get daemonset logdaemonset -o jsonpath='{.status.desiredNumberScheduled}')
        READY=$(kubectl get daemonset logdaemonset -o jsonpath='{.status.numberReady}')
        test "${DESIRED:-0}" -eq 0 || exit 1
        test "${READY:-0}" -eq 0 || exit 1
        COUNT=$(kubectl get pods -l name=fluentd-elasticsearch --no-headers 2>/dev/null | wc -l)
        test "$COUNT" -eq 0
      hint_context: |
        Compare `kubectl get daemonset logdaemonset -o yaml`'s `.status` block against
        `kubectl get pods -l name=fluentd-elasticsearch` — the object exists, but nothing is
        scheduling Pods for it.
      explanation_context: |
        A DaemonSet's `.status` fields (`desiredNumberScheduled`, `currentNumberScheduled`,
        `numberReady`, ...) are not computed by the API server — they are written by the DaemonSet
        controller inside `kube-controller-manager` as it watches nodes and reconciles one Pod per
        eligible node. This lab's control plane starts `kube-controller-manager` with a scoped
        `--controllers` list (`deployment,replicaset,namespace,endpoint,endpointslice,
        endpointslicemirroring,resourcequota,garbagecollector`) that omits `daemonset`, so
        `logdaemonset` sits in etcd as a valid, well-formed spec that nothing ever acts on — a
        useful reminder that a resource existing in the API is not the same as a controller
        reconciling it.
      solution_script: |
        kubectl get daemonset logdaemonset -o yaml
        kubectl get pods -l name=fluentd-elasticsearch
---
