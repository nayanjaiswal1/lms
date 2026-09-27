---
kind: lesson
id_key: k8s/cluster-ops/lesson-security
course: fast-kubernetes
section: cluster-ops
section_title: 'Real Clusters: Setup, Security and Operations'
section_position: 10
title: Security with RBAC, ServiceAccounts and Pod Security
position: 1
estimated_minutes: 45
source:
  - README.md
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
    - id_key: namespace-and-sa
      title: Create a namespace and a ServiceAccount
      points: 10
      is_stateful: true
      description: Create the namespace `team-a` and, inside it, a ServiceAccount named `ci-bot`.
      verification_script: |
        #!/bin/bash
        kubectl get serviceaccount ci-bot -n team-a >/dev/null 2>&1
      hint_context: "`kubectl create namespace ...` then `kubectl create serviceaccount <name> -n <namespace>`"
      explanation_context: A ServiceAccount is an identity for software (a CI pipeline, an operator, a pod), just as a user account is an identity for a person.
      solution_script: |
        kubectl create namespace team-a
        kubectl create serviceaccount ci-bot -n team-a
    - id_key: create-role
      title: Create a Role
      points: 15
      is_stateful: true
      description: In `team-a`, create a Role named `deployer` that can `get`, `list`, `watch`, `create`, `update` and `patch` **deployments** (API group `apps`), and only `get`, `list`, `watch` **pods**.
      verification_script: |
        #!/bin/bash
        R=$(kubectl get role deployer -n team-a -o jsonpath='{range .rules[*]}{.resources[*]}:{.verbs[*]}{"\n"}{end}')
        echo "$R" | grep -q '^deployments:.*create' || exit 1
        echo "$R" | grep -q '^deployments:.*patch' || exit 1
        P=$(echo "$R" | grep '^pods:') || exit 1
        echo "$P" | grep -q list && ! echo "$P" | grep -qE 'create|delete|update|patch'
      hint_context: "Two `kubectl create role` rules are easiest in YAML: `rules:` with one entry for `apiGroups: [\"apps\"]`/`resources: [\"deployments\"]` and one for `apiGroups: [\"\"]`/`resources: [\"pods\"]`."
      explanation_context: Rules list API groups, resources and verbs. Core objects such as pods are in the empty API group "". Anything not listed is denied, because RBAC only grants, never denies.
      solution_script: |
        cat > /home/labuser/work/role.yaml <<'Y'
        apiVersion: rbac.authorization.k8s.io/v1
        kind: Role
        metadata:
          name: deployer
          namespace: team-a
        rules:
        - apiGroups: ["apps"]
          resources: ["deployments"]
          verbs: ["get", "list", "watch", "create", "update", "patch"]
        - apiGroups: [""]
          resources: ["pods"]
          verbs: ["get", "list", "watch"]
        Y
        kubectl apply -f /home/labuser/work/role.yaml
    - id_key: bind-role
      title: Bind the Role to the ServiceAccount
      points: 15
      is_stateful: true
      description: Create a RoleBinding named `ci-bot-deployer` in `team-a` that gives the Role `deployer` to the ServiceAccount `team-a:ci-bot`.
      verification_script: |
        #!/bin/bash
        test "$(kubectl get rolebinding ci-bot-deployer -n team-a -o jsonpath='{.roleRef.kind}/{.roleRef.name} {.subjects[0].kind}/{.subjects[0].namespace}/{.subjects[0].name}')" = "Role/deployer ServiceAccount/team-a/ci-bot"
      hint_context: "`kubectl create rolebinding <name> --role=<role> --serviceaccount=<namespace>:<sa> -n <namespace>`"
      explanation_context: "On a normal cluster you could now check with `kubectl auth can-i create deployments -n team-a --as=system:serviceaccount:team-a:ci-bot` (yes) and `... delete pods ...` (no). This sandbox's API server runs with authorization turned off, so can-i always answers yes here."
      solution_script: kubectl create rolebinding ci-bot-deployer --role=deployer --serviceaccount=team-a:ci-bot -n team-a
    - id_key: enforce-restricted
      title: Enforce the restricted Pod Security Standard
      points: 15
      is_stateful: true
      description: |
        Label the namespace `team-a` with `pod-security.kubernetes.io/enforce=restricted`. Then try `kubectl run root-pod --image=nginx:1.27 -n team-a` and read the error. The pod is rejected.
      verification_script: |
        #!/bin/bash
        test "$(kubectl get ns team-a -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" = "restricted" || exit 1
        ! kubectl get pod root-pod -n team-a >/dev/null 2>&1
      hint_context: "`kubectl label namespace team-a pod-security.kubernetes.io/enforce=restricted`"
      explanation_context: Pod Security Admission checks every new pod in the namespace. A plain nginx pod may run as root, allows privilege escalation and keeps default capabilities, so the restricted level rejects it.
      solution_script: |
        kubectl label namespace team-a pod-security.kubernetes.io/enforce=restricted
        kubectl run root-pod --image=nginx:1.27 -n team-a || true
    - id_key: secure-pod
      title: Write a pod that passes the restricted policy
      points: 20
      is_stateful: false
      description: |
        Create a pod `safe-pod` in `team-a` (image `nginxinc/nginx-unprivileged:1.27`) that is accepted by the restricted policy. It must:
        - run as non-root (`runAsNonRoot: true`, `runAsUser: 101`)
        - use `seccompProfile.type: RuntimeDefault`
        - set `allowPrivilegeEscalation: false`
        - drop `ALL` capabilities
      verification_script: |
        #!/bin/bash
        kubectl get pod safe-pod -n team-a >/dev/null 2>&1 || exit 1
        test "$(kubectl get pod safe-pod -n team-a -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}')" = "false"
      hint_context: "Pod-level `securityContext` takes runAsNonRoot, runAsUser and seccompProfile. The container-level `securityContext` takes allowPrivilegeEscalation and `capabilities: {drop: [\"ALL\"]}`."
      explanation_context: These settings mean that even if the app is hacked, the attacker is not root, cannot gain more privileges, and has no special kernel capabilities. They are good defaults for every production pod.
      solution_script: |
        cat > /home/labuser/work/safe-pod.yaml <<'Y'
        apiVersion: v1
        kind: Pod
        metadata:
          name: safe-pod
          namespace: team-a
        spec:
          securityContext:
            runAsNonRoot: true
            runAsUser: 101
            seccompProfile:
              type: RuntimeDefault
          containers:
          - name: web
            image: nginxinc/nginx-unprivileged:1.27
            securityContext:
              allowPrivilegeEscalation: false
              capabilities:
                drop: ["ALL"]
        Y
        kubectl apply -f /home/labuser/work/safe-pod.yaml
---

A cluster runs many teams' apps and holds their secrets, so access must be controlled carefully. This lesson covers the three security basics everyone working with Kubernetes needs: **who can do what** (authentication and RBAC), **what identity pods use** (ServiceAccounts), and **what pods are allowed to do on the node** (security contexts and Pod Security Standards).

## Authentication vs authorization

Every request to the API server goes through two checks, then admission:

1. **Authentication: who are you?** Kubernetes has no user database. People are identified by client certificates, tokens, or (most commonly in companies) an **OIDC** identity provider such as Azure AD/Entra ID, Google, Okta or Keycloak. Programs use **ServiceAccount** tokens.
2. **Authorization: are you allowed to do this?** Almost every cluster uses **RBAC** (role-based access control).
3. **Admission: is this object acceptable?** Admission controllers can reject or modify objects (for example Pod Security Admission, or policy engines such as Kyverno and OPA Gatekeeper).

```knowledge-check
{ "questions": [
  { "id": "k8s-sec-authn-q1", "type": "mcq",
    "prompt": "Where does Kubernetes store its list of human users?",
    "options": [
      {"id": "a", "text": "In etcd under /users"},
      {"id": "b", "text": "Nowhere; users come from external identity (certificates, tokens, OIDC), and only ServiceAccounts are Kubernetes objects"},
      {"id": "c", "text": "In a ConfigMap in kube-system"},
      {"id": "d", "text": "In the kubelet"}
    ],
    "correct": "b",
    "explanation": "Kubernetes trusts external identity for people. ServiceAccounts are the only identities it manages itself." }
] }
```

## RBAC: Roles and bindings

Think of an office ID card system. A **Role** is like the printed list of doors a certain type of card can open (server room, accounts, cafeteria). Giving that actual card to a person is the **RoleBinding**. The card only works in this one office building; a **ClusterRole** and **ClusterRoleBinding** are the same idea for a card that works across every branch office. RBAC has four object kinds:

| Object | Scope | Purpose |
|---|---|---|
| **Role** | One namespace | A set of permissions (verbs on resources) |
| **ClusterRole** | Whole cluster | Same, for cluster-wide resources (nodes, PVs) or for reuse in many namespaces |
| **RoleBinding** | One namespace | Gives a Role (or a ClusterRole) to subjects **in that namespace** |
| **ClusterRoleBinding** | Whole cluster | Gives a ClusterRole to subjects **everywhere** |

A Role:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: team-a
rules:
- apiGroups: [""]              # "" = core group (pods, services, configmaps, secrets)
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
```

Give it to a user, a group and a ServiceAccount:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: team-a
subjects:
- kind: User
  name: jane@example.com
- kind: Group
  name: team-a-devs
- kind: ServiceAccount
  name: ci-bot
  namespace: team-a
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Rules to remember:

- RBAC is **additive only**: there is no "deny" rule. Anything not granted is forbidden.
- Follow **least privilege**. Avoid giving `cluster-admin`, and be careful with `*` verbs, `secrets` access, and `pods/exec` (which lets someone run commands inside containers).
- Built-in ClusterRoles `view`, `edit`, `admin` and `cluster-admin` cover common needs. Bind `edit` in a namespace with a RoleBinding to give a team full control of their own namespace only.

Test permissions with `can-i`:

```bash
kubectl auth can-i create deployments -n team-a
kubectl auth can-i delete pods -n team-a --as=jane@example.com
kubectl auth can-i --list -n team-a --as=system:serviceaccount:team-a:ci-bot
```

[[lab-task:1]]

[[lab-task:2]]

[[lab-task:3]]

```knowledge-check
{ "questions": [
  { "id": "k8s-sec-rbac-q1", "type": "mcq",
    "prompt": "You bind the built-in ClusterRole `edit` to a team using a RoleBinding in namespace `team-a`. Where can the team edit objects?",
    "options": [
      {"id": "a", "text": "In every namespace"},
      {"id": "b", "text": "Only in team-a"},
      {"id": "c", "text": "Nowhere; a ClusterRole needs a ClusterRoleBinding"},
      {"id": "d", "text": "Only on cluster-wide resources"}
    ],
    "correct": "b",
    "explanation": "A RoleBinding limits the granted permissions to its own namespace, even when it references a ClusterRole." },
  { "id": "k8s-sec-rbac-q2", "type": "mcq",
    "prompt": "How do you forbid a user from deleting Secrets in RBAC?",
    "options": [
      {"id": "a", "text": "Add a rule with verb deny"},
      {"id": "b", "text": "Simply do not grant that permission in any Role or ClusterRole bound to them"},
      {"id": "c", "text": "Add a negative RoleBinding"},
      {"id": "d", "text": "Label the Secret protected=true"}
    ],
    "correct": "b",
    "explanation": "RBAC only grants. Everything not granted is denied by default." }
] }
```

## ServiceAccounts: identities for pods

Every pod runs as a **ServiceAccount** (the `default` one in its namespace unless you set `serviceAccountName`). Its token is mounted into the pod at `/var/run/secrets/kubernetes.io/serviceaccount/`, so code inside the pod can call the Kubernetes API with that identity. Tools such as CI runners, operators and Argo CD use this.

```yaml
spec:
  serviceAccountName: ci-bot
  automountServiceAccountToken: true    # set false for pods that never call the API
```

Good practice:

- Create one ServiceAccount per app that needs API access, and bind only the permissions it needs.
- Set `automountServiceAccountToken: false` for apps that never talk to the Kubernetes API. That way a stolen token cannot be misused.
- Tokens are short-lived and rotated automatically (projected tokens). Get one for testing with `kubectl create token ci-bot -n team-a`.
- On clouds, ServiceAccounts can be mapped to cloud IAM roles (IRSA / EKS Pod Identity on AWS, Workload Identity on GKE/AKS), so pods get cloud permissions without stored keys.

```knowledge-check
{ "questions": [
  { "id": "k8s-sec-sa-q1", "type": "mcq",
    "prompt": "Which identity does a pod use to call the Kubernetes API if you don't specify one?",
    "options": [
      {"id": "a", "text": "cluster-admin"},
      {"id": "b", "text": "The `default` ServiceAccount of its namespace"},
      {"id": "c", "text": "The user who created the pod"},
      {"id": "d", "text": "It cannot call the API"}
    ],
    "correct": "b",
    "explanation": "Pods default to the namespace's `default` ServiceAccount, which has no extra permissions unless someone binds them." }
] }
```

## Security context: what a container may do

By default many images run as **root**. If an attacker breaks into such a container, they are root inside it, which makes escaping to the node easier. `securityContext` tightens this:

```yaml
spec:
  securityContext:                 # pod level
    runAsNonRoot: true             # refuse to start if the image would run as root
    runAsUser: 1000
    fsGroup: 2000                  # group owner for mounted volumes
    seccompProfile:
      type: RuntimeDefault         # block dangerous system calls
  containers:
  - name: app
    image: myapp:1.0
    securityContext:               # container level
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true # app can only write to mounted volumes
      capabilities:
        drop: ["ALL"]              # remove all special kernel powers
```

Never use `privileged: true`, `hostNetwork`, `hostPID` or broad `hostPath` mounts for normal apps. They remove most of the isolation between the container and the node.

```knowledge-check
{ "questions": [
  { "id": "k8s-sec-ctx-q1", "type": "mcq",
    "prompt": "What does `readOnlyRootFilesystem: true` do?",
    "options": [
      {"id": "a", "text": "Makes all volumes read-only"},
      {"id": "b", "text": "Prevents the container from writing to its image filesystem; it can still write to mounted volumes such as an emptyDir"},
      {"id": "c", "text": "Makes the image smaller"},
      {"id": "d", "text": "Blocks network access"}
    ],
    "correct": "b",
    "explanation": "Attackers cannot drop tools or change binaries in the image. Give the app an emptyDir for temp files if it needs one." }
] }
```

## Pod Security Standards and admission

Kubernetes defines three **Pod Security Standards**:

- **privileged**: no restrictions (for system components).
- **baseline**: blocks the obviously dangerous settings (privileged, host namespaces...).
- **restricted**: also requires non-root, dropped capabilities, seccomp and no privilege escalation. Best practice for apps.

The built-in **Pod Security Admission** controller enforces them per namespace, using labels:

```bash
kubectl label namespace team-a \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted
```

- `enforce` rejects violating pods.
- `warn` only prints a warning (good for trying a level first).
- `audit` records violations in the audit log.

For rules beyond this (allowed registries, required labels, resource limits present), teams use **Kyverno** or **OPA Gatekeeper**.

[[lab-task:4]]

[[lab-task:5]]

```knowledge-check
{ "questions": [
  { "id": "k8s-sec-psa-q1", "type": "mcq",
    "prompt": "A namespace has pod-security.kubernetes.io/enforce=restricted. A Deployment's pods run as root. What happens?",
    "options": [
      {"id": "a", "text": "The pods run with a warning"},
      {"id": "b", "text": "The pods are rejected, so the ReplicaSet cannot create them"},
      {"id": "c", "text": "Kubernetes changes the user to non-root automatically"},
      {"id": "d", "text": "The whole namespace is deleted"}
    ],
    "correct": "b",
    "explanation": "enforce rejects non-compliant pods. The Deployment is accepted but its ReplicaSet reports FailedCreate events. Use warn mode first to find problems." }
] }
```

## Interview questions and real-world scenarios

**Q: Authentication vs authorization vs admission?**
Who are you (certs, tokens, OIDC)? Are you allowed (RBAC)? Is this object acceptable (admission controllers such as Pod Security, Kyverno, Gatekeeper)?

**Q: Role vs ClusterRole, RoleBinding vs ClusterRoleBinding?**
Namespaced vs cluster-wide permission sets; namespace-scoped vs cluster-wide grants. A RoleBinding can reference a ClusterRole to reuse it inside one namespace.

**Q: How do you give a pod access to a cloud service (for example S3) securely?**
Workload identity: map the pod's ServiceAccount to a cloud IAM role (IRSA / EKS Pod Identity, GKE/AKS Workload Identity) instead of storing access keys in Secrets.

**Q: What would you check in a Kubernetes security review?**
RBAC (no broad cluster-admin, no wildcard verbs, limited secrets/exec access), Pod Security (restricted), NetworkPolicies (default deny), image sources and scanning, secrets management, API server not public, audit logging, up-to-date versions.

**Q: Why is access to `pods/exec` or `create pods` dangerous?**
exec gives a shell inside containers with their secrets. Anyone who can create pods can mount any Secret in the namespace or (without Pod Security) run a privileged pod and take over a node.

**Real-world scenario: a developer needs to debug production.**
Give time-limited, read-only access (`view` role, logs) via SSO groups; for exec, use a just-in-time access process with audit logging, not permanent rights.

**Real-world scenario: after enabling `enforce=restricted`, a Deployment stops creating pods.**
The ReplicaSet shows FailedCreate events listing the violations. Fix the pod's securityContext (non-root, drop capabilities, seccomp); roll out policies with `warn` first to find these before enforcing.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-sec-int-q1",
      "type": "mcq",
      "prompt": "Why is permission to create pods in a namespace close to having access to all Secrets in that namespace?",
      "options": [
        {
          "id": "a",
          "text": "It is not related"
        },
        {
          "id": "b",
          "text": "A new pod can mount or read any Secret in its namespace as a volume or env var"
        },
        {
          "id": "c",
          "text": "Creating pods deletes Secrets"
        },
        {
          "id": "d",
          "text": "Pods are stored inside Secrets"
        }
      ],
      "correct": "b",
      "explanation": "RBAC on Secrets alone is not enough; pod creation rights must be treated as sensitive too."
    }
  ]
}
```
