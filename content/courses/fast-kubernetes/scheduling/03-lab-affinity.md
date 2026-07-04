---
kind: lab
id_key: k8s/scheduling/lab-affinity
course: fast-kubernetes
section: scheduling
section_title: Health & Scheduling
section_position: 6
title: 'Lab: Node Affinity'
position: 2
estimated_minutes: 30
source:
    - labs/affinity/podnodeaffinity.yaml
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
    - path: podnodeaffinity.yaml
      content: "apiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: nodeaffinitypod1\r\nspec:\r\n  containers:\r\n  - name: nodeaffinity1\r\n    image: nginx:latest\r\n  affinity:\r\n    nodeAffinity:\r\n      requiredDuringSchedulingIgnoredDuringExecution:\r\n        nodeSelectorTerms:\r\n        - matchExpressions:\r\n          - key: app\r\n            operator: In #In, NotIn, Exists, DoesNotExist\r\n            values:\r\n            - production\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: nodeaffinitypod2\r\nspec:\r\n  containers:\r\n  - name: nodeaffinity2\r\n    image: nginx:latest\r\n  affinity:\r\n    nodeAffinity:\r\n      preferredDuringSchedulingIgnoredDuringExecution:\r\n      - weight: 1\r\n        preference:\r\n          matchExpressions:\r\n          - key: app\r\n            operator: In\r\n            values:\r\n            - production\r\n      - weight: 2\r\n        preference:\r\n          matchExpressions:\r\n          - key: app\r\n            operator: In\r\n            values:\r\n            - test\r\n---\r\napiVersion: v1\r\nkind: Pod\r\nmetadata:\r\n  name: nodeaffinitypod3\r\nspec:\r\n  containers:\r\n  - name: nodeaffinity3\r\n    image: nginx:latest\r\n  affinity:\r\n    nodeAffinity:\r\n      requiredDuringSchedulingIgnoredDuringExecution:\r\n        nodeSelectorTerms:\r\n        - matchExpressions:\r\n          - key: app\r\n            operator: Exists #In, NotIn, Exists, DoesNotExist"
tasks:
    - id_key: create-nodeaffinity-pods
      title: Create the three node affinity Pods
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `podnodeaffinity.yaml` (already in your workdir) to create three Pods —
        **nodeaffinitypod1**, **nodeaffinitypod2**, and **nodeaffinitypod3** — each declaring a
        different `nodeAffinity` rule shape.
      verification_script: |
        #!/bin/bash
        kubectl get pod nodeaffinitypod1 >/dev/null 2>&1 || exit 1
        kubectl get pod nodeaffinitypod2 >/dev/null 2>&1 || exit 1
        kubectl get pod nodeaffinitypod3 >/dev/null 2>&1 || exit 1
      hint_context: Use `kubectl apply -f podnodeaffinity.yaml`.
      explanation_context: |
        The manifest bundles three Pod definitions separated by `---`; `kubectl apply -f`
        creates all three with a single command. Each Pod exercises a different nodeAffinity
        rule: a hard `required` rule with `In`, a soft `preferred` rule with two weighted terms,
        and a hard `required` rule with `Exists`.
      solution_script: kubectl apply -f podnodeaffinity.yaml
    - id_key: verify-pod1-required-affinity
      title: Confirm nodeaffinitypod1's required affinity rule
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that **nodeaffinitypod1** declares a `required` nodeAffinity rule under
        `.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution` matching
        key `app`, operator `In`, values `[production]`.
      verification_script: |
        #!/bin/bash
        BASE='{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0]'
        KEY=$(kubectl get pod nodeaffinitypod1 -o jsonpath="${BASE}.key}")
        OP=$(kubectl get pod nodeaffinitypod1 -o jsonpath="${BASE}.operator}")
        VAL=$(kubectl get pod nodeaffinitypod1 -o jsonpath="${BASE}.values[0]}")
        echo "$KEY" | grep -qx app || exit 1
        echo "$OP" | grep -qx In || exit 1
        echo "$VAL" | grep -qx production
      hint_context: |
        Inspect `.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution` with
        `kubectl get pod nodeaffinitypod1 -o yaml`.
      explanation_context: |
        `requiredDuringSchedulingIgnoredDuringExecution` is a hard constraint — the scheduler
        will not bind this Pod to any node whose labels don't satisfy every `matchExpressions`
        entry inside at least one `nodeSelectorTerms` block. "IgnoredDuringExecution" means a
        Pod already running is not evicted later if the node's labels change.
      solution_script: |
        kubectl get pod nodeaffinitypod1 -o jsonpath='{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution}'
    - id_key: verify-pod2-preferred-affinity
      title: Confirm nodeaffinitypod2's preferred affinity terms
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that **nodeaffinitypod2** declares two `preferred` nodeAffinity terms under
        `.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution` — weight
        `1` preferring `app In [production]`, and weight `2` preferring `app In [test]`.
      verification_script: |
        #!/bin/bash
        BASE='{.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution'
        W0=$(kubectl get pod nodeaffinitypod2 -o jsonpath="${BASE}[0].weight}")
        V0=$(kubectl get pod nodeaffinitypod2 -o jsonpath="${BASE}[0].preference.matchExpressions[0].values[0]}")
        W1=$(kubectl get pod nodeaffinitypod2 -o jsonpath="${BASE}[1].weight}")
        V1=$(kubectl get pod nodeaffinitypod2 -o jsonpath="${BASE}[1].preference.matchExpressions[0].values[0]}")
        echo "$W0" | grep -qx 1 || exit 1
        echo "$V0" | grep -qx production || exit 1
        echo "$W1" | grep -qx 2 || exit 1
        echo "$V1" | grep -qx test
      hint_context: |
        Use `kubectl get pod nodeaffinitypod2 -o jsonpath='{.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution}'`.
      explanation_context: |
        `preferredDuringSchedulingIgnoredDuringExecution` is a soft constraint — the scheduler
        scores nodes that satisfy each term by its `weight` and favors higher-scoring nodes, but
        will still schedule the Pod on a node that satisfies neither term if nothing else fits.
        Since this Pod has no `required` rule, it is never blocked by the absence of an `app`
        label anywhere in the cluster.
      solution_script: |
        kubectl get pod nodeaffinitypod2 -o jsonpath='{.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution}'
    - id_key: verify-pod3-exists-operator
      title: Confirm nodeaffinitypod3's Exists operator rule
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that **nodeaffinitypod3** declares a `required` nodeAffinity rule using operator
        `Exists` on key `app` — `Exists` takes no `values` list; it only checks that the label
        key is present on the node, regardless of its value.
      verification_script: |
        #!/bin/bash
        BASE='{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0]'
        KEY=$(kubectl get pod nodeaffinitypod3 -o jsonpath="${BASE}.key}")
        OP=$(kubectl get pod nodeaffinitypod3 -o jsonpath="${BASE}.operator}")
        echo "$KEY" | grep -qx app || exit 1
        echo "$OP" | grep -qx Exists
      hint_context: |
        Use `kubectl get pod nodeaffinitypod3 -o jsonpath='{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0]}'`.
      explanation_context: |
        `Exists` (like `DoesNotExist`) is a key-only operator — it never takes a `values` list.
        It matches any node carrying the label key `app` regardless of what it's set to, unlike
        `In`/`NotIn`, which also compare the value.
      solution_script: |
        kubectl get pod nodeaffinitypod3 -o jsonpath='{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution}'
    - id_key: verify-scheduling-outcome
      title: Confirm the actual scheduling outcome on the fake node
      points: 20
      is_optional: false
      is_stateful: false
      description: |
        This lab's cluster has a single fake (kwok) node whose labels are only
        `kubernetes.io/*`, `beta.kubernetes.io/*`, `node-role.kubernetes.io/agent`, and
        `type=kwok` — it carries **no `app` label at all**. Confirm the scheduling outcome this
        produces: **nodeaffinitypod2** (soft preference only) reaches `Running`, while
        **nodeaffinitypod1** and **nodeaffinitypod3** (hard `required` rules keyed on the
        missing `app` label) remain `Pending` because no node in the cluster satisfies their
        `nodeSelectorTerms`.
      verification_script: |
        #!/bin/bash
        PHASE2=$(kubectl get pod nodeaffinitypod2 -o jsonpath='{.status.phase}')
        echo "$PHASE2" | grep -qx Running || exit 1
        PHASE1=$(kubectl get pod nodeaffinitypod1 -o jsonpath='{.status.phase}')
        echo "$PHASE1" | grep -qx Pending || exit 1
        PHASE3=$(kubectl get pod nodeaffinitypod3 -o jsonpath='{.status.phase}')
        echo "$PHASE3" | grep -qx Pending
      hint_context: |
        Compare `kubectl get pods -o wide` for all three Pods against the node's real labels via
        `kubectl get nodes --show-labels` — none of them start with `app`.
      explanation_context: |
        A `required` nodeAffinity rule is enforced at scheduling time: if no node's labels
        satisfy it, the scheduler leaves the Pod unbound (`Pending`) indefinitely rather than
        falling back to a mismatched node. Both `nodeaffinitypod1` (`In [production]`) and
        `nodeaffinitypod3` (`Exists`) key on `app`, a label the single fake node never carries,
        so neither can ever be scheduled here. `nodeaffinitypod2` has no `required` rule — only
        two `preferred` terms — so the scheduler simply ranks the one available node (which
        matches neither preference, scoring 0) and schedules the Pod anyway, reaching `Running`.
      solution_script: |
        kubectl get pods -o wide
        kubectl get nodes --show-labels
---
