---
kind: lab
id_key: k8s/scheduling/lab-tainttoleration
course: fast-kubernetes
section: scheduling
section_title: Health & Scheduling
section_position: 6
title: 'Lab: Taint & Toleration'
position: 3
estimated_minutes: 30
source:
    - labs/tainttoleration/podtoleration.yaml
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
    - path: podtoleration.yaml
      content: "apiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: toleratedpod1\r\n  labels:\r\n    env: test\r\nspec:\r\n  containers:\r\n  - name: toleratedcontainer1\r\n    image: nginx:latest\r\n  tolerations:\r\n  - key: \"platform\"\r\n    operator: \"Equal\"\r\n    value: \"production\"\r\n    effect: \"NoSchedule\"\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: toleratedpod2\r\n  labels:\r\n    env: test\r\nspec:\r\n  containers:\r\n  - name: toleratedcontainer2\r\n    image: nginx\r\n  tolerations:\r\n  - key: \"platform\"\r\n    operator: \"Exists\"\r\n    effect: \"NoSchedule\""
tasks:
    - id_key: taint-node
      title: Taint the cluster node
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Find the name of the cluster's (single) node and apply a taint
        `platform=production:NoSchedule` to it using `kubectl taint`.
      verification_script: |
        #!/bin/bash
        NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
        test -n "$NODE" || exit 1
        kubectl get node "$NODE" -o jsonpath='{.spec.taints[?(@.key=="platform")].value}' | grep -qx production || exit 1
        kubectl get node "$NODE" -o jsonpath='{.spec.taints[?(@.key=="platform")].effect}' | grep -qx NoSchedule
      hint_context: |
        Get the node name with `kubectl get nodes -o jsonpath='{.items[0].metadata.name}'`, then
        run `kubectl taint nodes <node> platform=production:NoSchedule`.
      explanation_context: |
        A taint is applied to a Node and repels Pods unless they carry a matching toleration.
        The `key=value:effect` syntax here creates taint `platform=production` with effect
        `NoSchedule`, meaning the scheduler will not place new Pods on this node unless they
        tolerate it.
      solution_script: |
        NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
        kubectl taint nodes "$NODE" platform=production:NoSchedule
    - id_key: verify-intolerant-pod-blocked
      title: Confirm an untolerated Pod cannot schedule on the tainted node
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Create a Pod named **notoleratedpod** (image `nginx`) with no tolerations, e.g.
        `kubectl run notoleratedpod --image=nginx`. Because the node is tainted with
        `platform=production:NoSchedule` and this Pod declares no matching toleration, it
        should remain unscheduled.
      verification_script: |
        #!/bin/bash
        kubectl get pod notoleratedpod >/dev/null 2>&1 || exit 1
        NODENAME=$(kubectl get pod notoleratedpod -o jsonpath='{.spec.nodeName}' 2>/dev/null)
        test -z "$NODENAME" || exit 1
        kubectl get pod notoleratedpod -o jsonpath='{.status.phase}' | grep -qx Pending
      hint_context: |
        Use `kubectl run notoleratedpod --image=nginx`, then check that
        `kubectl get pod notoleratedpod -o jsonpath='{.spec.nodeName}'` is empty and
        `.status.phase` is `Pending`.
      explanation_context: |
        With only one Node in the cluster and that Node tainted `NoSchedule`, the scheduler has
        no eligible Node for a Pod lacking a toleration — it leaves the Pod `Pending` with
        `nodeName` unset rather than binding it anywhere. This is the taint doing its job.
      solution_script: kubectl run notoleratedpod --image=nginx
    - id_key: create-toleratedpods
      title: Create the tolerated Pods
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `podtoleration.yaml` (already in your workdir) to create two Pods —
        **toleratedpod1** and **toleratedpod2** — each carrying a toleration for the
        `platform=production:NoSchedule` taint.
      verification_script: |
        #!/bin/bash
        kubectl get pod toleratedpod1 >/dev/null 2>&1 || exit 1
        kubectl get pod toleratedpod2 >/dev/null 2>&1 || exit 1
      hint_context: Use `kubectl apply -f podtoleration.yaml`.
      explanation_context: |
        `podtoleration.yaml` declares two Pods sharing the `env=test` label, each with a
        `tolerations` entry under `.spec` — this is the only extra field a Pod needs to become
        eligible for scheduling onto a tainted Node.
      solution_script: kubectl apply -f podtoleration.yaml
    - id_key: verify-toleratedpod1-toleration
      title: Confirm toleratedpod1's toleration exactly matches the taint
      points: 10
      is_optional: false
      is_stateful: false
      description: |
        Confirm that **toleratedpod1**'s toleration uses `operator: Equal` with `key: platform`,
        `value: production`, and `effect: NoSchedule` — an exact match for the taint on the node.
      verification_script: |
        #!/bin/bash
        kubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations[0].key}' | grep -qx platform || exit 1
        kubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations[0].operator}' | grep -qx Equal || exit 1
        kubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations[0].value}' | grep -qx production || exit 1
        kubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations[0].effect}' | grep -qx NoSchedule
      hint_context: Inspect `kubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations}'`.
      explanation_context: |
        The `Equal` operator requires `key`, `value`, and `effect` to match the taint exactly.
        toleratedpod1's toleration is written to match `platform=production:NoSchedule` field
        for field — a looser toleration (missing `value`, or a different `effect`) would not
        tolerate this specific taint.
      solution_script: kubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations}'
    - id_key: verify-toleratedpod2-toleration
      title: Confirm toleratedpod2's toleration uses the Exists operator
      points: 10
      is_optional: false
      is_stateful: false
      description: |
        Confirm that **toleratedpod2**'s toleration uses `operator: Exists` with `key: platform`
        and `effect: NoSchedule` — tolerating any taint value on that key, not just `production`.
      verification_script: |
        #!/bin/bash
        kubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations[0].key}' | grep -qx platform || exit 1
        kubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations[0].operator}' | grep -qx Exists || exit 1
        kubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations[0].effect}' | grep -qx NoSchedule || exit 1
        VALUE=$(kubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations[0].value}' 2>/dev/null)
        test -z "$VALUE"
      hint_context: Inspect `kubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations}'`.
      explanation_context: |
        The `Exists` operator only checks that the `key` (and, if set, `effect`) is present on
        the taint — it ignores `value` entirely, which is why `podtoleration.yaml` omits `value`
        for toleratedpod2. This toleration matches `platform=<anything>:NoSchedule`.
      solution_script: kubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations}'
    - id_key: verify-toleratedpods-scheduled
      title: Confirm both tolerated Pods scheduled successfully despite the taint
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that **toleratedpod1** and **toleratedpod2** were both bound to the tainted node
        (`.spec.nodeName` set) and reached phase `Running`, proving their tolerations let the
        scheduler place them despite the `platform=production:NoSchedule` taint.
      verification_script: |
        #!/bin/bash
        for POD in toleratedpod1 toleratedpod2; do
          NODENAME=$(kubectl get pod "$POD" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
          test -n "$NODENAME" || exit 1
          kubectl get pod "$POD" -o jsonpath='{.status.phase}' | grep -qx Running || exit 1
        done
      hint_context: |
        Check `kubectl get pod toleratedpod1 toleratedpod2 -o wide` for the `NODE` and `STATUS`
        columns.
      explanation_context: |
        A toleration doesn't attract a Pod to a tainted Node — it only removes the repulsion,
        letting the scheduler consider that Node like any other. Here it's the only Node
        available, so both tolerated Pods land on it and reach `Running`, in contrast to
        notoleratedpod's `Pending` state.
      solution_script: kubectl get pod toleratedpod1 toleratedpod2 -o wide
---
