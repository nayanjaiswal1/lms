---
kind: lab
id_key: k8s/workloads/lab-cronjob
course: fast-kubernetes
section: workloads
section_title: Deployments & Workload Controllers
section_position: 3
title: 'Lab: CronJob'
position: 6
estimated_minutes: 15
source:
  - labs/cronjob/cronjob.yaml
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
  - path: cronjob.yaml
    content: |
      apiVersion: batch/v1
      kind: CronJob
      metadata:
        name: hello
      spec:
        schedule: "*/1 * * * *"
        jobTemplate:
          spec:
            template:
              spec:
                containers:
                - name: hello
                  image: busybox:1.36
                  imagePullPolicy: IfNotPresent
                  command:
                  - /bin/sh
                  - -c
                  - date; echo Hello from the Kubernetes cluster
                restartPolicy: OnFailure
tasks:
  - id_key: create-cronjob
    title: Create a CronJob
    points: 10
    is_stateful: true
    description: Apply `cronjob.yaml`, then run `kubectl get cronjobs` and `kubectl get jobs -w`. Within about a minute a Job named `hello-<number>` appears.
    verification_script: |
      #!/bin/bash
      test "$(kubectl get cronjob hello -o jsonpath='{.spec.schedule}')" = "*/1 * * * *" || exit 1
      kubectl get jobs -o jsonpath='{range .items[*]}{.metadata.ownerReferences[0].name}{"\n"}{end}' | grep -qx hello
    hint_context: Apply the file, then wait up to one minute for the first scheduled run.
    explanation_context: At each scheduled time the CronJob controller creates a normal Job from jobTemplate. The number in the Job name encodes the scheduled time.
    solution_script: |
      kubectl apply -f cronjob.yaml
      for i in $(seq 1 75); do kubectl get jobs --no-headers 2>/dev/null | grep -q '^hello-' && break; sleep 1; done
  - id_key: manual-run
    title: Trigger a run now
    points: 10
    is_stateful: false
    description: Do not wait for the schedule. Create a Job named `manual` from the CronJob `hello`.
    verification_script: |
      #!/bin/bash
      kubectl get job manual -o jsonpath='{.metadata.annotations.cronjob\.kubernetes\.io/instantiate}' | grep -qx manual
    hint_context: "`kubectl create job <name> --from=cronjob/<cronjob-name>`"
    explanation_context: "`--from=cronjob/hello` copies the CronJob's jobTemplate into a new Job. It is handy for testing a schedule without waiting."
    solution_script: kubectl create job manual --from=cronjob/hello
  - id_key: suspend-cronjob
    title: Pause the schedule
    points: 10
    is_stateful: false
    description: Suspend the CronJob `hello` so it stops creating new Jobs.
    verification_script: |
      #!/bin/bash
      kubectl get cronjob hello -o jsonpath='{.spec.suspend}' | grep -qx true
    hint_context: "Set `spec.suspend` to true, for example: `kubectl patch cronjob hello -p '{\"spec\":{\"suspend\":true}}'`"
    explanation_context: A suspended CronJob keeps its definition but creates no new Jobs until suspend is set back to false.
    solution_script: |
      kubectl patch cronjob hello -p '{"spec":{"suspend":true}}'
  - id_key: write-backup-cronjob
    title: Write a nightly backup CronJob
    points: 20
    is_stateful: false
    description: |
      Write and apply a CronJob named `backup` that:
      - runs every day at **02:30**
      - never runs two copies at the same time
      - uses image `busybox:1.36` with command `["sh", "-c", "echo backing up"]` and restartPolicy `OnFailure`
    verification_script: |
      #!/bin/bash
      test "$(kubectl get cronjob backup -o jsonpath='{.spec.schedule}|{.spec.concurrencyPolicy}|{.spec.jobTemplate.spec.template.spec.containers[0].image}')" = "30 2 * * *|Forbid|busybox:1.36"
    hint_context: Cron fields are minute, hour, day of month, month, day of week. The field that prevents overlapping runs is `concurrencyPolicy`.
    explanation_context: "`30 2 * * *` means minute 30 of hour 2, every day. `concurrencyPolicy: Forbid` skips a run while the previous Job is still active."
    solution_script: |
      cat > backup.yaml <<'Y'
      apiVersion: batch/v1
      kind: CronJob
      metadata:
        name: backup
      spec:
        schedule: "30 2 * * *"
        concurrencyPolicy: Forbid
        jobTemplate:
          spec:
            template:
              spec:
                restartPolicy: OnFailure
                containers:
                - name: backup
                  image: busybox:1.36
                  command: ["sh", "-c", "echo backing up"]
      Y
      kubectl apply -f backup.yaml
---
