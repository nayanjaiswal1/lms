---
kind: quiz
id_key: k8s/helm/quiz
course: fast-kubernetes
section: helm
section_title: 'Helm: Packaging Applications'
section_position: 8
title: 'Quiz: Helm'
position: 1
estimated_minutes: 8
source:
  - Helm.md
  - HelmCheatsheet.md
  - K8s-Helm-Jenkins.md
pass_percentage: 70
duration_minutes: 15
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What is a Helm release?
    options:
      - text: A new version of Helm itself
        correct: false
      - text: One installed instance of a chart in a cluster, with its own name and revision history
        correct: true
      - text: A chart repository
        correct: false
      - text: A Docker image
        correct: false
    explanation: Installing a chart creates a release. Upgrades and rollbacks add revisions to it.
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which file in a chart holds the default settings?
    options:
      - text: Chart.yaml
        correct: false
      - text: values.yaml
        correct: true
      - text: templates/_helpers.tpl
        correct: false
      - text: NOTES.txt
        correct: false
    explanation: values.yaml has the defaults; Chart.yaml has metadata such as name, version and appVersion.
  - id_key: q3
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: What is the difference between `version` and `appVersion` in Chart.yaml?
    options:
      - text: They must always be equal
        correct: false
      - text: version is the chart package's version; appVersion is the version of the application it deploys
        correct: true
      - text: version is for Helm 2, appVersion for Helm 3
        correct: false
      - text: appVersion is the Kubernetes version
        correct: false
    explanation: Bump version whenever the chart changes; appVersion tracks the app (often the default image tag).
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Where does Helm 3 store release history?
    options:
      - text: In Tiller running in kube-system
        correct: false
      - text: As Secrets in the release's namespace
        correct: true
      - text: In ~/.helm on your laptop only
        correct: false
      - text: In the chart repository
        correct: false
    explanation: Helm 3 has no server component; release data lives in the cluster as Secrets.
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: Which flag makes `helm upgrade` roll back automatically if the upgrade fails?
    options:
      - text: --force
        correct: false
      - text: --atomic
        correct: true
      - text: --dry-run
        correct: false
      - text: --reuse-values
        correct: false
    explanation: --atomic waits for the upgrade to succeed and rolls back if it does not.
  - id_key: q6
    type: mcq
    difficulty: beginner
    points: 1
    prompt: A release is behaving strangely. Which command shows the manifests Helm actually applied?
    options:
      - text: helm get manifest <release>
        correct: true
      - text: helm repo list
        correct: false
      - text: helm search hub
        correct: false
      - text: helm version
        correct: false
    explanation: helm get manifest prints the rendered YAML of the current revision.
  - id_key: q7
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: After `helm uninstall db`, the PostgreSQL data is still on disk. Why?
    options:
      - text: Helm uninstall is broken
        correct: false
      - text: PVCs created from a StatefulSet's volumeClaimTemplates are not owned by the release, so they are kept
        correct: true
      - text: Helm moves the data to etcd
        correct: false
      - text: The data is in a ConfigMap
        correct: false
    explanation: This protects data by default. Delete the PVCs manually if you really want the data gone.
---
