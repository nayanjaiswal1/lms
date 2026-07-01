-- ════════════════════════════════════════════════════════════════════════════
-- k8s_12_lab5.sql — Lab 5: RBAC, Service Accounts & Pod Security
-- Module: 000000081002 (Master course, Section 1, Module 2)
-- 7 tasks, lab ID: 000000090005, version ID: 000000099005
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO lab_definitions (
  id, org_id, course_id, module_id, scope, title, description,
  lab_type, environment, setup_script,
  max_duration, max_resets, hint_penalty_pct, is_required, is_published,
  published_version_id, created_by
) VALUES (
  '00000000-0000-0000-0000-000000090005',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000080000',
  '00000000-0000-0000-0000-000000081002',
  'module',
  'RBAC, Service Accounts & Pod Security',
  'Implement least-privilege access control: create ServiceAccounts, Roles, RoleBindings, and ClusterRoles. Configure pod security contexts to run as non-root. Verify permissions with kubectl auth can-i.',
  'terminal', 'mindforge/lab-k8s:1.31',
  '#!/bin/bash
kubectl delete namespace rbac-lab --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create namespace rbac-lab >/dev/null 2>&1 || true',
  90, 3, 10, true, false, NULL,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
(
  '00000000-0000-0000-0000-000000095001',
  '00000000-0000-0000-0000-000000090005', 1,
  'Create a ServiceAccount for the application',
  'Create a ServiceAccount named `app-sa` in namespace `rbac-lab`. ServiceAccounts provide an identity for pods to authenticate to the Kubernetes API.',
  '#!/bin/bash
kubectl get serviceaccount app-sa -n rbac-lab >/dev/null 2>&1',
  'Use `kubectl create serviceaccount app-sa -n rbac-lab`.',
  'ServiceAccounts are namespace-scoped identities for pods. Each pod gets a default ServiceAccount if none is specified. The token is mounted at /var/run/secrets/kubernetes.io/serviceaccount/token and used to authenticate to the API server.',
  10, false, false
),
(
  '00000000-0000-0000-0000-000000095002',
  '00000000-0000-0000-0000-000000090005', 2,
  'Create a Role allowing pod read access',
  'Create a Role named `pod-reader` in namespace `rbac-lab` that grants **get, list, watch** permissions on **pods** and **pods/log** resources.',
  '#!/bin/bash
kubectl get role pod-reader -n rbac-lab >/dev/null 2>&1 && \
kubectl get role pod-reader -n rbac-lab \
  -o jsonpath=''{.rules[0].verbs}'' | grep -q list',
  'Use `kubectl create role pod-reader --verb=get,list,watch --resource=pods,pods/log -n rbac-lab`.',
  'Roles are namespace-scoped. Rules specify apiGroups (empty string for core), resources, and verbs. A Role with no binding has no effect — it must be bound to a subject via RoleBinding.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000095003',
  '00000000-0000-0000-0000-000000090005', 3,
  'Bind the Role to the ServiceAccount',
  'Create a RoleBinding named `app-sa-pod-reader` in namespace `rbac-lab` that binds the `pod-reader` Role to the `app-sa` ServiceAccount.',
  '#!/bin/bash
kubectl get rolebinding app-sa-pod-reader -n rbac-lab >/dev/null 2>&1 && \
kubectl get rolebinding app-sa-pod-reader -n rbac-lab \
  -o jsonpath=''{.subjects[0].name}'' | grep -q app-sa',
  'Use `kubectl create rolebinding app-sa-pod-reader --role=pod-reader --serviceaccount=rbac-lab:app-sa -n rbac-lab`.',
  'RoleBinding links a Role to one or more subjects (Users, Groups, ServiceAccounts) within a namespace. Note the --serviceaccount flag requires namespace:name format. The bound subject inherits exactly the permissions defined in the Role.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000095004',
  '00000000-0000-0000-0000-000000090005', 4,
  'Create a ClusterRole for node monitoring',
  'Create a ClusterRole named `node-reader` that grants **get, list, watch** on **nodes** and **nodes/status** resources (cluster-scoped, no namespace needed).',
  '#!/bin/bash
kubectl get clusterrole node-reader >/dev/null 2>&1 && \
kubectl get clusterrole node-reader \
  -o jsonpath=''{.rules[0].resources}'' | grep -q nodes',
  'Use `kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes,nodes/status`.',
  'ClusterRoles are cluster-scoped and can reference cluster-scoped resources (nodes, PVs, namespaces) that Roles cannot. They can also be used in namespace-scoped RoleBindings to grant permissions within a namespace only.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000095005',
  '00000000-0000-0000-0000-000000090005', 5,
  'Bind the ClusterRole to the ServiceAccount cluster-wide',
  'Create a ClusterRoleBinding named `app-sa-node-reader` that grants the `app-sa` ServiceAccount (in namespace `rbac-lab`) the `node-reader` ClusterRole.',
  '#!/bin/bash
kubectl get clusterrolebinding app-sa-node-reader >/dev/null 2>&1 && \
kubectl get clusterrolebinding app-sa-node-reader \
  -o jsonpath=''{.subjects[0].name}'' | grep -q app-sa',
  'Use `kubectl create clusterrolebinding app-sa-node-reader --clusterrole=node-reader --serviceaccount=rbac-lab:app-sa`.',
  'ClusterRoleBinding grants permissions cluster-wide. Unlike RoleBinding (which binds a ClusterRole to a namespace scope), ClusterRoleBinding gives the subject permissions across all namespaces and cluster-scoped resources.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000095006',
  '00000000-0000-0000-0000-000000090005', 6,
  'Deploy a Pod with non-root security context',
  'Create a Pod named `secure-pod` in namespace `rbac-lab` using `nginx:1.27-alpine` with a security context: `runAsNonRoot: true`, `runAsUser: 1000`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`. Use `app-sa` as the ServiceAccount.',
  '#!/bin/bash
kubectl get pod secure-pod -n rbac-lab >/dev/null 2>&1 && \
RUN_AS=$(kubectl get pod secure-pod -n rbac-lab \
  -o jsonpath=''{.spec.securityContext.runAsNonRoot}'' 2>/dev/null) && \
test "$RUN_AS" = "true"',
  'In Pod spec, add `securityContext.runAsNonRoot: true` and `securityContext.runAsUser: 1000`. Also add `serviceAccountName: app-sa`. For container, add `securityContext.allowPrivilegeEscalation: false` and `readOnlyRootFilesystem: true`.',
  'Pod-level securityContext sets process UID/GID. Container-level securityContext can override. readOnlyRootFilesystem prevents the container from writing to its own filesystem (requires tmpfs for /tmp). allowPrivilegeEscalation: false prevents sudo/setuid escalation.',
  20, false, false
),
(
  '00000000-0000-0000-0000-000000095007',
  '00000000-0000-0000-0000-000000090005', 7,
  'Verify RBAC permissions with kubectl auth can-i',
  'Confirm that `app-sa` CAN list pods in namespace `rbac-lab` and CAN get nodes, but CANNOT create pods in `rbac-lab`. Use `kubectl auth can-i` with `--as=system:serviceaccount:rbac-lab:app-sa`.',
  '#!/bin/bash
CAN_LIST=$(kubectl auth can-i list pods -n rbac-lab \
  --as=system:serviceaccount:rbac-lab:app-sa 2>/dev/null)
CAN_CREATE=$(kubectl auth can-i create pods -n rbac-lab \
  --as=system:serviceaccount:rbac-lab:app-sa 2>/dev/null)
test "$CAN_LIST" = "yes" && test "$CAN_CREATE" = "no"',
  'Run `kubectl auth can-i list pods -n rbac-lab --as=system:serviceaccount:rbac-lab:app-sa`. The output should be "yes". Try create: output should be "no".',
  'kubectl auth can-i performs a SubjectAccessReview API call that simulates the authorization check. It respects RBAC bindings, impersonation (--as), and the NodeAuthorizer. Always verify RBAC is working as intended before trusting it blocks access.',
  20, false, false
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES (
  '00000000-0000-0000-0000-000000099005',
  '00000000-0000-0000-0000-000000090005',
  1,
  $json$[
    {"id":"00000000-0000-0000-0000-000000095001","lab_id":"00000000-0000-0000-0000-000000090005","position":1,"title":"Create a ServiceAccount for the application","description":"Create ServiceAccount app-sa in rbac-lab.","verification_script":"#!/bin/bash\nkubectl get serviceaccount app-sa -n rbac-lab >/dev/null 2>&1","hint_context":"kubectl create serviceaccount app-sa -n rbac-lab","explanation_context":"ServiceAccounts provide pod identity for API server authentication","points":10,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000095002","lab_id":"00000000-0000-0000-0000-000000090005","position":2,"title":"Create a Role allowing pod read access","description":"Create Role pod-reader in rbac-lab with get,list,watch on pods and pods/log.","verification_script":"#!/bin/bash\nkubectl get role pod-reader -n rbac-lab >/dev/null 2>&1 && kubectl get role pod-reader -n rbac-lab -o jsonpath='{.rules[0].verbs}' | grep -q list","hint_context":"kubectl create role pod-reader --verb=get,list,watch --resource=pods,pods/log -n rbac-lab","explanation_context":"Roles are namespace-scoped RBAC objects; must be bound to subjects to take effect","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000095003","lab_id":"00000000-0000-0000-0000-000000090005","position":3,"title":"Bind the Role to the ServiceAccount","description":"Create RoleBinding app-sa-pod-reader binding pod-reader to app-sa.","verification_script":"#!/bin/bash\nkubectl get rolebinding app-sa-pod-reader -n rbac-lab >/dev/null 2>&1 && kubectl get rolebinding app-sa-pod-reader -n rbac-lab -o jsonpath='{.subjects[0].name}' | grep -q app-sa","hint_context":"kubectl create rolebinding app-sa-pod-reader --role=pod-reader --serviceaccount=rbac-lab:app-sa -n rbac-lab","explanation_context":"RoleBinding links Role to subjects within a namespace","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000095004","lab_id":"00000000-0000-0000-0000-000000090005","position":4,"title":"Create a ClusterRole for node monitoring","description":"Create ClusterRole node-reader with get,list,watch on nodes and nodes/status.","verification_script":"#!/bin/bash\nkubectl get clusterrole node-reader >/dev/null 2>&1 && kubectl get clusterrole node-reader -o jsonpath='{.rules[0].resources}' | grep -q nodes","hint_context":"kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes,nodes/status","explanation_context":"ClusterRoles are cluster-scoped and can reference cluster-scoped resources","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000095005","lab_id":"00000000-0000-0000-0000-000000090005","position":5,"title":"Bind the ClusterRole to the ServiceAccount cluster-wide","description":"Create ClusterRoleBinding app-sa-node-reader binding node-reader to app-sa.","verification_script":"#!/bin/bash\nkubectl get clusterrolebinding app-sa-node-reader >/dev/null 2>&1 && kubectl get clusterrolebinding app-sa-node-reader -o jsonpath='{.subjects[0].name}' | grep -q app-sa","hint_context":"kubectl create clusterrolebinding app-sa-node-reader --clusterrole=node-reader --serviceaccount=rbac-lab:app-sa","explanation_context":"ClusterRoleBinding grants permissions cluster-wide to the subject","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000095006","lab_id":"00000000-0000-0000-0000-000000090005","position":6,"title":"Deploy a Pod with non-root security context","description":"Create Pod secure-pod in rbac-lab with runAsNonRoot:true, runAsUser:1000, readOnlyRootFilesystem:true.","verification_script":"#!/bin/bash\nkubectl get pod secure-pod -n rbac-lab >/dev/null 2>&1 && RUN_AS=$(kubectl get pod secure-pod -n rbac-lab -o jsonpath='{.spec.securityContext.runAsNonRoot}' 2>/dev/null) && test \"$RUN_AS\" = \"true\"","hint_context":"Add securityContext.runAsNonRoot: true and securityContext.runAsUser: 1000 to Pod spec","explanation_context":"Pod securityContext enforces process UID/GID and privilege restrictions via cgroups","points":20,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000095007","lab_id":"00000000-0000-0000-0000-000000090005","position":7,"title":"Verify RBAC permissions with kubectl auth can-i","description":"Confirm app-sa can list pods but cannot create pods in rbac-lab.","verification_script":"#!/bin/bash\nCAN_LIST=$(kubectl auth can-i list pods -n rbac-lab --as=system:serviceaccount:rbac-lab:app-sa 2>/dev/null)\nCAN_CREATE=$(kubectl auth can-i create pods -n rbac-lab --as=system:serviceaccount:rbac-lab:app-sa 2>/dev/null)\ntest \"$CAN_LIST\" = \"yes\" && test \"$CAN_CREATE\" = \"no\"","hint_context":"kubectl auth can-i list pods -n rbac-lab --as=system:serviceaccount:rbac-lab:app-sa","explanation_context":"auth can-i performs SubjectAccessReview; always verify RBAC is enforced as expected","points":20,"is_optional":false,"is_stateful":false}
  ]$json$::jsonb,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

UPDATE lab_definitions
SET is_published = true, published_version_id = '00000000-0000-0000-0000-000000099005', updated_at = now()
WHERE id = '00000000-0000-0000-0000-000000090005'
  AND published_version_id IS NULL;
