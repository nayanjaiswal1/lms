---
kind: quiz
id_key: k8s/observability/quiz
course: fast-kubernetes
section: observability
section_title: Monitoring, Logging & Autoscaling
section_position: 9
title: 'Quiz: Monitoring, Logging & Autoscaling'
position: 1
estimated_minutes: 8
source:
  - K8s-Monitoring-Prometheus-Grafana.md
pass_percentage: 70
duration_minutes: 15
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What happens to a pod's logs on the node when the pod is deleted?
    options:
      - text: They are kept forever in etcd
        correct: false
      - text: They are removed, which is why logs are shipped to a central store
        correct: true
      - text: They move to the next pod
        correct: false
      - text: They are emailed to the admin
        correct: false
    explanation: Node logs belong to the container. A log agent DaemonSet ships them to Loki, Elasticsearch or a cloud service.
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What is the typical way to run a log collector like Fluent Bit?
    options:
      - text: As a DaemonSet, one pod per node
        correct: true
      - text: As a CronJob
        correct: false
      - text: Inside every application image
        correct: false
      - text: As a single Deployment replica
        correct: false
    explanation: Each node has its own container log files, so the collector must run on every node.
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: An HPA shows TARGETS <unknown>/60%. What is the most likely cause?
    options:
      - text: The Deployment has too many replicas
        correct: false
      - text: metrics-server is missing, or the pods have no CPU requests
        correct: true
      - text: The HPA must be created with Helm
        correct: false
      - text: The Service is ClusterIP
        correct: false
    explanation: The HPA needs usage data from metrics-server and computes utilization against requests.
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which tool is used to build dashboards on top of Prometheus data?
    options:
      - text: Alertmanager
        correct: false
      - text: Grafana
        correct: true
      - text: kube-proxy
        correct: false
      - text: etcd
        correct: false
    explanation: Grafana visualizes; Prometheus stores and queries; Alertmanager routes alerts.
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: What does the Cluster Autoscaler react to?
    options:
      - text: High CPU usage on a single pod
        correct: false
      - text: Pods that stay Pending because no node has room (and underused nodes it can remove)
        correct: true
      - text: Failed liveness probes
        correct: false
      - text: New Helm releases
        correct: false
    explanation: It adds nodes for unschedulable pods and removes nodes that are mostly empty.
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: Your app exposes /metrics. With kube-prometheus-stack installed, how do you make Prometheus scrape it?
    options:
      - text: Restart Prometheus
        correct: false
      - text: Create a ServiceMonitor that selects your app's Service
        correct: true
      - text: Add the app to kube-system
        correct: false
      - text: Run kubectl top
        correct: false
    explanation: The Prometheus Operator watches ServiceMonitor objects and adds matching Services as scrape targets.
---
