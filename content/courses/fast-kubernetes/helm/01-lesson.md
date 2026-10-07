---
kind: lesson
id_key: k8s/helm/lesson
course: fast-kubernetes
section: helm
section_title: 'Helm: Packaging Applications'
section_position: 8
title: Helm Charts, Releases and Values
position: 0
estimated_minutes: 50
source:
  - Helm.md
  - HelmCheatsheet.md
  - K8s-Helm-Jenkins.md
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
  tasks:
    - id_key: create-chart
      title: Create a chart
      points: 10
      is_stateful: true
      description: In your work folder, create a new chart called `webapp` with `helm create`. Look around with `ls -R webapp` and open `webapp/values.yaml` and `webapp/templates/deployment.yaml`.
      verification_script: |
        #!/bin/bash
        test -f /home/labuser/work/webapp/Chart.yaml && test -f /home/labuser/work/webapp/values.yaml && test -f /home/labuser/work/webapp/templates/deployment.yaml
      hint_context: "`helm create <name>`"
      explanation_context: helm create writes a complete working chart (a Deployment, Service, optional Ingress and HPA) that you can adapt. Most real charts start like this.
      solution_script: cd /home/labuser/work && helm create webapp
    - id_key: render-template
      title: Render the templates without installing
      points: 10
      is_stateful: false
      description: Render the chart with the release name `web` and `replicaCount=2`, and save the output to `~/work/rendered.yaml`. Open it and find the Deployment's `replicas:` line.
      verification_script: |
        #!/bin/bash
        f=/home/labuser/work/rendered.yaml
        grep -q 'kind: Deployment' "$f" && grep -q 'replicas: 2' "$f" && grep -q 'name: web-webapp' "$f"
      hint_context: "`helm template <release> <chart-dir> --set key=value > file`"
      explanation_context: helm template shows exactly the YAML Helm would send to the cluster. It is the first thing to run when a chart does not do what you expect.
      solution_script: cd /home/labuser/work && helm template web ./webapp --set replicaCount=2 > rendered.yaml
    - id_key: install-release
      title: Install a release
      points: 15
      is_stateful: true
      description: Install the chart as a release named `web` with 2 replicas. Then run `helm list`, `helm status web` and `kubectl get deploy,svc`.
      verification_script: |
        #!/bin/bash
        helm status web -o json 2>/dev/null | grep -q '"status":"deployed"' || exit 1
        test "$(kubectl get deployment web-webapp -o jsonpath='{.spec.replicas}')" = "2"
      hint_context: "`helm install <release> <chart-dir> --set replicaCount=2`"
      explanation_context: Helm rendered the templates, applied them, and stored the release (revision 1) as a Secret in the namespace. Every object is named after the release, here web-webapp.
      solution_script: cd /home/labuser/work && helm install web ./webapp --set replicaCount=2
    - id_key: upgrade-values-file
      title: Upgrade with a values file
      points: 20
      is_stateful: true
      description: |
        Create `~/work/prod-values.yaml` that sets `replicaCount` to `3` and `image.tag` to `"1.27"`. Upgrade the `web` release with it (keep the chart the same). Check `helm history web`.
      verification_script: |
        #!/bin/bash
        test "$(kubectl get deployment web-webapp -o jsonpath='{.spec.replicas} {.spec.template.spec.containers[0].image}')" = "3 nginx:1.27" || exit 1
        helm history web | awk 'NR>1{print $1}' | grep -qx 2
      hint_context: "`image.tag` means a nested key: `image:` then `  tag: \"1.27\"` on the next line. Then `helm upgrade web ./webapp -f prod-values.yaml`."
      explanation_context: Values from -f override the chart's values.yaml. The upgrade created revision 2 and rolled the Deployment to the new image.
      solution_script: |
        cd /home/labuser/work
        printf 'replicaCount: 3\nimage:\n  tag: "1.27"\n' > prod-values.yaml
        helm upgrade web ./webapp -f prod-values.yaml
    - id_key: rollback-release
      title: Roll back the release
      points: 15
      is_stateful: false
      description: Roll the `web` release back to revision 1. Check `helm history web` again and the Deployment's replicas and image.
      verification_script: |
        #!/bin/bash
        test "$(kubectl get deployment web-webapp -o jsonpath='{.spec.replicas}')" = "2" || exit 1
        helm history web | awk 'NR>1{print $1}' | grep -qx 3
      hint_context: "`helm rollback <release> <revision>`"
      explanation_context: A rollback re-applies revision 1's rendered manifests and records them as a new revision (3). History is never rewritten.
      solution_script: helm rollback web 1
---

Look at a typical app: a Deployment, a Service, a ConfigMap, a Secret, an Ingress, maybe a HorizontalPodAutoscaler. That is six YAML files, and you need slightly different versions for dev, staging and production. Copying and editing them by hand quickly goes wrong. **Helm** is the package manager for Kubernetes that solves this.

## What Helm does

A Helm chart is like a thali menu at a restaurant: the fixed items (rice, dal, sabzi) are the manifests, and the spice-level or portion-size choice at the counter is what you override in `values.yaml`. You get a full, working meal without writing the recipe yourself. Helm bundles all of an app's Kubernetes manifests into one **chart**, with **variables** for everything that differs between installs. It gives you:

- **Templating**: write the YAML once, fill in values (replica count, image tag, host name) per environment.
- **Packaging and sharing**: install someone else's app (PostgreSQL, Prometheus, Jenkins) with one command instead of writing dozens of manifests.
- **Release management**: every install is tracked. You can upgrade, see the history, and roll back.

Three words to know:

| Term | Meaning |
|---|---|
| **Chart** | The package: templates + default values + metadata. |
| **Release** | One installed instance of a chart in a cluster, with a name. You can install the same chart twice as two releases (`blog-dev`, `blog-prod`). |
| **Repository** | A place where charts are published (an HTTP server or an OCI registry). **Artifact Hub** (artifacthub.io) is where you search for public charts. |

Helm 3 is just a client. It talks to the API server with your kubeconfig, like kubectl, and stores release history as Secrets in the release's namespace. (The old server-side component "Tiller" from Helm 2 no longer exists.)

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-what-q1", "type": "mcq",
    "prompt": "You install the same chart twice, once as `shop-dev` and once as `shop-prod`. How many releases exist?",
    "options": [
      {"id": "a", "text": "One; charts can only be installed once"},
      {"id": "b", "text": "Two separate releases, each with its own history and values"},
      {"id": "c", "text": "Zero until you run helm package"},
      {"id": "d", "text": "One release with two revisions"}
    ],
    "correct": "b",
    "explanation": "A chart is the package; each install creates an independent release." }
] }
```

## Installing Helm and using public charts

```bash
# Linux/macOS (official script); or use your package manager: brew install helm, choco install kubernetes-helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

Working with repositories:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami   # add a repo to your local list
helm repo update                                          # refresh the chart index
helm repo list
helm search repo wordpress                                # search your added repos
helm search hub wordpress                                 # search Artifact Hub
helm show values bitnami/wordpress > wp-values.yaml       # see every setting the chart offers
helm pull bitnami/jenkins --untar                         # download a chart to read or modify it
```

Many charts are now published to **OCI registries** and installed without `repo add`:

```bash
helm install my-redis oci://registry-1.docker.io/bitnamicharts/redis
```

Always read the chart's values (`helm show values`) before installing. That is the chart's "settings page". Also check that a chart is actively maintained (recent releases, who publishes it). For example, Bitnami cut back its free chart and image catalog in 2025, so many older tutorials point to charts that are no longer updated. Prefer charts published by the software's own project when they exist.

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-repo-q1", "type": "mcq",
    "prompt": "Before installing a public chart, how do you see all the settings you can change?",
    "options": [
      {"id": "a", "text": "helm show values <chart>"},
      {"id": "b", "text": "helm list"},
      {"id": "c", "text": "helm history <chart>"},
      {"id": "d", "text": "kubectl describe chart <chart>"}
    ],
    "correct": "a",
    "explanation": "helm show values prints the chart's default values.yaml, which documents every configurable option." }
] }
```

## Inside a chart

`helm create webapp` generates this layout:

```
webapp/
├── Chart.yaml          # name, version (of the chart), appVersion (of the app), dependencies
├── values.yaml         # default values
├── charts/             # dependency charts (subcharts)
└── templates/          # Kubernetes manifests with template placeholders
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── hpa.yaml
    ├── _helpers.tpl    # reusable named snippets (names, labels)
    └── NOTES.txt       # message printed after install
```

A template uses Go template syntax. Values from `values.yaml` appear under `.Values`:

```yaml
# templates/deployment.yaml (simplified)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-{{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
```

```yaml
# values.yaml
replicaCount: 1
image:
  repository: nginx
  tag: ""
```

- `.Values` = your values, `.Release.Name` = the release name, `.Chart` = data from Chart.yaml.
- `| default ...` is a template function. There are many (`quote`, `upper`, `toYaml`, `indent`...).
- `{{- if .Values.ingress.enabled }} ... {{- end }}` turns whole objects on or off.
- `Chart.yaml` has two versions: `version` (the chart's own version, bump it on every chart change) and `appVersion` (the version of the app it deploys).

[[lab-task:1]]

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-chart-q1", "type": "mcq",
    "prompt": "In a template, what does `{{ .Values.replicaCount }}` become?",
    "options": [
      {"id": "a", "text": "The number of existing pods"},
      {"id": "b", "text": "The replicaCount value from values.yaml, or from an override given at install/upgrade time"},
      {"id": "c", "text": "The chart version"},
      {"id": "d", "text": "Always 1"}
    ],
    "correct": "b",
    "explanation": ".Values holds the merged values: chart defaults overridden by -f files and --set flags." }
] }
```

## Checking a chart before installing it

Never install blind. These commands render or validate without changing the cluster:

```bash
helm lint ./webapp                                   # find mistakes in the chart
helm template web ./webapp --set replicaCount=2      # print the rendered YAML
helm install web ./webapp --dry-run --debug          # simulate an install against the cluster
helm get manifest web                                # the YAML of an already-installed release
```

`helm template` is the most useful debugging tool: when a release does not look right, render it and read the YAML.

[[lab-task:2]]

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-check-q1", "type": "mcq",
    "prompt": "Which command shows the exact Kubernetes YAML a chart will produce, without touching the cluster?",
    "options": [
      {"id": "a", "text": "helm template <release> <chart>"},
      {"id": "b", "text": "helm install <release> <chart>"},
      {"id": "c", "text": "helm rollback <release>"},
      {"id": "d", "text": "helm repo update"}
    ],
    "correct": "a",
    "explanation": "helm template renders locally and prints the YAML." }
] }
```

## Install, upgrade, rollback, uninstall

```bash
helm install web ./webapp                                  # from a local folder
helm install wp bitnami/wordpress -n blog --create-namespace
helm list -A                                               # releases in all namespaces
helm status web
helm upgrade web ./webapp -f prod-values.yaml              # apply new values or a new chart version
helm upgrade --install web ./webapp -f prod-values.yaml    # install if missing, else upgrade (great for CI)
helm history web                                           # revisions
helm rollback web 1                                        # back to revision 1
helm uninstall web                                         # delete all objects of the release
```

Useful flags for real deployments:

- `--atomic`: if the upgrade fails, roll back automatically.
- `--wait --timeout 5m`: wait until pods are ready before calling it a success.
- `--version 1.2.3`: pin the chart version (do this in production).

Note: `helm uninstall` usually does **not** delete PVCs created by StatefulSets, so database data survives. Delete them yourself when you mean it.

[[lab-task:3]]

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-lifecycle-q1", "type": "mcq",
    "prompt": "A CI pipeline should create the release the first time and upgrade it on every later run. Which command fits?",
    "options": [
      {"id": "a", "text": "helm install"},
      {"id": "b", "text": "helm upgrade --install"},
      {"id": "c", "text": "helm template | kubectl apply"},
      {"id": "d", "text": "helm rollback"}
    ],
    "correct": "b",
    "explanation": "upgrade --install is idempotent: it installs if the release does not exist and upgrades otherwise." }
] }
```

## Overriding values

Values are merged in this order (later wins):

1. The chart's `values.yaml`
2. Files passed with `-f` / `--values` (in the order given)
3. `--set key=value` flags

```bash
helm install web ./webapp -f values-common.yaml -f values-prod.yaml --set image.tag=1.27
helm get values web            # the values you supplied for this release
helm get values web --all      # every value, including defaults
```

Keep one values file per environment in Git (`values-dev.yaml`, `values-prod.yaml`). Use `--set` only for small things like an image tag from CI. **Never put real passwords in values files in Git**; reference an existing Secret or use a secrets tool.

[[lab-task:4]]

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-values-q1", "type": "mcq",
    "prompt": "values.yaml says replicaCount: 1, prod.yaml says replicaCount: 3, and you run `helm install app ./chart -f prod.yaml --set replicaCount=5`. How many replicas?",
    "options": [
      {"id": "a", "text": "1"},
      {"id": "b", "text": "3"},
      {"id": "c", "text": "5"},
      {"id": "d", "text": "9"}
    ],
    "correct": "c",
    "explanation": "--set has the highest priority, then -f files, then the chart defaults." }
] }
```

## Real example: Jenkins with Helm

Installing a CI server shows why Helm is popular. Without Helm you would write a StatefulSet, Service, PVC, ServiceAccount, RBAC rules and a ConfigMap. With Helm:

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm show values jenkins/jenkins > jenkins-values.yaml    # e.g. set controller.serviceType: NodePort
helm install jenkins jenkins/jenkins -n jenkins --create-namespace -f jenkins-values.yaml

# the admin password is stored in a Secret created by the chart
kubectl get secret -n jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 -d
kubectl port-forward -n jenkins svc/jenkins 8080:8080     # then open http://localhost:8080
```

The same pattern (repo add → show values → install with your values file) works for Prometheus, Grafana, PostgreSQL, Redis and most other software.

**Helm vs Kustomize**: Kustomize (built into `kubectl apply -k`) customizes plain YAML with overlays instead of templates. Teams often use Helm for third-party software and either Helm or Kustomize for their own apps. GitOps tools such as Argo CD and Flux can deploy both.

[[lab-task:5]]

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-real-q1", "type": "mcq",
    "prompt": "A Helm upgrade made the app crash. What is the fastest way back to the last working version?",
    "options": [
      {"id": "a", "text": "helm uninstall and reinstall"},
      {"id": "b", "text": "helm rollback <release> <last-good-revision>"},
      {"id": "c", "text": "kubectl delete pods"},
      {"id": "d", "text": "helm repo update"}
    ],
    "correct": "b",
    "explanation": "helm history shows the revisions; helm rollback re-applies the chosen one. --atomic on upgrades does this automatically on failure." }
] }
```

## Extending Kubernetes: CRDs and operators

Kubernetes ships with built-in kinds: Pod, Deployment, Service, and so on. A **CustomResourceDefinition (CRD)** lets you add a brand new kind of your own, so the API server can store and serve objects that Kubernetes itself never shipped with. Once a CRD is installed, `kubectl get <your-new-kind>` works exactly like it does for a Pod.

A new kind by itself does nothing, it is just a place to store desired state. An **operator** is a controller (the same reconcile-loop idea from the basics lesson) written to watch objects of that custom kind and do the real work: create the underlying Deployments, Secrets, backups, or whatever the custom object describes.

Examples you will run into in real clusters:

- **cert-manager** adds a `Certificate` kind. You create a `Certificate` object saying "I want a TLS cert for shop.mindforge.test", and its operator requests, renews and stores the certificate for you.
- **Prometheus Operator** adds a `ServiceMonitor` kind. You create one pointing at your Service, and the operator wires Prometheus to scrape it, no manual Prometheus config editing.
- **CloudNativePG** adds a `Cluster` kind for PostgreSQL. You describe the Postgres cluster you want (replicas, storage size), and the operator creates the pods, handles failover and backups.

This is exactly why so many Helm charts install more than your app: a chart for cert-manager or a database often installs the CRDs **and** the operator together, so that after `helm install` you can just write a small custom-kind YAML file and the operator handles the rest. If `helm install` finishes but `kubectl get <customkind>` says `the server doesn't have a resource type`, the CRD did not get installed, usually because CRDs must be applied before the objects that use them, and some charts require a separate step for this (check the chart's README).

```knowledge-check
{ "questions": [
  { "id": "k8s-helm-crd-q1", "type": "mcq",
    "prompt": "What does a CustomResourceDefinition (CRD) add to a cluster?",
    "options": [
      {"id": "a", "text": "A new namespace"},
      {"id": "b", "text": "A brand new kind of object that the API server can store and serve, beyond the built-in kinds"},
      {"id": "c", "text": "A faster scheduler"},
      {"id": "d", "text": "A new node"}
    ],
    "correct": "b",
    "explanation": "A CRD registers a new kind with the API server. By itself it only defines the shape of the data; an operator does the actual work." },
  { "id": "k8s-helm-crd-q2", "type": "mcq",
    "prompt": "You create a CloudNativePG `Cluster` object describing a 3-node Postgres cluster. What actually creates the pods and manages failover?",
    "options": [
      {"id": "a", "text": "The kube-scheduler, automatically"},
      {"id": "b", "text": "The CloudNativePG operator, a controller watching Cluster objects and reconciling them"},
      {"id": "c", "text": "Helm, at install time only, with no further involvement"},
      {"id": "d", "text": "etcd, by reading the CRD schema"}
    ],
    "correct": "b",
    "explanation": "The CRD only defines the shape of the Cluster object. An operator is the controller that watches these objects and creates the real Deployments, Services, and backup jobs to match." }
] }
```

## Interview questions and real-world scenarios

**Q: What problems does Helm solve?**
Templating (one chart, many environments), packaging and sharing apps, and release management with history and rollback.

**Q: Chart vs release vs repository?**
Package, installed instance, and distribution location (HTTP repo or OCI registry).

**Q: How do you manage different values per environment?**
Base `values.yaml` in the chart, plus `values-dev.yaml` / `values-prod.yaml` in Git passed with `-f`; secrets from a secret manager, not values files.

**Q: Helm vs Kustomize?**
Helm uses templates and has release tracking; Kustomize patches plain YAML with overlays and is built into kubectl. Helm is dominant for third-party software; both are common for in-house apps, often driven by Argo CD or Flux.

**Q: How do you debug a chart that renders wrong YAML?**
`helm template` or `helm install --dry-run --debug`, `helm lint`, and `helm get manifest` / `helm get values` for installed releases.

**Real-world scenario: `helm upgrade` fails with "another operation (install/upgrade/rollback) is in progress".**
A previous upgrade was interrupted and the release is stuck in pending-upgrade. Check `helm history`, then `helm rollback` to the last deployed revision. Using `--atomic --timeout` in CI prevents half-finished releases.

**Real-world scenario: an upgrade removed a PVC and data was lost.**
The chart's PVC template was renamed or removed. Review `helm diff upgrade` (helm-diff plugin) before upgrading, use `helm.sh/resource-policy: keep` on critical resources, and back up first.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-helm-int-q1",
      "type": "mcq",
      "prompt": "A Helm release is stuck in 'pending-upgrade' after a CI job was cancelled. What is the usual fix?",
      "options": [
        {
          "id": "a",
          "text": "Delete the cluster"
        },
        {
          "id": "b",
          "text": "Check helm history and helm rollback to the last deployed revision"
        },
        {
          "id": "c",
          "text": "Run helm repo update"
        },
        {
          "id": "d",
          "text": "Delete all Secrets in the namespace"
        }
      ],
      "correct": "b",
      "explanation": "Rolling back clears the pending state; --atomic on future upgrades prevents it."
    }
  ]
}
```
