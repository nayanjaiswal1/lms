---
kind: lesson
id_key: k8s/reference/lesson
course: fast-kubernetes
section: reference
section_title: Cheat Sheet
section_position: 11
title: kubectl and Helm Cheat Sheet
position: 0
estimated_minutes: 20
source:
  - KubernetesCommandCheatSheet.md
  - HelmCheatsheet.md
---

A one-page reference of the commands used in this course, grouped by task. Keep it open while you work.

## Cluster, contexts and help

```bash
kubectl version                          # client and server versions
kubectl cluster-info                     # API server address
kubectl get nodes -o wide
kubectl api-resources                    # every kind + short name + namespaced?
kubectl explain deployment.spec.strategy # documentation for any field
kubectl config get-contexts              # which clusters you can talk to
kubectl config use-context <name>        # switch cluster
kubectl config set-context --current --namespace=<ns>   # default namespace
```

Handy shell setup:

```bash
alias k=kubectl
source <(kubectl completion bash)        # tab completion (zsh: kubectl completion zsh)
complete -o default -F __start_kubectl k
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-cluster-q1", "type": "mcq",
    "prompt": "You forgot which fields a Deployment's rolling update supports. Which command shows the documentation inside the terminal?",
    "options": [
      {"id": "a", "text": "kubectl explain deployment.spec.strategy.rollingUpdate"},
      {"id": "b", "text": "kubectl describe deployment --help-fields"},
      {"id": "c", "text": "kubectl api-resources deployment"},
      {"id": "d", "text": "kubectl get deployment -o docs"}
    ],
    "correct": "a",
    "explanation": "kubectl explain reads the schema from the cluster itself, so it always matches your cluster's version." }
] }
```

## Viewing and finding things

```bash
kubectl get pods                         # current namespace
kubectl get pods -A                      # all namespaces
kubectl get pods -o wide                 # + IP and node
kubectl get pods -l app=web              # by label
kubectl get pods --field-selector status.phase=Pending
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get pod web -o yaml              # the full object
kubectl get pod web -o jsonpath='{.status.podIP}'
kubectl get deploy,svc,ingress -n shop
kubectl describe pod web                 # details + Events
kubectl get events -A --sort-by=.lastTimestamp
kubectl get pods -w                      # watch live
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-view-q1", "type": "mcq",
    "prompt": "Which command prints only the IP address of pod web?",
    "options": [
      {"id": "a", "text": "kubectl get pod web -o jsonpath='{.status.podIP}'"},
      {"id": "b", "text": "kubectl describe pod web --ip"},
      {"id": "c", "text": "kubectl get pod web --ip-only"},
      {"id": "d", "text": "kubectl logs web --ip"}
    ],
    "correct": "a",
    "explanation": "jsonpath extracts any field from the object. It is ideal for scripts." }
] }
```

## Creating, changing and deleting

```bash
kubectl apply -f file.yaml               # create or update (declarative)
kubectl apply -f ./manifests/            # a whole folder
kubectl apply -k ./overlays/prod         # Kustomize
kubectl diff -f file.yaml                # what would change?
kubectl create deployment web --image=nginx:1.27 --replicas=3
kubectl create deployment web --image=nginx:1.27 --dry-run=client -o yaml > web.yaml
kubectl run tmp --rm -it --image=busybox:1.36 -- sh     # throwaway debug pod
kubectl expose deployment web --port=80 --type=ClusterIP
kubectl edit deployment web
kubectl label pod web env=prod           # add label   (env- removes it)
kubectl annotate pod web note="hello"
kubectl delete -f file.yaml
kubectl delete pod web
kubectl delete pods -l app=web
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-change-q1", "type": "mcq",
    "prompt": "Before applying a changed manifest to production, which command shows exactly what would change?",
    "options": [
      {"id": "a", "text": "kubectl diff -f file.yaml"},
      {"id": "b", "text": "kubectl apply --preview"},
      {"id": "c", "text": "kubectl describe -f file.yaml"},
      {"id": "d", "text": "kubectl get -f file.yaml -w"}
    ],
    "correct": "a",
    "explanation": "kubectl diff compares the file with the live object on the server." }
] }
```

## Deployments, scaling and rollouts

```bash
kubectl scale deployment web --replicas=5
kubectl autoscale deployment web --cpu-percent=60 --min=2 --max=10
kubectl set image deployment/web nginx=nginx:1.27.1
kubectl set resources deployment web -c nginx --requests=cpu=100m,memory=128Mi --limits=memory=256Mi
kubectl rollout status deployment/web
kubectl rollout history deployment/web
kubectl rollout undo deployment/web [--to-revision=2]
kubectl rollout pause|resume deployment/web
kubectl rollout restart deployment/web
kubectl create job manual --from=cronjob/backup
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-rollout-q1", "type": "mcq",
    "prompt": "Which command replaces all pods of a Deployment with fresh ones without changing its spec?",
    "options": [
      {"id": "a", "text": "kubectl rollout restart deployment/web"},
      {"id": "b", "text": "kubectl rollout undo deployment/web"},
      {"id": "c", "text": "kubectl scale deployment/web --replicas=0"},
      {"id": "d", "text": "kubectl delete deployment web"}
    ],
    "correct": "a",
    "explanation": "rollout restart triggers a normal rolling update with the same template, with no downtime." }
] }
```

## Debugging

```bash
kubectl logs web [-c container] [-f] [--previous] [--since=10m]
kubectl logs -l app=web --all-containers --prefix
kubectl exec -it web -- sh
kubectl exec web -- env
kubectl port-forward pod/web 8080:80
kubectl port-forward svc/web 8080:80
kubectl cp web:/tmp/dump.txt ./dump.txt
kubectl debug -it web --image=busybox:1.36 --target=web     # ephemeral debug container
kubectl debug node/worker1 -it --image=busybox:1.36          # shell on a node
kubectl top nodes / kubectl top pods -A
kubectl get endpoints web                                    # does the Service have pods?
kubectl auth can-i delete pods --as=jane -n dev
```

`kubectl debug` adds a temporary container with tools to a running pod. It is perfect for minimal ("distroless") images that have no shell.

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-debug-q1", "type": "mcq",
    "prompt": "A pod uses a distroless image with no shell, so `kubectl exec -it pod -- sh` fails. How can you still investigate inside it?",
    "options": [
      {"id": "a", "text": "kubectl debug -it <pod> --image=busybox:1.36 --target=<container>"},
      {"id": "b", "text": "Rebuild the image with bash"},
      {"id": "c", "text": "kubectl logs --shell"},
      {"id": "d", "text": "It is impossible"}
    ],
    "correct": "a",
    "explanation": "An ephemeral debug container shares the pod's namespaces and brings its own tools." }
] }
```

## Nodes and cluster maintenance

```bash
kubectl cordon node1 / kubectl uncordon node1
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data
kubectl taint node node1 key=value:NoSchedule      # key- removes it
kubectl label node node1 disktype=ssd
kubectl delete node node1
kubeadm token create --print-join-command
kubeadm certs check-expiration
kubeadm upgrade plan
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-nodes-q1", "type": "mcq",
    "prompt": "Which command removes the taint with key gpu from node1?",
    "options": [
      {"id": "a", "text": "kubectl taint node node1 gpu-"},
      {"id": "b", "text": "kubectl untaint node1 gpu"},
      {"id": "c", "text": "kubectl label node node1 gpu-"},
      {"id": "d", "text": "kubectl taint node node1 --delete gpu"}
    ],
    "correct": "a",
    "explanation": "A trailing minus removes taints (and labels) with that key." }
] }
```

## Helm

```bash
helm repo add <name> <url> && helm repo update
helm search repo <keyword> / helm search hub <keyword>
helm show values <chart>
helm install <release> <chart> -n <ns> --create-namespace -f values.yaml
helm upgrade --install <release> <chart> -f values.yaml --atomic --wait
helm list -A
helm status <release>
helm history <release>
helm rollback <release> <revision>
helm get values <release> [--all]
helm get manifest <release>
helm template <release> <chart> -f values.yaml
helm lint <chart-dir>
helm uninstall <release>
helm create <name> / helm package <chart-dir> / helm dependency update <chart-dir>
```

```knowledge-check
{ "questions": [
  { "id": "k8s-ref-helm-q1", "type": "mcq",
    "prompt": "Which command shows the values you supplied when a release was installed or last upgraded?",
    "options": [
      {"id": "a", "text": "helm get values <release>"},
      {"id": "b", "text": "helm show values <release>"},
      {"id": "c", "text": "helm history <release>"},
      {"id": "d", "text": "helm lint <release>"}
    ],
    "correct": "a",
    "explanation": "helm get values reads the release; helm show values reads a chart's defaults." }
] }
```
