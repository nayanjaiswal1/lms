-- ════════════════════════════════════════════════════════════════════════════
-- k8s_10_lab3.sql — Lab 3: Services, Ingress & Network Policies
-- Module: 000000073002 (Advanced course, Section 3, Module 2)
-- 5 tasks, lab ID: 000000090003, version ID: 000000099003
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO lab_definitions (
  id, org_id, course_id, module_id, scope, title, description,
  lab_type, environment, setup_script,
  max_duration, max_resets, hint_penalty_pct, is_required, is_published,
  published_version_id, created_by
) VALUES (
  '00000000-0000-0000-0000-000000090003',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000070000',
  '00000000-0000-0000-0000-000000073002',
  'module',
  'Services, Ingress & Network Policies',
  'Build the full networking stack: deploy a web app, expose it via ClusterIP and NodePort, configure an Ingress resource, and protect it with NetworkPolicy rules that allow only frontend-to-backend communication.',
  'terminal', 'mindforge/lab-k8s:1.31',
  '#!/bin/bash
kubectl delete namespace netlab --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create namespace netlab >/dev/null 2>&1 || true
kubectl create deployment web --image=nginx:1.27 -n netlab >/dev/null 2>&1 || true
kubectl label deployment web app=web -n netlab >/dev/null 2>&1 || true',
  70, 3, 10, true, false, NULL,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
(
  '00000000-0000-0000-0000-000000093001',
  '00000000-0000-0000-0000-000000090003', 1,
  'Create a ClusterIP Service for the web Deployment',
  'Expose the `web` Deployment in namespace `netlab` as a **ClusterIP** Service named `web-clusterip` on port **80**, targeting container port 80.',
  '#!/bin/bash
kubectl get svc web-clusterip -n netlab >/dev/null 2>&1 && \
kubectl get svc web-clusterip -n netlab -o jsonpath=''{.spec.type}'' | grep -q ClusterIP',
  'Use `kubectl expose deployment web --name=web-clusterip --port=80 --type=ClusterIP -n netlab`.',
  'ClusterIP is the default service type. It creates a virtual IP in the cluster''s service CIDR. kube-proxy programs iptables/IPVS NAT rules so any pod hitting ClusterIP:80 gets forwarded to a ready web pod.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000093002',
  '00000000-0000-0000-0000-000000090003', 2,
  'Expose the web Service as a NodePort on port 30080',
  'Create a **NodePort** Service named `web-nodeport` in namespace `netlab` that exposes the web pods on node port **30080** (service port 80).',
  '#!/bin/bash
kubectl get svc web-nodeport -n netlab >/dev/null 2>&1 && \
NPORT=$(kubectl get svc web-nodeport -n netlab -o jsonpath=''{.spec.ports[0].nodePort}'' 2>/dev/null) && \
test "${NPORT:-0}" -eq 30080',
  'Define a Service YAML with `spec.type: NodePort` and `spec.ports[0].nodePort: 30080`. Apply with `kubectl apply -f`.',
  'NodePort builds on ClusterIP: it assigns a static port (30000-32767) on every node. External traffic reaches <NodeIP>:30080 → kube-proxy forwards to ClusterIP → pod. Prefer LoadBalancer or Ingress for production.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000093003',
  '00000000-0000-0000-0000-000000090003', 3,
  'Create an Ingress resource routing / to the web service',
  'Create an **Ingress** named `web-ingress` in namespace `netlab` with a rule for host `web.local` that routes path `/` (PathType: Prefix) to `web-clusterip:80`.',
  '#!/bin/bash
kubectl get ingress web-ingress -n netlab >/dev/null 2>&1 && \
kubectl get ingress web-ingress -n netlab -o jsonpath=''{.spec.rules[0].host}'' | grep -q web.local',
  'Create an Ingress YAML with `spec.rules[0].host: web.local` and `http.paths[0].backend.service.name: web-clusterip`. An Ingress controller (nginx-ingress) must be running in the cluster.',
  'Ingress is a Layer 7 HTTP/HTTPS router. The Ingress object just defines routing rules; an Ingress controller (e.g., nginx, traefik) watches Ingress objects and configures its internal proxy accordingly. Unlike Services, Ingress can route by host and path.',
  20, false, false
),
(
  '00000000-0000-0000-0000-000000093004',
  '00000000-0000-0000-0000-000000090003', 4,
  'Deny all ingress traffic to the web pods by default',
  'Apply a **NetworkPolicy** named `deny-all-web` in namespace `netlab` that selects pods with label `app=web` and denies all ingress traffic (empty `ingress: []`).',
  '#!/bin/bash
kubectl get networkpolicy deny-all-web -n netlab >/dev/null 2>&1 && \
kubectl get networkpolicy deny-all-web -n netlab -o jsonpath=''{.spec.ingress}'' | grep -q "\[\]"',
  'Create NetworkPolicy YAML with `spec.podSelector.matchLabels.app: web` and `spec.ingress: []` (empty array). This matches "all ingress is denied" — no ingress rule = no ingress allowed.',
  'NetworkPolicy is additive — by default all traffic is allowed. Adding a NetworkPolicy with empty ingress list DENIES all ingress to selected pods. You must then add separate NetworkPolicies to allow specific traffic. This is the "default deny, explicit allow" pattern.',
  20, false, false
),
(
  '00000000-0000-0000-0000-000000093005',
  '00000000-0000-0000-0000-000000090003', 5,
  'Allow ingress only from pods labeled app=frontend',
  'Create a **NetworkPolicy** named `allow-frontend-web` in namespace `netlab` that allows ingress to `app=web` pods **only from pods with label `app=frontend`** in the same namespace, on port 80.',
  '#!/bin/bash
kubectl get networkpolicy allow-frontend-web -n netlab >/dev/null 2>&1 && \
kubectl get networkpolicy allow-frontend-web -n netlab \
  -o jsonpath=''{.spec.ingress[0].from[0].podSelector.matchLabels.app}'' | grep -q frontend',
  'Create NetworkPolicy with `spec.ingress[0].from[0].podSelector.matchLabels.app: frontend` and `spec.ingress[0].ports[0].port: 80`. This adds an allowance on top of the deny-all policy.',
  'Multiple NetworkPolicies are ORed together — a pod is allowed if ANY policy permits the traffic. The combination of deny-all + allow-frontend means only frontend pods can reach web pods on port 80. All other sources are blocked.',
  20, false, false
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES (
  '00000000-0000-0000-0000-000000099003',
  '00000000-0000-0000-0000-000000090003',
  1,
  $json$[
    {"id":"00000000-0000-0000-0000-000000093001","lab_id":"00000000-0000-0000-0000-000000090003","position":1,"title":"Create a ClusterIP Service for the web Deployment","description":"Expose web Deployment as ClusterIP web-clusterip on port 80.","verification_script":"#!/bin/bash\nkubectl get svc web-clusterip -n netlab >/dev/null 2>&1 && kubectl get svc web-clusterip -n netlab -o jsonpath='{.spec.type}' | grep -q ClusterIP","hint_context":"kubectl expose deployment web --name=web-clusterip --port=80 --type=ClusterIP -n netlab","explanation_context":"ClusterIP creates a virtual IP in the cluster service CIDR accessible only from within the cluster","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000093002","lab_id":"00000000-0000-0000-0000-000000090003","position":2,"title":"Expose the web Service as a NodePort on port 30080","description":"Create NodePort Service web-nodeport exposing web pods on node port 30080.","verification_script":"#!/bin/bash\nkubectl get svc web-nodeport -n netlab >/dev/null 2>&1 && NPORT=$(kubectl get svc web-nodeport -n netlab -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null) && test \"${NPORT:-0}\" -eq 30080","hint_context":"Define Service YAML with spec.type: NodePort and spec.ports[0].nodePort: 30080","explanation_context":"NodePort opens a static port on every node, building on ClusterIP","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000093003","lab_id":"00000000-0000-0000-0000-000000090003","position":3,"title":"Create an Ingress resource routing / to the web service","description":"Create Ingress web-ingress routing host web.local path / to web-clusterip:80.","verification_script":"#!/bin/bash\nkubectl get ingress web-ingress -n netlab >/dev/null 2>&1 && kubectl get ingress web-ingress -n netlab -o jsonpath='{.spec.rules[0].host}' | grep -q web.local","hint_context":"Create Ingress YAML with spec.rules[0].host: web.local and backend service web-clusterip","explanation_context":"Ingress provides L7 HTTP routing; requires an Ingress controller to be deployed","points":20,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000093004","lab_id":"00000000-0000-0000-0000-000000090003","position":4,"title":"Deny all ingress traffic to the web pods by default","description":"Apply NetworkPolicy deny-all-web selecting app=web with empty ingress list.","verification_script":"#!/bin/bash\nkubectl get networkpolicy deny-all-web -n netlab >/dev/null 2>&1","hint_context":"NetworkPolicy YAML with spec.podSelector.matchLabels.app: web and spec.ingress: []","explanation_context":"Empty ingress list means no ingress is allowed to selected pods","points":20,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000093005","lab_id":"00000000-0000-0000-0000-000000090003","position":5,"title":"Allow ingress only from pods labeled app=frontend","description":"Create NetworkPolicy allow-frontend-web allowing app=frontend pods to reach app=web on port 80.","verification_script":"#!/bin/bash\nkubectl get networkpolicy allow-frontend-web -n netlab >/dev/null 2>&1 && kubectl get networkpolicy allow-frontend-web -n netlab -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels.app}' | grep -q frontend","hint_context":"NetworkPolicy with ingress.from.podSelector.matchLabels.app: frontend and ports.port: 80","explanation_context":"Multiple NetworkPolicies are ORed; deny-all + allow-frontend = only frontend can reach web","points":20,"is_optional":false,"is_stateful":false}
  ]$json$::jsonb,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

UPDATE lab_definitions
SET is_published = true, published_version_id = '00000000-0000-0000-0000-000000099003', updated_at = now()
WHERE id = '00000000-0000-0000-0000-000000090003'
  AND published_version_id IS NULL;
