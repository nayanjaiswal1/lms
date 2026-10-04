---
kind: lesson
id_key: k8s/observability/lesson
course: fast-kubernetes
section: observability
section_title: Monitoring, Logging & Autoscaling
section_position: 9
title: Monitoring, Logging and Autoscaling
position: 0
estimated_minutes: 50
source:
  - K8s-Monitoring-Prometheus-Grafana.md
  - K8s-Enable-Dashboard-On-Cluster.md
lab:
  lab_type: terminal
  environment: mindforge/lab-k8s:1.31
  max_duration: 45
  max_resets: 3
  hint_penalty_pct: 10
  is_required: false
  setup_script: |
    #!/bin/bash
    set -euo pipefail
    kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
  files:
    - path: app.yaml
      content: |
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: api
        spec:
          replicas: 2
          selector:
            matchLabels:
              app: api
          template:
            metadata:
              labels:
                app: api
            spec:
              containers:
              - name: api
                image: nginx:1.27
                resources:
                  requests:
                    cpu: 100m
                    memory: 64Mi
                  limits:
                    cpu: 200m
                    memory: 128Mi
        ---
        apiVersion: v1
        kind: Pod
        metadata:
          name: reporter
        spec:
          nodeSelector:
            hardware: gpu
          containers:
          - name: reporter
            image: busybox:1.36
  tasks:
    - id_key: find-pending-reason
      title: Find out why a pod is not running
      points: 15
      is_stateful: true
      description: |
        Apply `app.yaml`. One pod never starts. Use `kubectl get pods`, `kubectl describe pod` and `kubectl get events --sort-by=.lastTimestamp` to find which pod it is and why. Save the **name of the node label** it is waiting for (just the key) to `~/work/answer.txt`.
      verification_script: |
        #!/bin/bash
        grep -qx 'hardware' /home/labuser/work/answer.txt
      hint_context: Look for the FailedScheduling event. It says the node(s) did not match the pod's node affinity/selector. Then read the pod's nodeSelector.
      explanation_context: The reporter pod has nodeSelector hardware=gpu and no node has that label. Events plus describe answer most "why isn't it running" questions within a minute.
      solution_script: |
        kubectl apply -f /home/labuser/work/app.yaml
        echo hardware > /home/labuser/work/answer.txt
    - id_key: create-hpa
      title: Add a HorizontalPodAutoscaler
      points: 15
      is_stateful: true
      description: Create an HPA for the `api` Deployment that keeps average CPU around **60%**, with at least **2** and at most **8** replicas. Check it with `kubectl get hpa`.
      verification_script: |
        #!/bin/bash
        test "$(kubectl get hpa api -o jsonpath='{.spec.minReplicas} {.spec.maxReplicas} {.spec.metrics[0].resource.target.averageUtilization}')" = "2 8 60"
      hint_context: "`kubectl autoscale deployment <name> --cpu-percent=<n> --min=<n> --max=<n>`"
      explanation_context: The HPA compares actual CPU usage (from metrics-server) with the pods' CPU requests. This sandbox has no metrics-server, so TARGETS shows <unknown>, which is exactly what you would see on a real cluster that is missing it.
      solution_script: kubectl autoscale deployment api --cpu-percent=60 --min=2 --max=8
    - id_key: hpa-memory-v2
      title: Write an autoscaling/v2 HPA with two metrics
      points: 20
      is_stateful: false
      description: |
        Replace the HPA: delete `api` and write `hpa.yaml` with `apiVersion: autoscaling/v2`, name `api`, targeting Deployment `api`, min 2, max 10, and **two** metrics: CPU average utilization 60% and memory average utilization 75%. Apply it.
      verification_script: |
        #!/bin/bash
        test "$(kubectl get hpa api -o jsonpath='{.spec.maxReplicas}')" = "10" || exit 1
        M=$(kubectl get hpa api -o jsonpath='{range .spec.metrics[*]}{.resource.name}={.resource.target.averageUtilization}{"\n"}{end}' | sort | tr '\n' ' ')
        test "$M" = "cpu=60 memory=75 "
      hint_context: "`metrics:` is a list; each item has `type: Resource` and `resource:` with `name` and `target: {type: Utilization, averageUtilization: N}`. `scaleTargetRef` names the Deployment."
      explanation_context: With several metrics the HPA computes a replica count for each and uses the highest, so the app scales up if either CPU or memory is high.
      solution_script: |
        kubectl delete hpa api
        cat > /home/labuser/work/hpa.yaml <<'Y'
        apiVersion: autoscaling/v2
        kind: HorizontalPodAutoscaler
        metadata:
          name: api
        spec:
          scaleTargetRef:
            apiVersion: apps/v1
            kind: Deployment
            name: api
          minReplicas: 2
          maxReplicas: 10
          metrics:
          - type: Resource
            resource:
              name: cpu
              target:
                type: Utilization
                averageUtilization: 60
          - type: Resource
            resource:
              name: memory
              target:
                type: Utilization
                averageUtilization: 75
        Y
        kubectl apply -f /home/labuser/work/hpa.yaml
---

Running an app is only half the job. You also need to see what it is doing, find problems before users do, and handle more traffic without waking anyone up. This lesson covers the three pillars of **observability** in Kubernetes (events and logs, metrics, dashboards and alerts) plus **autoscaling**, which is built on metrics.

## Looking at the cluster with kubectl

Before any fancy tool, kubectl answers most questions:

```bash
kubectl get nodes -o wide                  # node status, versions, IPs
kubectl get pods -A -o wide                # every pod, where it runs
kubectl get pods -w                        # watch changes live (Linux: watch kubectl get pods)
kubectl get all -n shop                    # the common objects in a namespace
kubectl describe pod <name>                # details + Events
kubectl get events -A --sort-by=.lastTimestamp          # recent cluster events
kubectl get events --field-selector type=Warning        # only problems
```

**Events** are short records of what happened: pod scheduled, image pulled, probe failed, container killed, volume could not attach. They are kept for only about **one hour** by default, so look at them soon after a problem, or ship them to your logging system.

A quick health check you can run any time:

```bash
kubectl get nodes                                      # are all nodes Ready?
kubectl get pods -A | grep -v -E 'Running|Completed'   # anything not healthy?
kubectl get events -A --field-selector type=Warning
```

[[lab-task:1]]

```knowledge-check
{ "questions": [
  { "id": "k8s-obs-kubectl-q1", "type": "mcq",
    "prompt": "A pod failed to start two days ago and `kubectl get events` shows nothing about it. Why?",
    "options": [
      {"id": "a", "text": "Events are only kept for a short time (about an hour by default)"},
      {"id": "b", "text": "Events are only recorded for Deployments"},
      {"id": "c", "text": "You need helm to see events"},
      {"id": "d", "text": "Events are stored inside the container"}
    ],
    "correct": "a",
    "explanation": "Events expire quickly. For history, forward events and logs to a central system." }
] }
```

## Logs

Kubernetes expects apps to write logs to **stdout and stderr**, not to files. The container runtime stores that output on the node, and `kubectl logs` reads it:

```bash
kubectl logs deploy/api                  # one pod of a Deployment
kubectl logs -l app=api --all-containers --prefix   # every pod with the label
kubectl logs api-7c9d-xk2 -c sidecar     # a specific container
kubectl logs api-7c9d-xk2 --previous     # the crashed instance
kubectl logs api-7c9d-xk2 --since=15m -f # last 15 minutes, then follow
```

The catch: node logs are rotated and **deleted with the pod**. When a pod is gone, so are its logs. In production you ship logs off the nodes:

- A **log agent DaemonSet** (Fluent Bit, Fluentd, Vector, Promtail/Alloy) runs on every node, reads all container logs from `/var/log/containers`, and sends them to a store.
- The store and UI: **Loki + Grafana**, **Elasticsearch/OpenSearch + Kibana (EFK)**, or a cloud service (CloudWatch, Cloud Logging, Azure Monitor).

Write logs as **structured JSON** with a level, a timestamp and a request ID. That makes them searchable.

```knowledge-check
{ "questions": [
  { "id": "k8s-obs-logs-q1", "type": "mcq",
    "prompt": "Where should an app running in Kubernetes write its logs?",
    "options": [
      {"id": "a", "text": "To a file inside the container"},
      {"id": "b", "text": "To stdout/stderr, so the runtime and log agents can collect them"},
      {"id": "c", "text": "Directly into etcd"},
      {"id": "d", "text": "Into a ConfigMap"}
    ],
    "correct": "b",
    "explanation": "stdout/stderr is what kubectl logs and node log agents read. Files inside the container disappear with it." }
] }
```

## Metrics: metrics-server and kubectl top

**metrics-server** collects current CPU and memory usage from every kubelet. It powers `kubectl top` and the autoscalers. Most managed clusters have it; on minikube run `minikube addons enable metrics-server`.

```bash
kubectl top nodes
kubectl top pods -A --sort-by=memory
kubectl top pod api-7c9d-xk2 --containers
```

If you get `error: Metrics API not available`, metrics-server is not installed. metrics-server only keeps the **latest** values; it is not a monitoring system with history. For history, graphs and alerts you need Prometheus.

```knowledge-check
{ "questions": [
  { "id": "k8s-obs-metrics-q1", "type": "mcq",
    "prompt": "`kubectl top pods` fails with 'Metrics API not available'. What is missing?",
    "options": [
      {"id": "a", "text": "Prometheus"},
      {"id": "b", "text": "metrics-server"},
      {"id": "c", "text": "An Ingress controller"},
      {"id": "d", "text": "Helm"}
    ],
    "correct": "b",
    "explanation": "kubectl top reads from the Metrics API, which metrics-server provides." }
] }
```

## Prometheus and Grafana

The standard monitoring stack:

- **Prometheus** *scrapes* (pulls) metrics over HTTP from targets every few seconds and stores them as time series. You query it with **PromQL**.
- **node-exporter** (a DaemonSet) exposes node metrics: CPU, memory, disk, network.
- **kube-state-metrics** exposes the state of Kubernetes objects: desired vs available replicas, pod restarts, pending pods.
- **Alertmanager** sends alerts (Slack, email, PagerDuty) when rules fire.
- **Grafana** draws dashboards from Prometheus data.

The **kube-prometheus-stack** Helm chart installs all of these, with ready-made dashboards and alerts:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# open http://localhost:3000 ; user admin, password from:
kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

To expose Grafana without port-forward, set its Service type in your values file (for example `grafana.service.type: NodePort`) or add an Ingress. To make Prometheus scrape your own app, expose a `/metrics` endpoint and create a **ServiceMonitor** object that points at your app's Service.

A few PromQL queries worth knowing:

```
sum(rate(container_cpu_usage_seconds_total{namespace="shop"}[5m])) by (pod)       # CPU per pod
kube_deployment_status_replicas_available / kube_deployment_spec_replicas           # health of deployments
increase(kube_pod_container_status_restarts_total[1h]) > 3                          # pods restarting often
```

You can also monitor nodes outside Kubernetes (for example Windows servers with windows_exporter) by adding them as extra scrape targets in the chart's values (`prometheus.prometheusSpec.additionalScrapeConfigs`).

```knowledge-check
{ "questions": [
  { "id": "k8s-obs-prom-q1", "type": "mcq",
    "prompt": "How does Prometheus get metrics from your application?",
    "options": [
      {"id": "a", "text": "The app pushes metrics into etcd"},
      {"id": "b", "text": "Prometheus scrapes an HTTP endpoint (usually /metrics) on a schedule"},
      {"id": "c", "text": "Grafana collects them and forwards them to Prometheus"},
      {"id": "d", "text": "kubectl top sends them"}
    ],
    "correct": "b",
    "explanation": "Prometheus is pull-based. A ServiceMonitor tells the Prometheus Operator which Services to scrape." },
  { "id": "k8s-obs-prom-q2", "type": "mcq",
    "prompt": "Which component gives Prometheus the number of desired vs available replicas of each Deployment?",
    "options": [
      {"id": "a", "text": "node-exporter"},
      {"id": "b", "text": "kube-state-metrics"},
      {"id": "c", "text": "Grafana"},
      {"id": "d", "text": "CoreDNS"}
    ],
    "correct": "b",
    "explanation": "kube-state-metrics turns the state of Kubernetes objects into metrics. node-exporter covers machine-level metrics." }
] }
```

## The Kubernetes Dashboard

The **Kubernetes Dashboard** is a web UI to browse and edit cluster objects. On minikube: `minikube dashboard`. On other clusters install it with its Helm chart and log in with a ServiceAccount token:

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard -n kubernetes-dashboard --create-namespace
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
kubectl -n kubernetes-dashboard create token <service-account-name>    # paste this token to log in
```

Never expose the dashboard to the internet, and do not give it cluster-admin rights "to make it work". A dashboard with admin rights is an open door into your whole cluster. Many teams use tools like **k9s** (a terminal UI) or **Headlamp** / **Lens** instead.

```knowledge-check
{ "questions": [
  { "id": "k8s-obs-dash-q1", "type": "mcq",
    "prompt": "Why is exposing the Kubernetes Dashboard publicly with a cluster-admin token dangerous?",
    "options": [
      {"id": "a", "text": "It makes the cluster slower"},
      {"id": "b", "text": "Anyone who gets in can control every object in the cluster"},
      {"id": "c", "text": "The dashboard deletes pods automatically"},
      {"id": "d", "text": "It disables RBAC"}
    ],
    "correct": "b",
    "explanation": "The dashboard acts with the permissions of the token used. Keep it private and give it minimal rights." }
] }
```

## Autoscaling

Picture a restaurant kitchen on a busy Saturday night. The manager watches how many orders are waiting and calls in extra cooks when the queue grows, then sends them home once things are quiet again. That is what the autoscalers below do, just with pods and nodes instead of cooks. Kubernetes can scale at three levels:

| Autoscaler | Scales | Based on |
|---|---|---|
| **HorizontalPodAutoscaler (HPA)** | The number of **pods** of a Deployment/StatefulSet | CPU, memory or custom metrics |
| **VerticalPodAutoscaler (VPA)** | The **requests/limits** of pods | Observed usage over time |
| **Cluster Autoscaler / Karpenter** | The number of **nodes** | Pods stuck Pending for lack of room |

They work together: traffic grows → HPA adds pods → new pods do not fit → the cluster autoscaler adds a node.

Creating an HPA:

```bash
kubectl autoscale deployment api --cpu-percent=60 --min=2 --max=8
kubectl get hpa -w
```

or declaratively:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60     # % of the pods' CPU *request*
```

Things that trip people up:

- The HPA needs **metrics-server**. Without it TARGETS shows `<unknown>` and nothing scales.
- Utilization is measured **against requests**. Pods without CPU requests cannot be autoscaled on CPU.
- Remove `replicas` from the Deployment YAML (or ignore it in GitOps). Otherwise every `kubectl apply` fights the HPA.
- The HPA scales **down slowly** on purpose (a 5-minute stabilization window by default) to avoid flapping.
- For queue-based or event-driven scaling (including scaling to zero), look at **KEDA**.

[[lab-task:2]]

[[lab-task:3]]

```knowledge-check
{ "questions": [
  { "id": "k8s-obs-hpa-q1", "type": "mcq",
    "prompt": "An HPA targets 50% CPU. Pods request 200m CPU and each uses about 200m. What does the HPA do?",
    "options": [
      {"id": "a", "text": "Nothing; usage equals the request"},
      {"id": "b", "text": "Scales up, because usage is 100% of the request, double the 50% target"},
      {"id": "c", "text": "Scales down"},
      {"id": "d", "text": "Raises the CPU limit"}
    ],
    "correct": "b",
    "explanation": "Utilization = usage / request = 100%. The HPA adds pods until the average is back near 50%, roughly doubling the replicas." },
  { "id": "k8s-obs-hpa-q2", "type": "mcq",
    "prompt": "Pods are Pending with 'Insufficient cpu' after the HPA scaled up. Which component fixes this?",
    "options": [
      {"id": "a", "text": "VerticalPodAutoscaler"},
      {"id": "b", "text": "Cluster Autoscaler (or Karpenter), which adds nodes"},
      {"id": "c", "text": "metrics-server"},
      {"id": "d", "text": "kube-proxy"}
    ],
    "correct": "b",
    "explanation": "The HPA adds pods; when they do not fit, the cluster autoscaler adds nodes for them." }
] }
```

## Interview questions and real-world scenarios

**Q: What are the three pillars of observability?**
Metrics (Prometheus), logs (Loki/EFK), traces (OpenTelemetry with Jaeger/Tempo). Events are a fourth Kubernetes-specific signal.

**Q: How do you collect logs in Kubernetes?**
Apps log to stdout/stderr; a DaemonSet agent (Fluent Bit, Vector, Alloy) ships node logs to a central store. Sidecar log shippers are only for apps that must write files.

**Q: What would you alert on for a web service?**
User-facing symptoms first: error rate, latency (p95/p99), availability (the "golden signals", also traffic and saturation). Plus platform alerts: pods crash-looping, nodes NotReady, disk almost full, certificates expiring, PVs filling up.

**Q: How does HPA calculate replicas?**
desired = ceil(current × currentMetric / target), within min/max, with a scale-down stabilization window. Utilization is against requests.

**Q: HPA vs VPA vs Cluster Autoscaler?**
More pods, bigger pods, more nodes. Don't use HPA and VPA on the same CPU/memory metric at the same time.

**Real-world scenario: traffic spike, HPA scaled up, but latency is still high.**
New pods are Pending (no node capacity → cluster autoscaler too slow or at max), pods are slow to become ready (long startup), or the bottleneck is elsewhere (the database). Check pending pods, readiness time and database metrics; consider a higher `minReplicas` before known peaks.

**Real-world scenario: "We have no idea why it was slow last night."**
Logs were lost with the pods and metrics weren't retained. Set up central logs, Prometheus with retention (or long-term storage like Thanos/Mimir), and dashboards per service.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-obs-int-q1",
      "type": "mcq",
      "prompt": "Which alert is most useful to page an engineer at night for a web API?",
      "options": [
        {
          "id": "a",
          "text": "CPU of one pod above 50%"
        },
        {
          "id": "b",
          "text": "Error rate above 5% for 5 minutes (a user-facing symptom)"
        },
        {
          "id": "c",
          "text": "A new Deployment was created"
        },
        {
          "id": "d",
          "text": "A ConfigMap changed"
        }
      ],
      "correct": "b",
      "explanation": "Page on symptoms users feel (errors, latency). Resource-level signals are better as dashboards or low-urgency alerts."
    }
  ]
}
```
