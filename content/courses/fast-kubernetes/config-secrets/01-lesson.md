---
kind: lesson
id_key: k8s/config-secrets/lesson
course: fast-kubernetes
section: config-secrets
section_title: ConfigMaps & Secrets
section_position: 5
title: ConfigMaps and Secrets
position: 0
estimated_minutes: 40
source:
  - K8s-Configmap.md
  - K8s-Secret.md
---

The same image should run in development, staging and production. What changes between them is **configuration**: database hosts, feature settings, API keys, passwords. Kubernetes keeps these outside the image in two kinds of objects: **ConfigMaps** for normal settings and **Secrets** for sensitive values.

## Why configuration lives outside the image

If you bake a database host into the image, you need a new image for each environment, and a password inside an image can be read by anyone who can pull it. The rule (from the "twelve-factor app" guidelines) is: **build one image, inject config at runtime.**

Kubernetes injects config into a pod in two ways:

1. As **environment variables**.
2. As **files** in a mounted volume.

Both ConfigMaps and Secrets support both ways.

```knowledge-check
{ "questions": [
  { "id": "k8s-cfg-why-q1", "type": "mcq",
    "prompt": "Why keep the database hostname out of the container image?",
    "options": [
      {"id": "a", "text": "Images cannot contain text"},
      {"id": "b", "text": "So the same image can run in every environment with different settings injected at runtime"},
      {"id": "c", "text": "Kubernetes deletes environment variables from images"},
      {"id": "d", "text": "It makes the image build faster"}
    ],
    "correct": "b",
    "explanation": "One image, many environments. Config is supplied by ConfigMaps and Secrets when the pod starts." }
] }
```

## Creating a ConfigMap

Think of a notice board in a society lobby versus a locked drawer in the watchman's cabin. Anyone walking past can read the notice board, that is a ConfigMap: plain settings nobody minds being seen. The locked drawer holds things you would rather only a few people saw, that is a Secret, though as you will see below, the lock is weaker than it sounds.

A **ConfigMap** stores key-value pairs. A value can be a short string or the whole content of a file.

From YAML:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myconfigmap
data:
  db_server: "db.mindforge.test"      # simple values
  database: "mydatabase"
  site.settings: |                 # a whole file as one value
    color=blue
    padding:25px
```

From the command line:

```bash
kubectl create configmap myconfigmap2 \
  --from-literal=background=red \
  --from-file=theme.txt              # key = file name, value = file content
kubectl create configmap nginx-conf --from-file=nginx.conf --from-env-file=app.env

kubectl get configmaps
kubectl describe configmap myconfigmap
kubectl get configmap myconfigmap -o yaml
```

`--from-file=theme.txt` creates the key `theme.txt`. Use `--from-file=mykey=theme.txt` to choose the key name. A ConfigMap can hold at most 1 MiB. It is for configuration, not data.

```knowledge-check
{ "questions": [
  { "id": "k8s-cfg-create-q1", "type": "mcq",
    "prompt": "`kubectl create configmap app --from-file=settings.ini` creates which key?",
    "options": [
      {"id": "a", "text": "app"},
      {"id": "b", "text": "settings.ini, with the file content as its value"},
      {"id": "c", "text": "One key per line of the file"},
      {"id": "d", "text": "data"}
    ],
    "correct": "b",
    "explanation": "--from-file uses the file name as the key and the whole file as the value, unless you write --from-file=<key>=<file>." }
] }
```

## Using a ConfigMap in a pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmappod
spec:
  containers:
  - name: app
    image: nginx:1.27
    env:
    - name: DB_SERVER                # one variable from one key
      valueFrom:
        configMapKeyRef:
          name: myconfigmap
          key: db_server
    envFrom:                         # every key becomes a variable
    - configMapRef:
        name: myconfigmap2
    volumeMounts:
    - name: config-vol
      mountPath: /config             # each key becomes a file in /config
      readOnly: true
  volumes:
  - name: config-vol
    configMap:
      name: myconfigmap
```

Inside the container, `echo $DB_SERVER` prints `db.mindforge.test`, and `cat /config/site.settings` prints the settings file.

**What happens when the ConfigMap changes?**

- **Environment variables do not change** in a running container. They are read once at start. Restart the pods (`kubectl rollout restart deployment/<name>`).
- **Mounted files are updated** automatically after a short delay (up to about a minute). The app must re-read the file to notice.
- Files mounted with `subPath` are **not** updated.

If the ConfigMap (or a key) does not exist, the pod will not start (`CreateContainerConfigError`), unless you mark the reference `optional: true`.

```knowledge-check
{ "questions": [
  { "id": "k8s-cfg-use-q1", "type": "mcq",
    "prompt": "You update a ConfigMap that a running pod uses as environment variables. What does the app see?",
    "options": [
      {"id": "a", "text": "The new values immediately"},
      {"id": "b", "text": "The old values, until the container is restarted"},
      {"id": "c", "text": "Empty values"},
      {"id": "d", "text": "The pod crashes"}
    ],
    "correct": "b",
    "explanation": "Environment variables are fixed when the container starts. Mounted files update after a delay; env vars need a restart." },
  { "id": "k8s-cfg-use-q2", "type": "mcq",
    "prompt": "Which field loads every key of a ConfigMap as environment variables at once?",
    "options": [
      {"id": "a", "text": "env[].valueFrom.configMapKeyRef"},
      {"id": "b", "text": "envFrom[].configMapRef"},
      {"id": "c", "text": "volumes[].configMap"},
      {"id": "d", "text": "spec.configMap"}
    ],
    "correct": "b",
    "explanation": "envFrom imports all keys. valueFrom.configMapKeyRef picks one key for one variable." }
] }
```

## Secrets

A **Secret** works like a ConfigMap but is meant for sensitive values: passwords, tokens, keys, certificates.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque                   # generic key-value secret
stringData:                    # plain text here; Kubernetes stores it base64-encoded
  db_server: db.mindforge.test
  db_username: admin
  db_password: P@ssw0rd!
```

- `stringData` accepts plain text (easier to write).
- `data` requires **base64-encoded** values: `echo -n 'admin' | base64` → `YWRtaW4=`. The `-n` matters; without it you encode a newline too.

From the command line:

```bash
kubectl create secret generic mysecret2 \
  --from-literal=db_username=admin \
  --from-literal=db_password='P@ssw0rd!'

# from files, so the password never appears in your shell history
kubectl create secret generic mysecret3 \
  --from-file=db_username=username.txt \
  --from-file=db_password=password.txt

kubectl get secrets
kubectl describe secret mysecret        # shows keys and sizes, not the values
kubectl get secret mysecret -o jsonpath='{.data.db_password}' | base64 -d
```

Other Secret types you will meet:

| Type | Used for |
|---|---|
| `Opaque` | Any key-value data (default) |
| `kubernetes.io/tls` | A TLS certificate and key (`kubectl create secret tls`), used by Ingress |
| `kubernetes.io/dockerconfigjson` | Registry login for pulling private images (`kubectl create secret docker-registry`), used via `imagePullSecrets` |

```knowledge-check
{ "questions": [
  { "id": "k8s-cfg-secret-q1", "type": "mcq",
    "prompt": "What is the difference between `data` and `stringData` in a Secret manifest?",
    "options": [
      {"id": "a", "text": "data is encrypted; stringData is not"},
      {"id": "b", "text": "data takes base64-encoded values; stringData takes plain text that Kubernetes encodes for you"},
      {"id": "c", "text": "stringData is only for TLS secrets"},
      {"id": "d", "text": "There is no difference"}
    ],
    "correct": "b",
    "explanation": "Both end up stored as base64 in data. stringData is just a convenience for writing plain text." }
] }
```

## Using Secrets in a pod

Exactly like ConfigMaps, with `secretKeyRef`, `secretRef` and `secret` volumes:

```yaml
spec:
  containers:
  - name: app
    image: nginx:1.27
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: mysecret
          key: db_password
    envFrom:
    - secretRef:
        name: mysecret             # every key as a variable
    volumeMounts:
    - name: secret-vol
      mountPath: /secret           # each key becomes a file, e.g. /secret/db_password
      readOnly: true
  volumes:
  - name: secret-vol
    secret:
      secretName: mysecret
```

Mounting secrets as **files** is often safer than environment variables. Environment variables are easy to leak: they show up in crash dumps, debug pages, and child processes, and some logging tools print them.

```knowledge-check
{ "questions": [
  { "id": "k8s-cfg-usesecret-q1", "type": "mcq",
    "prompt": "A Secret mysecret with key api_key is mounted as a volume at /etc/creds. Where does the app find the value?",
    "options": [
      {"id": "a", "text": "In the environment variable API_KEY"},
      {"id": "b", "text": "In the file /etc/creds/api_key"},
      {"id": "c", "text": "In /etc/creds/mysecret.json"},
      {"id": "d", "text": "In /var/run/secrets/api_key"}
    ],
    "correct": "b",
    "explanation": "Each key of a mounted Secret (or ConfigMap) becomes a file named after the key inside the mount path." }
] }
```

## Keeping Secrets actually secret

**base64 is encoding, not encryption.** Anyone who can read the Secret object can decode it in one command. By default, Secrets are also stored unencrypted in etcd. Protect them properly:

- **Limit access with RBAC.** Only the people and service accounts that need a Secret should be allowed to `get` or `list` Secrets in that namespace. (RBAC is covered in the cluster operations lesson.)
- **Enable encryption at rest** for Secrets in etcd (managed clouds usually offer this, often with a cloud KMS key).
- **Never commit Secret manifests with real values to Git.** Use **Sealed Secrets** (encrypted files that only the cluster can decrypt), **SOPS**, or the **External Secrets Operator**, which syncs values from a vault such as AWS Secrets Manager, Azure Key Vault or HashiCorp Vault.
- Mark Secrets and ConfigMaps that should never change as `immutable: true`. That protects them from accidental edits and reduces load on the API server.

```knowledge-check
{ "questions": [
  { "id": "k8s-cfg-safe-q1", "type": "mcq",
    "prompt": "A teammate says: 'Our passwords are safe in Git because the Secret YAML is base64-encoded.' What is wrong with that?",
    "options": [
      {"id": "a", "text": "Nothing; base64 is strong encryption"},
      {"id": "b", "text": "base64 is only encoding; anyone can decode it, so real secrets must not be committed in plain Secret manifests"},
      {"id": "c", "text": "Git cannot store base64 text"},
      {"id": "d", "text": "Kubernetes rejects base64 values"}
    ],
    "correct": "b",
    "explanation": "`base64 -d` reverses it instantly. Use Sealed Secrets, SOPS or an external secret manager, and restrict access with RBAC." }
] }
```

## Interview questions and real-world scenarios

**Q: How do you pass configuration to a pod?**
ConfigMaps and Secrets, as env vars (`env`/`envFrom`) or as mounted files. Plus the Downward API for pod metadata (name, namespace, labels, resource limits).

**Q: Are Kubernetes Secrets secure?**
Not by default: base64 only, readable by anyone with `get secrets`, and unencrypted in etcd unless encryption at rest is enabled. Make them secure with RBAC, KMS encryption, external secret stores and file mounts.

**Q: How do pods pick up a changed ConfigMap?**
Mounted files update after a delay (not with subPath); env vars need a restart. A common pattern is to put a hash of the config in a pod-template annotation (Helm's `checksum/config`) so any config change triggers a rollout automatically.

**Q: What is an immutable ConfigMap/Secret?**
`immutable: true` prevents changes, protects against accidental edits, and reduces API server watch load. To change it, create a new one with a new name and point the Deployment at it.

**Q: How do you pull images from a private registry?**
A `kubernetes.io/dockerconfigjson` Secret referenced in `imagePullSecrets` (or attached to the ServiceAccount). On clouds, node IAM roles or workload identity often replace stored credentials.

**Real-world scenario: after rotating a database password, half the pods fail to connect.**
Pods read the password as an env var at startup. Some restarted and got the new one, others still use the old one, which the database no longer accepts. Rotate safely: let the DB accept both passwords briefly, roll out a restart, then remove the old one. Mounted files plus apps that re-read them avoid restarts.

**Real-world scenario: a pod is stuck in CreateContainerConfigError after a deploy.**
The new version references a ConfigMap key or Secret that was not created in that environment. Create it, or ship config and code together (Helm/Kustomize) so they cannot drift.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-cfg-int-q1",
      "type": "mcq",
      "prompt": "How can Helm make a Deployment roll out automatically whenever its ConfigMap changes?",
      "options": [
        {
          "id": "a",
          "text": "It cannot"
        },
        {
          "id": "b",
          "text": "Put a checksum of the rendered ConfigMap in a pod-template annotation, so a config change changes the template"
        },
        {
          "id": "c",
          "text": "Use envFrom instead of env"
        },
        {
          "id": "d",
          "text": "Mark the ConfigMap immutable"
        }
      ],
      "correct": "b",
      "explanation": "Any change to the pod template triggers a rolling update; the checksum annotation ties the template to the config content."
    }
  ]
}
```
