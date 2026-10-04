---
kind: lab
id_key: k8s/workloads/lab-job
course: fast-kubernetes
section: workloads
section_title: Deployments & Workload Controllers
section_position: 3
title: 'Lab: Job'
position: 5
estimated_minutes: 15
source:
  - labs/job/job.yaml
lab_type: terminal
environment: mindforge/lab-k8s:1.31
max_duration: 30
max_resets: 3
hint_penalty_pct: 10
is_required: true
setup_script: |
  #!/bin/bash
  set -euo pipefail
  kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
files:
  - path: job.yaml
    content: |
      apiVersion: batch/v1
      kind: Job
      metadata:
        name: pi
      spec:
        parallelism: 2
        completions: 10
        backoffLimit: 5
        activeDeadlineSeconds: 100
        template:
          spec:
            containers:
            - name: pi
              image: perl:5.40
              command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
            restartPolicy: Never
tasks:
  - id_key: run-job
    title: Run a Job to completion
    points: 15
    is_stateful: true
    description: Apply `job.yaml`, then watch it with `kubectl get jobs -w` (Ctrl+C to stop) and `kubectl get pods`. Wait until COMPLETIONS shows `10/10`.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get job pi -o jsonpath='{.status.succeeded}')" = "10"
    hint_context: "`kubectl apply -f job.yaml`"
    explanation_context: The Job ran at most 2 pods at a time (parallelism) until 10 had succeeded (completions). Finished pods stay in Completed state so you can read their logs.
    solution_script: kubectl apply -f job.yaml
  - id_key: create-job-imperative
    title: Create a Job with one command
    points: 10
    is_stateful: false
    description: Create a Job called `hello` from `busybox:1.36` that runs `echo hello`, using `kubectl create job`. Check that it completes.
    verification_script: |
      #!/bin/bash
      kubectl get job hello -o jsonpath='{.spec.template.spec.containers[0].image} {.status.succeeded}' | grep -qx 'busybox:1.36 1'
    hint_context: "`kubectl create job <name> --image=<image> -- <command>`. Everything after `--` is the command."
    explanation_context: "`kubectl create job hello --image=busybox:1.36 -- echo hello` builds a Job that needs one successful run and uses restartPolicy Never."
    solution_script: kubectl create job hello --image=busybox:1.36 -- echo hello
  - id_key: job-ttl
    title: Clean up finished Jobs automatically
    points: 15
    is_stateful: false
    description: |
      Write `cleanup-job.yaml` for a Job named `cleanup` (image `busybox:1.36`, command `["sh", "-c", "echo done"]`, restartPolicy `Never`) that deletes itself **300 seconds** after it finishes. Apply it.
    verification_script: |
      #!/bin/bash
      kubectl get job cleanup -o jsonpath='{.spec.ttlSecondsAfterFinished}' 2>/dev/null | grep -qx 300
    hint_context: The field is `ttlSecondsAfterFinished`, directly under the Job's `spec`.
    explanation_context: The TTL controller deletes the Job and its pods once the TTL has passed after completion, so finished Jobs do not pile up.
    solution_script: |
      cat > cleanup-job.yaml <<'Y'
      apiVersion: batch/v1
      kind: Job
      metadata:
        name: cleanup
      spec:
        ttlSecondsAfterFinished: 300
        template:
          spec:
            restartPolicy: Never
            containers:
            - name: cleanup
              image: busybox:1.36
              command: ["sh", "-c", "echo done"]
      Y
      kubectl apply -f cleanup-job.yaml
---
