---
kind: quiz
id_key: k8s/observability/quiz
course: fast-kubernetes
section: observability
section_title: Observability
section_position: 9
title: 'Quiz: Observability'
position: 1
estimated_minutes: 15
source: []
pass_percentage: 60
duration_minutes: 15
questions:
    - id_key: q1
      type: mcq
      difficulty: intermediate
      points: 3
      prompt: In the kube-prometheus-stack setup described in the lesson, what role does Helm play?
      multiple: false
      options:
          - text: Helm is used to write PromQL queries against the Prometheus database
            correct: false
          - text: Helm adds the prometheus-community chart repository and installs the kube-prometheus-stack chart, which deploys Prometheus and Grafana onto the cluster
            correct: true
          - text: Helm completely replaces kubectl for all cluster monitoring tasks
            correct: false
          - text: Helm is only used to install the Windows node exporter service
            correct: false
      explanation: |
          The lesson runs `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`,
          `helm pull prometheus-community/kube-prometheus-stack`, and `helm install prometheus
          kube-prometheus-stack` to deploy the whole Prometheus + Grafana stack as a single release
          named prometheus. kubectl is still used afterward for port-forwarding and inspecting pods.
    - id_key: q2
      type: mcq
      difficulty: beginner
      points: 2
      prompt: After installing the kube-prometheus-stack chart with release name `prometheus`, what are the default Grafana login credentials given in the lesson?
      multiple: false
      options:
          - text: 'username: root, password: grafana'
            correct: false
          - text: 'username: admin, password: admin'
            correct: false
          - text: 'username: admin, password: prom-operator'
            correct: true
          - text: No credentials are required; Grafana is open by default
            correct: false
      explanation: |
          The lesson states the default provided username is admin and the default password is
          prom-operator when Grafana is deployed via the kube-prometheus-stack Helm chart.
    - id_key: q3
      type: mcq
      difficulty: intermediate
      points: 3
      prompt: 'The lesson changes Grafana''s Service type from ClusterIP to NodePort (adding nodePort: 32333) in values.yaml before reinstalling the release. Why is this change needed?'
      multiple: false
      options:
          - text: ClusterIP services cannot be scraped by Prometheus
            correct: false
          - text: NodePort exposes the Grafana Service on a static port on every node's IP, making the dashboard reachable at MasterIP:32333 from any machine on the cluster network instead of requiring kubectl port-forward
            correct: true
          - text: NodePort is required for any Helm chart to install successfully
            correct: false
          - text: ClusterIP services are automatically deleted after 24 hours
            correct: false
      explanation: |
          By default the Grafana Service is ClusterIP, reachable only inside the cluster (or via
          kubectl port-forward deployment/prometheus-grafana 3000). Changing the type to NodePort
          and setting nodePort: 32333 exposes it on that port on every node's IP, so the lesson can
          browse to MasterIP:32333 directly.
---
