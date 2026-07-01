-- ════════════════════════════════════════════════════════════════════════════
-- k8s_13_lab6.sql — Lab 6: Network Policies & Zero-Trust Networking
-- Module: 000000082002 (Master course, Section 2, Module 2)
-- 6 tasks, lab ID: 000000090006, version ID: 000000099006
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO lab_definitions (
  id, org_id, course_id, module_id, scope, title, description,
  lab_type, environment, setup_script,
  max_duration, max_resets, hint_penalty_pct, is_required, is_published,
  published_version_id, created_by
) VALUES (
  '00000000-0000-0000-0000-000000090006',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000080000',
  '00000000-0000-0000-0000-000000082002',
  'module',
  'Network Policies & Zero-Trust Networking',
  'Build a zero-trust network model from scratch. Start with default-deny, layer allow rules for specific pod-to-pod communication, restrict egress, permit DNS traffic, and validate isolation between namespaces.',
  'terminal', 'mindforge/lab-k8s:1.31',
  '#!/bin/bash
for NS in frontend backend monitoring; do
  kubectl delete namespace $NS --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl create namespace $NS >/dev/null 2>&1 || true
done
kubectl create deployment frontend --image=nginx:1.27 -n frontend >/dev/null 2>&1 || true
kubectl create deployment backend --image=nginx:1.27 -n backend >/dev/null 2>&1 || true
kubectl label deployment frontend app=frontend -n frontend >/dev/null 2>&1 || true
kubectl label deployment backend app=backend -n backend >/dev/null 2>&1 || true',
  90, 3, 10, true, false, NULL,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
(
  '00000000-0000-0000-0000-000000096001',
  '00000000-0000-0000-0000-000000090006', 1,
  'Apply default-deny ingress to the backend namespace',
  'Create a NetworkPolicy named `default-deny-ingress` in namespace `backend` that selects all pods (empty podSelector) and denies all ingress by having an empty ingress array.',
  '#!/bin/bash
kubectl get networkpolicy default-deny-ingress -n backend >/dev/null 2>&1 && \
kubectl get networkpolicy default-deny-ingress -n backend \
  -o jsonpath=''{.spec.podSelector}'' | grep -q "{}"',
  'NetworkPolicy YAML: `spec.podSelector: {}` (selects all pods) and `spec.ingress: []` (empty = deny all). Apply to namespace backend.',
  'An empty podSelector matches all pods in the namespace. Empty ingress means no ingress is allowed. This is the foundation of zero-trust: deny everything, then selectively allow.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000096002',
  '00000000-0000-0000-0000-000000090006', 2,
  'Allow ingress to backend pods only from frontend namespace',
  'Create a NetworkPolicy named `allow-frontend-to-backend` in namespace `backend` that allows ingress to pods with `app=backend` from any pod in the `frontend` namespace on port **80**.',
  '#!/bin/bash
kubectl get networkpolicy allow-frontend-to-backend -n backend >/dev/null 2>&1 && \
kubectl get networkpolicy allow-frontend-to-backend -n backend \
  -o jsonpath=''{.spec.ingress[0].from[0].namespaceSelector}'' | grep -q matchLabels',
  'Use `ingress.from[0].namespaceSelector.matchLabels.kubernetes.io/metadata.name: frontend` and `ingress.ports[0].port: 80`. The frontend namespace must have the metadata.name label (set automatically in K8s 1.21+).',
  'namespaceSelector allows traffic from pods in matching namespaces. Combined with podSelector (AND logic within a single from entry), or separate from entries (OR logic) for more complex rules. Namespace labels are set automatically since K8s 1.21 with kubernetes.io/metadata.name.',
  20, false, false
),
(
  '00000000-0000-0000-0000-000000096003',
  '00000000-0000-0000-0000-000000090006', 3,
  'Apply default-deny egress to the backend namespace',
  'Create a NetworkPolicy named `default-deny-egress` in namespace `backend` that selects all pods and denies all egress.',
  '#!/bin/bash
kubectl get networkpolicy default-deny-egress -n backend >/dev/null 2>&1 && \
kubectl get networkpolicy default-deny-egress -n backend \
  -o jsonpath=''{.spec.policyTypes}'' | grep -q Egress',
  'Add `spec.policyTypes: [Egress]` and `spec.egress: []` with empty podSelector. Without policyTypes: [Egress] the egress restriction won''t apply.',
  'NetworkPolicy spec.policyTypes explicitly declares which policy types the policy enforces. If policyTypes is omitted, Kubernetes infers it from the presence of ingress/egress fields. Always explicitly set policyTypes for clarity.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000096004',
  '00000000-0000-0000-0000-000000090006', 4,
  'Allow DNS egress from backend pods',
  'Create a NetworkPolicy named `allow-dns-egress` in namespace `backend` that allows egress from all pods to **UDP port 53** and **TCP port 53** (DNS). This is required for pod DNS resolution to work.',
  '#!/bin/bash
kubectl get networkpolicy allow-dns-egress -n backend >/dev/null 2>&1 && \
kubectl get networkpolicy allow-dns-egress -n backend \
  -o jsonpath=''{.spec.egress[0].ports[0].port}'' | grep -q 53',
  'Create NetworkPolicy with spec.policyTypes: [Egress] and spec.egress entries for ports 53/UDP and 53/TCP. Use two port entries in the same egress rule or two separate egress rules.',
  'DNS uses both UDP (primary) and TCP (large responses, zone transfers). After applying default-deny-egress, pods cannot resolve any hostnames. This is the minimal egress allowance needed before adding application-specific egress rules.',
  20, false, false
),
(
  '00000000-0000-0000-0000-000000096005',
  '00000000-0000-0000-0000-000000090006', 5,
  'Allow egress from backend to monitoring namespace on port 9090',
  'Create a NetworkPolicy named `allow-metrics-egress` in namespace `backend` that allows egress from `app=backend` pods to any pod in the `monitoring` namespace on port **9090** (Prometheus scrape port).',
  '#!/bin/bash
kubectl get networkpolicy allow-metrics-egress -n backend >/dev/null 2>&1 && \
kubectl get networkpolicy allow-metrics-egress -n backend \
  -o jsonpath=''{.spec.egress[0].ports[0].port}'' | grep -q 9090',
  'NetworkPolicy with spec.podSelector.matchLabels.app: backend, spec.policyTypes: [Egress], spec.egress[0].to[0].namespaceSelector.matchLabels.kubernetes.io/metadata.name: monitoring, spec.egress[0].ports[0].port: 9090.',
  'Fine-grained egress rules control which namespaces and ports backend pods can reach. This is the Prometheus pull model: Prometheus in monitoring scrapes /metrics from backend pods. The egress rule allows backend pods to respond to connections on 9090.',
  20, false, false
),
(
  '00000000-0000-0000-0000-000000096006',
  '00000000-0000-0000-0000-000000090006', 6,
  'Verify isolation: frontend cannot reach backend on port 8080',
  'The NetworkPolicy stack should block frontend pods from reaching backend on port **8080** (which has no allow rule). Verify by confirming no NetworkPolicy allows ingress to backend on port 8080 from the frontend namespace.',
  '#!/bin/bash
ALLOWS=$(kubectl get networkpolicy -n backend -o jsonpath=''{.items[*].spec.ingress[*].ports[*].port}'' 2>/dev/null)
echo "$ALLOWS" | grep -qv 8080 && \
kubectl get networkpolicy default-deny-ingress -n backend >/dev/null 2>&1',
  'Run `kubectl get networkpolicy -n backend` and review all ingress rules. Port 8080 should not appear in any allow rule. The default-deny policy blocks it.',
  'This task validates the zero-trust model: only explicitly allowed traffic flows. Port 8080 is not in any ingress allow rule, so the default-deny-ingress policy blocks it. This is why reviewing NetworkPolicy coverage before deployment is critical.',
  15, false, false
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES (
  '00000000-0000-0000-0000-000000099006',
  '00000000-0000-0000-0000-000000090006',
  1,
  $json$[
    {"id":"00000000-0000-0000-0000-000000096001","lab_id":"00000000-0000-0000-0000-000000090006","position":1,"title":"Apply default-deny ingress to the backend namespace","description":"Create NetworkPolicy default-deny-ingress in backend selecting all pods with empty ingress.","verification_script":"#!/bin/bash\nkubectl get networkpolicy default-deny-ingress -n backend >/dev/null 2>&1","hint_context":"spec.podSelector: {} and spec.ingress: [] in backend namespace","explanation_context":"Empty podSelector matches all pods; empty ingress denies all inbound traffic","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000096002","lab_id":"00000000-0000-0000-0000-000000090006","position":2,"title":"Allow ingress to backend pods only from frontend namespace","description":"Create NetworkPolicy allow-frontend-to-backend allowing frontend namespace pods to reach app=backend on port 80.","verification_script":"#!/bin/bash\nkubectl get networkpolicy allow-frontend-to-backend -n backend >/dev/null 2>&1 && kubectl get networkpolicy allow-frontend-to-backend -n backend -o jsonpath='{.spec.ingress[0].from[0].namespaceSelector}' | grep -q matchLabels","hint_context":"Use namespaceSelector.matchLabels.kubernetes.io/metadata.name: frontend in ingress.from","explanation_context":"namespaceSelector allows cross-namespace traffic; combined with podSelector for fine-grained control","points":20,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000096003","lab_id":"00000000-0000-0000-0000-000000090006","position":3,"title":"Apply default-deny egress to the backend namespace","description":"Create NetworkPolicy default-deny-egress in backend with policyTypes: [Egress] and empty egress.","verification_script":"#!/bin/bash\nkubectl get networkpolicy default-deny-egress -n backend >/dev/null 2>&1 && kubectl get networkpolicy default-deny-egress -n backend -o jsonpath='{.spec.policyTypes}' | grep -q Egress","hint_context":"Add spec.policyTypes: [Egress] and spec.egress: [] with empty podSelector","explanation_context":"policyTypes must be set explicitly for egress policy to apply; empty egress denies all outbound","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000096004","lab_id":"00000000-0000-0000-0000-000000090006","position":4,"title":"Allow DNS egress from backend pods","description":"Create NetworkPolicy allow-dns-egress in backend allowing egress on UDP/TCP port 53.","verification_script":"#!/bin/bash\nkubectl get networkpolicy allow-dns-egress -n backend >/dev/null 2>&1 && kubectl get networkpolicy allow-dns-egress -n backend -o jsonpath='{.spec.egress[0].ports[0].port}' | grep -q 53","hint_context":"Add egress ports for both UDP:53 and TCP:53 in the allow-dns-egress NetworkPolicy","explanation_context":"DNS requires UDP:53 (primary) and TCP:53 (fallback); blocking DNS breaks all hostname resolution","points":20,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000096005","lab_id":"00000000-0000-0000-0000-000000090006","position":5,"title":"Allow egress from backend to monitoring namespace on port 9090","description":"Create NetworkPolicy allow-metrics-egress allowing app=backend pods to reach monitoring namespace on port 9090.","verification_script":"#!/bin/bash\nkubectl get networkpolicy allow-metrics-egress -n backend >/dev/null 2>&1 && kubectl get networkpolicy allow-metrics-egress -n backend -o jsonpath='{.spec.egress[0].ports[0].port}' | grep -q 9090","hint_context":"Use egress.to.namespaceSelector.matchLabels.kubernetes.io/metadata.name: monitoring and ports.port: 9090","explanation_context":"Fine-grained egress rules control which external services backend pods can reach","points":20,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000096006","lab_id":"00000000-0000-0000-0000-000000090006","position":6,"title":"Verify isolation: frontend cannot reach backend on port 8080","description":"Confirm no NetworkPolicy allows ingress to backend on port 8080 (default-deny blocks it).","verification_script":"#!/bin/bash\nALLOWS=$(kubectl get networkpolicy -n backend -o jsonpath='{.items[*].spec.ingress[*].ports[*].port}' 2>/dev/null)\necho \"$ALLOWS\" | grep -qv 8080 && kubectl get networkpolicy default-deny-ingress -n backend >/dev/null 2>&1","hint_context":"Review all NetworkPolicies in backend with kubectl get networkpolicy -n backend -o yaml","explanation_context":"Zero-trust validation: only explicitly allowed traffic flows; port 8080 has no allow rule","points":15,"is_optional":false,"is_stateful":false}
  ]$json$::jsonb,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

UPDATE lab_definitions
SET is_published = true, published_version_id = '00000000-0000-0000-0000-000000099006', updated_at = now()
WHERE id = '00000000-0000-0000-0000-000000090006'
  AND published_version_id IS NULL;
