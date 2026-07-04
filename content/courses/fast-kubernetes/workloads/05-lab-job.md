---
kind: lab
id_key: k8s/workloads/lab-job
course: fast-kubernetes
section: workloads
section_title: Workloads & Controllers
section_position: 2
title: 'Lab: Job'
position: 4
estimated_minutes: 30
source:
    - labs/job/job.yaml
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
    - path: job.yaml
      content: "apiVersion: batch/v1\r\nkind: Job\r\nmetadata:\r\n  name: pi\r\nspec:\r\n  parallelism: 2\r\n  completions: 10\r\n  backoffLimit: 5\r\n  activeDeadlineSeconds: 100\r\n  template:\r\n    spec:\r\n      containers:\r\n      - name: pi\r\n        image: perl\r\n        command: [\"perl\",  \"-Mbignum=bpi\", \"-wle\", \"print bpi(2000)\"]\r\n      restartPolicy: Never #OnFailure "
tasks:
    - id_key: create-pi-job
      title: Create the pi Job
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `job.yaml` (already in your workdir) to create a Job named **pi** with
        **2** parallel workers (`parallelism: 2`) that must reach **10** successful
        completions (`completions: 10`).
      verification_script: |
        #!/bin/bash
        kubectl get job pi >/dev/null 2>&1 || exit 1
        COMPLETIONS=$(kubectl get job pi -o jsonpath='{.spec.completions}' 2>/dev/null)
        PARALLELISM=$(kubectl get job pi -o jsonpath='{.spec.parallelism}' 2>/dev/null)
        test "$COMPLETIONS" = "10" || exit 1
        test "$PARALLELISM" = "2"
      hint_context: Use `kubectl apply -f job.yaml`.
      explanation_context: |
        `kubectl apply` creates the Job object with `.spec.completions` and
        `.spec.parallelism` set from the manifest. Unlike a Deployment, a Job's controller
        drives Pods to successful completion rather than keeping them running forever.
      solution_script: kubectl apply -f job.yaml
    - id_key: verify-job-backoff-deadline
      title: Confirm the Job's retry and deadline limits
      points: 10
      is_optional: false
      is_stateful: false
      description: |
        Confirm that the **pi** Job has `backoffLimit: 5` and
        `activeDeadlineSeconds: 100`, as declared in `job.yaml`.
      verification_script: |
        #!/bin/bash
        BACKOFF=$(kubectl get job pi -o jsonpath='{.spec.backoffLimit}' 2>/dev/null)
        DEADLINE=$(kubectl get job pi -o jsonpath='{.spec.activeDeadlineSeconds}' 2>/dev/null)
        test "$BACKOFF" = "5" || exit 1
        test "$DEADLINE" = "100"
      hint_context: |
        Inspect the Job spec with `kubectl get job pi -o yaml` or query
        `.spec.backoffLimit` and `.spec.activeDeadlineSeconds` directly with `jsonpath`.
      explanation_context: |
        `backoffLimit` caps how many times the Job controller retries a failed Pod before
        marking the Job itself as failed. `activeDeadlineSeconds` is a hard wall-clock
        ceiling on the whole Job — once exceeded, the Job is terminated regardless of
        `backoffLimit`, which protects against a retry loop that never gives up on its own.
      solution_script: kubectl get job pi -o jsonpath='{.spec.backoffLimit} {.spec.activeDeadlineSeconds}'
    - id_key: verify-pi-container-spec
      title: Confirm the pi container's image, command, and restart policy
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Confirm that the **pi** Job's Pod template runs container `pi` on image `perl`,
        with a command that computes `bpi(2000)`, and `restartPolicy: Never`.
      verification_script: |
        #!/bin/bash
        IMAGE=$(kubectl get job pi -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
        test "$IMAGE" = "perl" || exit 1
        RESTART=$(kubectl get job pi -o jsonpath='{.spec.template.spec.restartPolicy}' 2>/dev/null)
        test "$RESTART" = "Never" || exit 1
        CMD=$(kubectl get job pi -o jsonpath='{.spec.template.spec.containers[0].command}' 2>/dev/null)
        echo "$CMD" | grep -q 'bpi(2000)'
      hint_context: |
        Inspect `.spec.template.spec.containers[0]` for `image` and `command`, and
        `.spec.template.spec.restartPolicy` for the restart policy.
      explanation_context: |
        A Job's Pod template only accepts `restartPolicy: Never` or `OnFailure` — never
        `Always` — because a Pod that's supposed to run to completion and stop can't use
        the same "restart forever" policy a long-running Deployment Pod does. `pi`'s
        container runs a one-shot Perl computation of pi to 2000 digits, then exits.
      solution_script: kubectl get job pi -o jsonpath='{.spec.template.spec.containers[0]}{.spec.template.spec.restartPolicy}'
    - id_key: verify-job-status-tracking
      title: Inspect the Job's completion-tracking status fields
      points: 15
      is_optional: false
      is_stateful: false
      description: |
        Kubernetes tracks a Job's progress toward its **10** required completions through
        `.status.active` and `.status.succeeded` as the Job controller creates and reaps
        Pods. Inspect **pi**'s status block with `kubectl get job pi -o yaml` (or
        `-o jsonpath`) and confirm the Job is configured to reach that target.
      verification_script: |
        #!/bin/bash
        kubectl get job pi >/dev/null 2>&1 || exit 1
        SUCCEEDED=$(kubectl get job pi -o jsonpath='{.status.succeeded}' 2>/dev/null)
        ACTIVE=$(kubectl get job pi -o jsonpath='{.status.active}' 2>/dev/null)
        COMPLETIONS=$(kubectl get job pi -o jsonpath='{.spec.completions}' 2>/dev/null)
        if [ -n "$SUCCEEDED" ] && [ "$SUCCEEDED" -ge 1 ] 2>/dev/null; then exit 0; fi
        if [ -n "$ACTIVE" ] && [ "$ACTIVE" -ge 1 ] 2>/dev/null; then exit 0; fi
        test "${COMPLETIONS:-0}" = "10"
      hint_context: |
        Check `.status.succeeded` and `.status.active` first. If neither has populated in
        this environment, falling back to confirming `.spec.completions` still proves the
        Job object is correctly configured to run to 10 successful completions.
      explanation_context: |
        In a full cluster, the Job controller watches `.status.active`, `.status.succeeded`,
        and `.status.failed`, creating Pods up to `parallelism` until `completions`
        successes are reached. This lab's control plane does not enable the `job` controller
        (see `kube-controller-manager`'s `--controllers=` flag), so `pi` never gets Pods
        scheduled for it and its status subresource stays empty here — the same declarative
        spec you already verified (`completions: 10`) is exactly what a real cluster's Job
        controller would drive toward.
      solution_script: kubectl get job pi -o jsonpath='{.status}'
---
