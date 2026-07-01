-- ════════════════════════════════════════════════════════════════════════════
-- k8s_08_lab1.sql — Lab 1: Deploy Your First Pod
-- Module: 000000071002 (Advanced course, Section 1, Module 2)
-- 5 tasks, lab ID: 000000090001, version ID: 000000099001
-- ════════════════════════════════════════════════════════════════════════════

-- Step 1: Insert lab definition (published_version_id=NULL until version exists)
INSERT INTO lab_definitions (
  id, org_id, course_id, module_id, scope, title, description,
  lab_type, environment, setup_script,
  max_duration, max_resets, hint_penalty_pct, is_required, is_published,
  published_version_id, created_by
) VALUES (
  '00000000-0000-0000-0000-000000090001',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000070000',
  '00000000-0000-0000-0000-000000071002',
  'module',
  'Deploy Your First Pod',
  'Start from scratch with a bare Kubernetes cluster. You will create namespaces, deploy Nginx as a Deployment, expose it via a Service, scale it, and add resource constraints — the five skills every K8s practitioner uses every day.',
  'terminal', 'mindforge/lab-k8s:1.31',
  '#!/bin/bash
# Lab environment setup — single-node K8s cluster (kubeadm, containerd)
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
kubectl delete namespace production --ignore-not-found=true >/dev/null 2>&1 || true',
  60, 3, 10, true, false, NULL,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

-- Step 2: Insert lab tasks
INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
(
  '00000000-0000-0000-0000-000000091001',
  '00000000-0000-0000-0000-000000090001', 1,
  'Create the production namespace',
  'Create a Kubernetes namespace named **production**. Namespaces provide logical isolation for workloads. All subsequent resources in this lab will live in this namespace.',
  '#!/bin/bash
kubectl get namespace production >/dev/null 2>&1',
  'Use `kubectl create namespace production` or apply a YAML manifest with `kind: Namespace`. Check with `kubectl get ns`.',
  'A Namespace is a Kubernetes object that provides a scope for names and resource quotas. `kubectl create namespace production` is the imperative approach; the declarative approach uses a YAML with `apiVersion: v1, kind: Namespace`.',
  10, false, false
),
(
  '00000000-0000-0000-0000-000000091002',
  '00000000-0000-0000-0000-000000090001', 2,
  'Deploy an Nginx Deployment in the production namespace',
  'Create a **Deployment** named `nginx` in the `production` namespace using the `nginx:1.27` image with **1 initial replica**. The pod must have the label `app=nginx`.',
  '#!/bin/bash
kubectl get deployment nginx -n production >/dev/null 2>&1 && \
kubectl get pods -n production -l app=nginx --no-headers 2>/dev/null | grep -q Running',
  'Use `kubectl create deployment nginx --image=nginx:1.27 -n production`. A Deployment creates a ReplicaSet which manages the pods.',
  'Deployments are the recommended way to run stateless workloads. They manage a ReplicaSet which in turn manages Pods. The label `app=nginx` is added automatically by `kubectl create deployment`.',
  15, false, true
),
(
  '00000000-0000-0000-0000-000000091003',
  '00000000-0000-0000-0000-000000090001', 3,
  'Expose the Deployment as a ClusterIP Service',
  'Create a **ClusterIP Service** named `nginx-svc` in the `production` namespace that routes traffic to the nginx pods on port **80**.',
  '#!/bin/bash
kubectl get svc nginx-svc -n production >/dev/null 2>&1 && \
kubectl get svc nginx-svc -n production -o jsonpath=''{.spec.type}'' | grep -q ClusterIP',
  'Use `kubectl expose deployment nginx --name=nginx-svc --port=80 --type=ClusterIP -n production`. The selector must match the pod label `app=nginx`.',
  'A ClusterIP Service creates a stable virtual IP reachable only within the cluster. kube-proxy programs iptables/IPVS rules that DNAT traffic from the ClusterIP to one of the ready pod IPs.',
  15, false, true
),
(
  '00000000-0000-0000-0000-000000091004',
  '00000000-0000-0000-0000-000000090001', 4,
  'Scale the Deployment to 3 replicas',
  'Scale the `nginx` Deployment in the `production` namespace to **3 replicas**. All 3 pods must be in Running state before this task is marked complete.',
  '#!/bin/bash
READY=$(kubectl get deployment nginx -n production -o jsonpath=''{.status.readyReplicas}'' 2>/dev/null)
test "${READY:-0}" -ge 3',
  'Use `kubectl scale deployment nginx --replicas=3 -n production`. Monitor with `kubectl rollout status deployment/nginx -n production`.',
  'Scaling a Deployment updates `.spec.replicas`. The Deployment controller adjusts the ReplicaSet''s replica count, which schedules or terminates pods. readyReplicas tracks pods that passed their readiness probe.',
  20, false, true
),
(
  '00000000-0000-0000-0000-000000091005',
  '00000000-0000-0000-0000-000000090001', 5,
  'Add CPU and memory resource limits',
  'Patch the `nginx` Deployment to add resource limits: **CPU=200m** and **memory=128Mi** on the nginx container. The Deployment must complete its rolling update successfully.',
  '#!/bin/bash
MEM=$(kubectl get deployment nginx -n production \
  -o jsonpath=''{.spec.template.spec.containers[0].resources.limits.memory}'' 2>/dev/null)
CPU=$(kubectl get deployment nginx -n production \
  -o jsonpath=''{.spec.template.spec.containers[0].resources.limits.cpu}'' 2>/dev/null)
test -n "$MEM" && test -n "$CPU"',
  'Use `kubectl set resources deployment nginx -c nginx --limits=cpu=200m,memory=128Mi -n production`. Check with `kubectl describe deployment nginx -n production`.',
  'Resource limits are enforced by the container runtime via cgroups. CPU limits throttle (compressible); memory limits cause OOMKill (incompressible). Setting both requests and limits equal gives the pod Guaranteed QoS — it is the last to be evicted under node memory pressure.',
  20, false, false
)
ON CONFLICT (id) DO NOTHING;

-- Step 3: Insert lab task version (JSONB snapshot of all tasks)
INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES (
  '00000000-0000-0000-0000-000000099001',
  '00000000-0000-0000-0000-000000090001',
  1,
  $json$[
    {"id":"00000000-0000-0000-0000-000000091001","lab_id":"00000000-0000-0000-0000-000000090001","position":1,"title":"Create the production namespace","description":"Create a Kubernetes namespace named production.","verification_script":"#!/bin/bash\nkubectl get namespace production >/dev/null 2>&1","hint_context":"Use kubectl create namespace production","explanation_context":"Namespaces provide logical isolation for workloads.","points":10,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000091002","lab_id":"00000000-0000-0000-0000-000000090001","position":2,"title":"Deploy an Nginx Deployment in the production namespace","description":"Create a Deployment named nginx in the production namespace using nginx:1.27.","verification_script":"#!/bin/bash\nkubectl get deployment nginx -n production >/dev/null 2>&1 && kubectl get pods -n production -l app=nginx --no-headers 2>/dev/null | grep -q Running","hint_context":"Use kubectl create deployment nginx --image=nginx:1.27 -n production","explanation_context":"Deployments manage a ReplicaSet which manages Pods.","points":15,"is_optional":false,"is_stateful":true},
    {"id":"00000000-0000-0000-0000-000000091003","lab_id":"00000000-0000-0000-0000-000000090001","position":3,"title":"Expose the Deployment as a ClusterIP Service","description":"Create a ClusterIP Service named nginx-svc in production on port 80.","verification_script":"#!/bin/bash\nkubectl get svc nginx-svc -n production >/dev/null 2>&1 && kubectl get svc nginx-svc -n production -o jsonpath='{.spec.type}' | grep -q ClusterIP","hint_context":"Use kubectl expose deployment nginx --name=nginx-svc --port=80 --type=ClusterIP -n production","explanation_context":"ClusterIP creates a stable virtual IP reachable only within the cluster.","points":15,"is_optional":false,"is_stateful":true},
    {"id":"00000000-0000-0000-0000-000000091004","lab_id":"00000000-0000-0000-0000-000000090001","position":4,"title":"Scale the Deployment to 3 replicas","description":"Scale the nginx Deployment in production to 3 replicas.","verification_script":"#!/bin/bash\nREADY=$(kubectl get deployment nginx -n production -o jsonpath='{.status.readyReplicas}' 2>/dev/null)\ntest \"${READY:-0}\" -ge 3","hint_context":"Use kubectl scale deployment nginx --replicas=3 -n production","explanation_context":"Scaling updates .spec.replicas; the controller adjusts pods accordingly.","points":20,"is_optional":false,"is_stateful":true},
    {"id":"00000000-0000-0000-0000-000000091005","lab_id":"00000000-0000-0000-0000-000000090001","position":5,"title":"Add CPU and memory resource limits","description":"Add CPU=200m and memory=128Mi limits to the nginx container.","verification_script":"#!/bin/bash\nMEM=$(kubectl get deployment nginx -n production -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)\nCPU=$(kubectl get deployment nginx -n production -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null)\ntest -n \"$MEM\" && test -n \"$CPU\"","hint_context":"Use kubectl set resources deployment nginx -c nginx --limits=cpu=200m,memory=128Mi -n production","explanation_context":"CPU limits throttle; memory limits cause OOMKill. Equal requests/limits = Guaranteed QoS.","points":20,"is_optional":false,"is_stateful":false}
  ]$json$::jsonb,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

-- Step 4: Publish the lab
UPDATE lab_definitions
SET is_published = true, published_version_id = '00000000-0000-0000-0000-000000099001', updated_at = now()
WHERE id = '00000000-0000-0000-0000-000000090001'
  AND published_version_id IS NULL;
