---
kind: lab
id_key: k8s/workloads/lab-cronjob
course: fast-kubernetes
section: workloads
section_title: Workloads & Controllers
section_position: 2
title: 'Lab: CronJob'
position: 5
estimated_minutes: 30
source:
    - labs/cronjob/cronjob.yaml
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
    - path: cronjob.yaml
      content: "# https://crontab.guru/\r\napiVersion: batch/v1\r\nkind: CronJob\r\nmetadata:\r\n  name: hello\r\nspec:\r\n  schedule: \"*/1 * * * *\"\r\n  jobTemplate:\r\n    spec:\r\n      template:\r\n        spec:\r\n          containers:\r\n          - name: hello\r\n            image: busybox\r\n            imagePullPolicy: IfNotPresent\r\n            command:\r\n            - /bin/sh\r\n            - -c\r\n            - date; echo Hello from the Kubernetes cluster\r\n          restartPolicy: OnFailure"
tasks:
    - id_key: create-hello-cronjob
      title: Create the hello CronJob
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Apply `cronjob.yaml` (already in your workdir) to create a CronJob named **hello**
        with schedule `*/1 * * * *`, running a `busybox` container.
      verification_script: |
        #!/bin/bash
        kubectl get cronjob hello >/dev/null 2>&1 || exit 1
        SCHEDULE=$(kubectl get cronjob hello -o jsonpath='{.spec.schedule}')
        test "$SCHEDULE" = "*/1 * * * *" || exit 1
        IMAGE=$(kubectl get cronjob hello -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}')
        test "$IMAGE" = "busybox"
      hint_context: Use `kubectl apply -f cronjob.yaml`.
      explanation_context: |
        The CronJob controller creates a new Job from `.spec.jobTemplate` each time
        `.spec.schedule` fires — `*/1 * * * *` is standard cron syntax for "every minute".
        Because a Job wraps a Pod template, that template sits one level deeper here than on a
        bare Pod or Deployment: `.spec.jobTemplate.spec.template.spec`.
      solution_script: kubectl apply -f cronjob.yaml
    - id_key: verify-cronjob-container-spec
      title: Confirm the container command and restartPolicy
      points: 10
      is_optional: false
      is_stateful: false
      description: |
        Confirm that `hello`'s Job template runs the command
        `/bin/sh -c "date; echo Hello from the Kubernetes cluster"` and that the Pod template's
        `restartPolicy` is `OnFailure`, exactly as declared in `cronjob.yaml`.
      verification_script: |
        #!/bin/bash
        POLICY=$(kubectl get cronjob hello -o jsonpath='{.spec.jobTemplate.spec.template.spec.restartPolicy}')
        test "$POLICY" = "OnFailure" || exit 1
        CMD=$(kubectl get cronjob hello -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].command[2]}')
        echo "$CMD" | grep -q "Hello from the Kubernetes cluster"
      hint_context: |
        Inspect `.spec.jobTemplate.spec.template.spec` with `jsonpath` — both `restartPolicy`
        and `containers[0].command` live there.
      explanation_context: |
        A CronJob's Pod template must set `restartPolicy` to `OnFailure` or `Never` — never the
        `Always` default used by long-running controllers like Deployments, since a Job's Pod is
        expected to run to completion rather than restart forever. The container's `command`
        array here overrides `busybox`'s default entrypoint to run a one-off shell command.
      solution_script: kubectl get cronjob hello -o jsonpath='{.spec.jobTemplate.spec.template.spec}'
    - id_key: suspend-hello-cronjob
      title: Suspend the hello CronJob
      points: 15
      is_optional: false
      is_stateful: true
      description: |
        Suspend the **hello** CronJob so it stops scheduling new Jobs, without deleting it.
        Patch `.spec.suspend` to `true`.
      verification_script: |
        #!/bin/bash
        SUSPEND=$(kubectl get cronjob hello -o jsonpath='{.spec.suspend}')
        test "$SUSPEND" = "true"
      hint_context: |
        Use `kubectl patch cronjob hello -p '{"spec":{"suspend":true}}' --type merge`, or
        `kubectl edit cronjob hello`.
      explanation_context: |
        Setting `.spec.suspend: true` tells the CronJob controller to stop creating new Jobs
        from this schedule while leaving the CronJob object, and any Jobs it already created,
        untouched — the standard way to pause a CronJob temporarily (e.g. during an incident)
        without losing its configuration.
      solution_script: kubectl patch cronjob hello -p '{"spec":{"suspend":true}}' --type merge
    - id_key: configure-cronjob-policy
      title: Configure concurrencyPolicy and job history limits
      points: 20
      is_optional: false
      is_stateful: true
      description: |
        Patch the **hello** CronJob to set `.spec.concurrencyPolicy` to `Forbid` (skip a run
        if the previous Job hasn't finished), `.spec.successfulJobsHistoryLimit` to `2`, and
        `.spec.failedJobsHistoryLimit` to `1`.
      verification_script: |
        #!/bin/bash
        CP=$(kubectl get cronjob hello -o jsonpath='{.spec.concurrencyPolicy}')
        test "$CP" = "Forbid" || exit 1
        SJHL=$(kubectl get cronjob hello -o jsonpath='{.spec.successfulJobsHistoryLimit}')
        test "$SJHL" = "2" || exit 1
        FJHL=$(kubectl get cronjob hello -o jsonpath='{.spec.failedJobsHistoryLimit}')
        test "$FJHL" = "1"
      hint_context: |
        `kubectl patch cronjob hello -p
        '{"spec":{"concurrencyPolicy":"Forbid","successfulJobsHistoryLimit":2,"failedJobsHistoryLimit":1}}'
        --type merge`
      explanation_context: |
        `concurrencyPolicy: Forbid` skips a new run if the previous Job is still active — the
        alternatives are `Allow` (the default, runs overlap freely) and `Replace` (cancels the
        running Job and starts the new one). `successfulJobsHistoryLimit` and
        `failedJobsHistoryLimit` cap how many completed Job objects the controller retains for
        inspection before garbage-collecting the oldest ones.
      solution_script: |
        kubectl patch cronjob hello -p '{"spec":{"concurrencyPolicy":"Forbid","successfulJobsHistoryLimit":2,"failedJobsHistoryLimit":1}}' --type merge
---
