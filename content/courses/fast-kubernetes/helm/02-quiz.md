---
kind: quiz
id_key: k8s/helm/quiz
course: fast-kubernetes
section: helm
section_title: Helm & Packaging
section_position: 8
title: 'Quiz: Helm & Packaging'
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
      prompt: What is a Helm chart?
      multiple: false
      options:
          - text: A running instance of an application inside a Kubernetes namespace
            correct: false
          - text: A packaged collection of Kubernetes YAML templates plus a values.yaml file and Chart.yaml metadata that together define a deployable application
            correct: true
          - text: A remote server that stores container images, similar to a Docker registry
            correct: false
          - text: A Kubernetes admission webhook that validates Helm-managed resources
            correct: false
      explanation: |
          A Helm chart is the package format Helm installs. Its values.yaml holds configurable
          values that get injected into the template files (e.g. replicas: {{ .Values.replicaCount }}),
          Chart.yaml holds chart metadata (apiVersion, appVersion, maintainers, description), and the
          template/ directory holds the actual Kubernetes manifest templates (Deployment, Service,
          ConfigMap, Secret, etc.).
    - id_key: q2
      type: mcq
      difficulty: intermediate
      points: 2
      prompt: 'After running `helm install my-release bitnami/wordpress`, what does `my-release` represent?'
      multiple: false
      options:
          - text: The name of the Helm repository the chart was pulled from
            correct: false
          - text: The name assigned to this specific installed instance (release) of the chart, used by later commands such as helm status, helm upgrade, and helm uninstall
            correct: true
          - text: The Kubernetes namespace the chart will be installed into
            correct: false
          - text: The version tag of the chart being installed
            correct: false
      explanation: |
          Helm calls an installed instance of a chart a "release". Commands like helm status
          <release>, helm upgrade -f values.yaml <release> <chart>, helm rollback <release>
          <revision>, and helm uninstall <release name> all operate on that release name, not on
          the chart or repository name.
    - id_key: q3
      type: mcq
      difficulty: beginner
      points: 2
      prompt: Which command adds a new chart repository (e.g. Bitnami's) to your local Helm client so its charts can be searched and installed from your machine?
      multiple: false
      options:
          - text: helm search hub bitnami
            correct: false
          - text: helm pull bitnami
            correct: false
          - text: helm repo add bitnami https://charts.bitnami.com/bitnami
            correct: true
          - text: helm install bitnami
            correct: false
      explanation: |
          helm repo add [name] [url] registers a chart repository locally; helm repo list then
          shows it and helm search repo searches the locally added repositories. helm search hub
          instead searches Artifact Hub directly without needing a local repo add, and helm pull
          only downloads a chart archive from a repo that has already been added.
---
