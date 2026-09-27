---
kind: lesson
id_key: k8s/workloads/lesson-controllers
course: fast-kubernetes
section: workloads
section_title: Deployments & Workload Controllers
section_position: 3
title: DaemonSets, StatefulSets, Jobs and CronJobs
position: 2
estimated_minutes: 50
source:
  - K8s-Daemon-Sets.md
  - K8s-Statefulset.md
  - K8s-Job.md
  - K8s-CronJob.md
---

A Deployment is right for stateless apps where every copy is the same and can run anywhere. Some workloads need different rules:

| You need... | Use |
|---|---|
| N identical, interchangeable copies (web app, API) | **Deployment** |
| One copy on **every node** (log collector, monitoring agent) | **DaemonSet** |
| Copies with a **stable name and their own disk** (database, Kafka, ZooKeeper) | **StatefulSet** |
| Run a task **to completion** once (batch job, migration) | **Job** |
| Run a task **on a schedule** (nightly backup, hourly report) | **CronJob** |

All of them use the same pod template you already know. Only the controller's behavior changes.

## DaemonSet: one pod per node

Like a housing society that posts exactly one security guard at every gate, not three guards at one gate and none at the others, a **DaemonSet** runs exactly one copy of a pod on every node (or every node that matches a selector). When a node joins the cluster, the DaemonSet adds a pod there automatically. When a node is removed, that pod goes too. There is no `replicas` field: the number of nodes decides the count.

Typical uses are node-level agents: log collectors (Fluentd, Fluent Bit), metrics exporters (node-exporter), network plugins (Calico, Cilium) and storage drivers.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: logdaemonset
  labels:
    app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:                          # also run on control-plane nodes, which are tainted
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
      volumes:
      - name: varlog
        hostPath:                           # a folder on the node itself
          path: /var/log
```

Two things to notice:

- **`hostPath`** mounts a directory from the node's own disk. A log collector needs it to read the logs of every other pod on that node. hostPath is powerful and risky, so only use it for node agents like this one.
- The **toleration** lets the pod run on control-plane nodes, which normally refuse regular pods (taints and tolerations are explained in the scheduling section). Older clusters used the key `node-role.kubernetes.io/master`.

```bash
kubectl apply -f daemonset.yaml
kubectl get daemonset          # DESIRED = number of eligible nodes
kubectl get pods -o wide       # one pod per node
```

Delete one of its pods and the DaemonSet creates a replacement on the same node.

```knowledge-check
{ "questions": [
  { "id": "k8s-ctrl-ds-q1", "type": "mcq",
    "prompt": "A cluster has 4 nodes and a DaemonSet with no node selector. A 5th node joins. What happens?",
    "options": [
      {"id": "a", "text": "Nothing until you raise replicas to 5"},
      {"id": "b", "text": "The DaemonSet automatically starts one pod on the new node"},
      {"id": "c", "text": "One pod moves from an old node to the new one"},
      {"id": "d", "text": "All 4 pods restart"}
    ],
    "correct": "b",
    "explanation": "A DaemonSet has no replicas field. It keeps one pod on every eligible node, including nodes that join later." },
  { "id": "k8s-ctrl-ds-q2", "type": "mcq",
    "prompt": "Which workload is the best fit for a log collector that must read log files from every node?",
    "options": [
      {"id": "a", "text": "Deployment with 3 replicas"},
      {"id": "b", "text": "DaemonSet"},
      {"id": "c", "text": "Job"},
      {"id": "d", "text": "StatefulSet"}
    ],
    "correct": "b",
    "explanation": "A node agent must run once per node, which is exactly what a DaemonSet guarantees." }
] }
```

## StatefulSet: stable names and their own storage

Think of numbered lockers at a gym: locker 7 is always locker 7, and whoever is assigned to it keeps using the same locker with the same contents inside, even if it is a different day. Pods of a Deployment are interchangeable: random names, shared storage (if any), started in any order. A database cluster cannot work that way. Each member needs to be known by name and keep **its own** data. A **StatefulSet** gives each pod:

- **A stable, ordered name**: `web-0`, `web-1`, `web-2`. If `web-1` is deleted, the new pod is again called `web-1`.
- **A stable network name** through a **headless Service**: `web-0.nginx.default.svc.cluster.local`.
- **Its own PersistentVolumeClaim** from `volumeClaimTemplates`. `web-0` always gets back the same disk (`www-web-0`), even when rescheduled to another node.
- **Ordered start and stop**: `web-0` must be ready before `web-1` starts. Scaling down removes the highest number first.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  clusterIP: None            # "headless": no virtual IP, DNS returns the pod IPs directly
  selector:
    app: nginx
  ports:
  - port: 80
    name: web
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: nginx         # the headless Service that gives pods their DNS names
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:      # one PVC per pod: www-web-0, www-web-1, www-web-2
  - metadata:
      name: www
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 512Mi
```

What to remember:

- **Deleting or scaling down a StatefulSet does not delete its PVCs.** Your data is safe by default. Delete the PVCs yourself when you really want the data gone.
- A **headless Service** (`clusterIP: None`) has no load-balanced IP. A DNS lookup of `nginx` returns all pod IPs, and `web-0.nginx` returns exactly that pod's IP. Clients that must talk to one specific member (for example, "write to the primary") use these names.
- A StatefulSet gives you identity and storage. It does **not** set up replication between members. The database itself (or an operator) must do that. For production databases, a managed service or an operator (for example CloudNativePG for PostgreSQL) is usually a better choice than writing one yourself.

```knowledge-check
{ "questions": [
  { "id": "k8s-ctrl-sts-q1", "type": "mcq",
    "prompt": "StatefulSet `db` has 3 replicas. Pod db-1 is deleted. What is the replacement pod called, and which disk does it get?",
    "options": [
      {"id": "a", "text": "A random name and a new empty disk"},
      {"id": "b", "text": "db-1, and it reattaches db-1's existing PVC"},
      {"id": "c", "text": "db-3, and it shares db-0's disk"},
      {"id": "d", "text": "db-1, with a new empty disk"}
    ],
    "correct": "b",
    "explanation": "StatefulSet pods have stable identities. The replacement keeps the name db-1 and binds to the same PVC it used before." },
  { "id": "k8s-ctrl-sts-q2", "type": "mcq",
    "prompt": "You scale a StatefulSet from 3 to 1 replica. What happens to the PVCs of the removed pods?",
    "options": [
      {"id": "a", "text": "They are deleted immediately"},
      {"id": "b", "text": "They are kept, so the data is still there if you scale back up"},
      {"id": "c", "text": "They are merged into the remaining pod's PVC"},
      {"id": "d", "text": "They are converted to emptyDir volumes"}
    ],
    "correct": "b",
    "explanation": "By default, StatefulSet PVCs outlive the pods. Scaling back up reattaches them. You delete them manually when the data is no longer needed." }
] }
```

## Job: run to completion

A **Job** runs pods until a task finishes successfully, and then stops. It does not restart finished work. Use it for batch processing, data imports or database migrations.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  completions: 10              # 10 successful pod runs are needed in total
  parallelism: 2               # run at most 2 pods at the same time
  backoffLimit: 5              # after 5 failed attempts, mark the Job as failed
  activeDeadlineSeconds: 100   # fail the Job if it runs longer than 100 s overall
  ttlSecondsAfterFinished: 600 # delete the Job and its pods 10 minutes after it finishes
  template:
    spec:
      restartPolicy: Never     # Jobs must use Never or OnFailure
      containers:
      - name: pi
        image: perl:5.40
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
```

```bash
kubectl apply -f job.yaml
kubectl get jobs -w            # COMPLETIONS goes 0/10 → 10/10
kubectl get pods               # finished pods show Completed
kubectl logs job/pi            # output of one of its pods
```

Finished pods are kept (in `Completed` state) so you can read their logs. `ttlSecondsAfterFinished` cleans them up automatically.

```knowledge-check
{ "questions": [
  { "id": "k8s-ctrl-job-q1", "type": "mcq",
    "prompt": "A Job has completions: 6 and parallelism: 3. How does it run?",
    "options": [
      {"id": "a", "text": "3 pods run forever"},
      {"id": "b", "text": "Up to 3 pods run at a time until 6 have succeeded"},
      {"id": "c", "text": "6 pods start at once, 3 of them are later killed"},
      {"id": "d", "text": "It runs 3 times, each time with 6 pods"}
    ],
    "correct": "b",
    "explanation": "parallelism caps how many pods run at the same time; completions is the number of successful runs needed." },
  { "id": "k8s-ctrl-job-q2", "type": "mcq",
    "prompt": "Why can a Job's pod template not use restartPolicy: Always?",
    "options": [
      {"id": "a", "text": "Because a Job must be able to finish; Always would restart the container even after success"},
      {"id": "b", "text": "Because Jobs have no containers"},
      {"id": "c", "text": "Because Always is only for DaemonSets"},
      {"id": "d", "text": "It can; Always is the default for Jobs"}
    ],
    "correct": "a",
    "explanation": "Jobs are meant to end. Only Never and OnFailure are allowed, so a successful container is not started again." }
] }
```

## CronJob: run a Job on a schedule

A **CronJob** creates a new Job at times you choose, using the standard cron format:

```
┌───────── minute (0-59)
│ ┌─────── hour (0-23)
│ │ ┌───── day of month (1-31)
│ │ │ ┌─── month (1-12)
│ │ │ │ ┌─ day of week (0-6, Sunday = 0)
│ │ │ │ │
* * * * *
```

Examples: `*/5 * * * *` every 5 minutes, `0 2 * * *` every day at 02:00, `0 9 * * 1` every Monday at 09:00. Schedules use the controller's time zone (usually UTC) unless you set `spec.timeZone`, for example `timeZone: "Asia/Kolkata"`.

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"          # every minute
  concurrencyPolicy: Forbid        # skip a run if the previous one is still running
  successfulJobsHistoryLimit: 3    # keep the last 3 finished Jobs
  failedJobsHistoryLimit: 1
  jobTemplate:                     # a normal Job spec
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: hello
            image: busybox:1.36
            command: ["/bin/sh", "-c", "date; echo Hello from the Kubernetes cluster"]
```

`concurrencyPolicy` decides what happens when a run is due but the previous one has not finished: `Allow` (default, run both), `Forbid` (skip the new run) or `Replace` (stop the old one, start the new one).

```bash
kubectl get cronjobs
kubectl get jobs -w                                   # a new Job appears every minute
kubectl create job manual-run --from=cronjob/hello    # run it right now, without waiting
kubectl patch cronjob hello -p '{"spec":{"suspend":true}}'   # pause the schedule
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ctrl-cron-q1", "type": "mcq",
    "prompt": "Which schedule runs a CronJob every day at 02:30?",
    "options": [
      {"id": "a", "text": "2 30 * * *"},
      {"id": "b", "text": "30 2 * * *"},
      {"id": "c", "text": "*/30 2 * * *"},
      {"id": "d", "text": "30 * 2 * *"}
    ],
    "correct": "b",
    "explanation": "Fields are minute, hour, day of month, month, day of week. Minute 30, hour 2, every day." },
  { "id": "k8s-ctrl-cron-q2", "type": "mcq",
    "prompt": "A backup CronJob sometimes runs longer than its interval, and two backups must never run at once. Which setting prevents that?",
    "options": [
      {"id": "a", "text": "concurrencyPolicy: Forbid"},
      {"id": "b", "text": "parallelism: 1"},
      {"id": "c", "text": "suspend: true"},
      {"id": "d", "text": "successfulJobsHistoryLimit: 1"}
    ],
    "correct": "a",
    "explanation": "Forbid skips a scheduled run while the previous Job is still active." }
] }
```

## Interview questions and real-world scenarios

**Q: When would you choose a StatefulSet over a Deployment?**
When pods need a stable identity, stable network names, their own persistent disk, or ordered startup: databases, Kafka, ZooKeeper, Elasticsearch. Mention that many teams prefer managed databases or operators instead.

**Q: What is a headless Service and why do StatefulSets need one?**
`clusterIP: None`. DNS returns pod IPs directly, and each pod gets a name like `web-0.nginx`. That lets clients address one specific member (for example the primary).

**Q: How is a DaemonSet scheduled on tainted control-plane nodes?**
By adding a toleration for the control-plane taint. DaemonSet pods also automatically tolerate node-condition taints like not-ready, so node agents keep running on unhealthy nodes.

**Q: A Job keeps failing. What limits how often it retries?**
`backoffLimit` (retries, with growing delay) and `activeDeadlineSeconds` (total time). With `restartPolicy: OnFailure` the container restarts in place; with `Never` new pods are created.

**Q: What happens if a CronJob run takes longer than its interval?**
It depends on `concurrencyPolicy`: Allow runs them in parallel, Forbid skips the new run, Replace stops the old run. Also mention `startingDeadlineSeconds` for runs missed during downtime.

**Real-world scenario: a nightly backup CronJob silently stopped running.**
Check `kubectl get cronjob` (SUSPEND?, LAST SCHEDULE), the Jobs it created, and their pod logs. Common causes: suspended, failing pods hidden by a low `failedJobsHistoryLimit`, or overlapping runs blocked by Forbid. Add an alert on "last successful run older than 26 hours".

**Real-world scenario: finished Job pods fill the namespace.**
Set `ttlSecondsAfterFinished` on Jobs, and history limits on CronJobs.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-ctrl-int-q1",
      "type": "mcq",
      "prompt": "Why is a Deployment a poor fit for a 3-node PostgreSQL cluster?",
      "options": [
        {
          "id": "a",
          "text": "Deployments cannot run PostgreSQL images"
        },
        {
          "id": "b",
          "text": "Deployment pods are interchangeable with random names and no per-pod disk, but each database member needs its own stable identity and storage"
        },
        {
          "id": "c",
          "text": "Deployments cannot have more than 2 replicas"
        },
        {
          "id": "d",
          "text": "Deployments do not support environment variables"
        }
      ],
      "correct": "b",
      "explanation": "StatefulSets (or an operator built on them) provide stable names and per-pod PVCs."
    }
  ]
}
```
