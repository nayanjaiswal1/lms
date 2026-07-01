-- ════════════════════════════════════════════════════════════════════════════
-- k8s_09_lab2.sql — Lab 2: Deployments, Rolling Updates & HPA
-- Module: 000000072002 (Advanced course, Section 2, Module 2)
-- 6 tasks, lab ID: 000000090002, version ID: 000000099002
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO lab_definitions (
  id, org_id, course_id, module_id, scope, title, description,
  lab_type, environment, setup_script,
  max_duration, max_resets, hint_penalty_pct, is_required, is_published,
  published_version_id, created_by
) VALUES (
  '00000000-0000-0000-0000-000000090002',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000070000',
  '00000000-0000-0000-0000-000000072002',
  'module',
  'Deployments, Rolling Updates & HPA',
  'Master Deployment lifecycle management: create a Deployment, perform a rolling update, roll back, configure liveness probes, set up a PodDisruptionBudget, and finally wire up a HorizontalPodAutoscaler.',
  'terminal', 'mindforge/lab-k8s:1.31',
  '#!/bin/bash
kubectl delete namespace workloads --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create namespace workloads >/dev/null 2>&1 || true',
  90, 3, 10, true, false, NULL,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
(
  '00000000-0000-0000-0000-000000092001',
  '00000000-0000-0000-0000-000000090002', 1,
  'Create a Deployment with 3 replicas and RollingUpdate strategy',
  'Create a Deployment named `api` in namespace `workloads` using image `nginx:1.25`, **3 replicas**, RollingUpdate strategy with `maxSurge=1` and `maxUnavailable=0`.',
  '#!/bin/bash
REPLICAS=$(kubectl get deployment api -n workloads -o jsonpath=''{.spec.replicas}'' 2>/dev/null)
STRATEGY=$(kubectl get deployment api -n workloads -o jsonpath=''{.spec.strategy.type}'' 2>/dev/null)
test "${REPLICAS:-0}" -eq 3 && test "$STRATEGY" = "RollingUpdate"',
  'Create the Deployment YAML with `spec.strategy.type: RollingUpdate` and `rollingUpdate.maxSurge: 1, maxUnavailable: 0`. Apply with `kubectl apply -f`.',
  'maxUnavailable=0 ensures zero downtime — the new pods must be Ready before old pods are removed. maxSurge=1 allows one extra pod during the rollout so the total never exceeds replicas+1.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000092002',
  '00000000-0000-0000-0000-000000090002', 2,
  'Perform a rolling update to nginx:1.27',
  'Update the `api` Deployment to use image `nginx:1.27`. Wait for the rollout to complete. The Deployment must show the new image and all pods Ready.',
  '#!/bin/bash
IMG=$(kubectl get deployment api -n workloads -o jsonpath=''{.spec.template.spec.containers[0].image}'' 2>/dev/null)
READY=$(kubectl get deployment api -n workloads -o jsonpath=''{.status.readyReplicas}'' 2>/dev/null)
test "$IMG" = "nginx:1.27" && test "${READY:-0}" -eq 3',
  'Use `kubectl set image deployment/api api=nginx:1.27 -n workloads`, then watch with `kubectl rollout status deployment/api -n workloads`.',
  'Rolling update: Kubernetes creates a new ReplicaSet with the new image and incrementally shifts pods from old to new RS, respecting maxSurge/maxUnavailable. Revision history is stored in old ReplicaSets.',
  15, false, true
),
(
  '00000000-0000-0000-0000-000000092003',
  '00000000-0000-0000-0000-000000090002', 3,
  'Roll back to the previous image version',
  'Roll back the `api` Deployment to the previous revision (nginx:1.25). All pods must be running the previous image.',
  '#!/bin/bash
IMG=$(kubectl get deployment api -n workloads -o jsonpath=''{.spec.template.spec.containers[0].image}'' 2>/dev/null)
test "$IMG" = "nginx:1.25"',
  'Use `kubectl rollout undo deployment/api -n workloads`. Verify with `kubectl rollout history deployment/api -n workloads`.',
  'undo scales up the previous ReplicaSet and scales down the current one. The current revision becomes the latest entry in history. You can also undo to a specific revision with --to-revision=N.',
  15, false, true
),
(
  '00000000-0000-0000-0000-000000092004',
  '00000000-0000-0000-0000-000000090002', 4,
  'Add a liveness probe to the Deployment',
  'Patch the `api` Deployment to add an HTTP liveness probe: path `/`, port `80`, `initialDelaySeconds=10`, `periodSeconds=15`, `failureThreshold=3`.',
  '#!/bin/bash
PATH_VAL=$(kubectl get deployment api -n workloads \
  -o jsonpath=''{.spec.template.spec.containers[0].livenessProbe.httpGet.path}'' 2>/dev/null)
test "$PATH_VAL" = "/"',
  'Edit the deployment YAML to add `livenessProbe.httpGet.path: /` and `livenessProbe.httpGet.port: 80` under the container spec. Apply with `kubectl apply`.',
  'Liveness probes detect hung/deadlocked containers. On consecutive failures (failureThreshold), kubelet restarts the container. HTTP probes are most common for web services; exec probes run a command; TCP probes attempt a TCP connection.',
  20, false, false
),
(
  '00000000-0000-0000-0000-000000092005',
  '00000000-0000-0000-0000-000000090002', 5,
  'Create a PodDisruptionBudget for the api Deployment',
  'Create a PodDisruptionBudget named `api-pdb` in namespace `workloads` that ensures **at least 2 pods** are always available during voluntary disruptions.',
  '#!/bin/bash
kubectl get pdb api-pdb -n workloads >/dev/null 2>&1 && \
MIN=$(kubectl get pdb api-pdb -n workloads -o jsonpath=''{.spec.minAvailable}'' 2>/dev/null) && \
test "${MIN:-0}" -ge 2',
  'Create a PDB YAML with `spec.minAvailable: 2` and `selector.matchLabels.app: api`. Apply with `kubectl apply`.',
  'PodDisruptionBudgets protect against voluntary disruptions (node drain, rolling update) by ensuring a minimum number of pods remain available. maxUnavailable is the complementary field. PDBs are enforced by the Eviction API — drain and HPA respect them.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000092006',
  '00000000-0000-0000-0000-000000090002', 6,
  'Configure a HorizontalPodAutoscaler targeting 50% CPU',
  'Create an HPA named `api-hpa` in namespace `workloads` targeting the `api` Deployment: min replicas=2, max replicas=10, target CPU utilization=50%.',
  '#!/bin/bash
kubectl get hpa api-hpa -n workloads >/dev/null 2>&1 && \
MAX=$(kubectl get hpa api-hpa -n workloads -o jsonpath=''{.spec.maxReplicas}'' 2>/dev/null) && \
test "${MAX:-0}" -eq 10',
  'Use `kubectl autoscale deployment api --min=2 --max=10 --cpu-percent=50 -n workloads`. This requires the api Deployment to have CPU requests set.',
  'HPA requires the target resource to have resource requests defined so it can compute utilization (usage/request). The HPA controller syncs every 15 seconds and uses metrics from metrics-server. The scale-down stabilization window (5 min default) prevents thrashing.',
  20, false, false
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES (
  '00000000-0000-0000-0000-000000099002',
  '00000000-0000-0000-0000-000000090002',
  1,
  $json$[
    {"id":"00000000-0000-0000-0000-000000092001","lab_id":"00000000-0000-0000-0000-000000090002","position":1,"title":"Create a Deployment with 3 replicas and RollingUpdate strategy","description":"Create Deployment api in workloads with nginx:1.25, 3 replicas, RollingUpdate maxSurge=1 maxUnavailable=0.","verification_script":"#!/bin/bash\nREPLICAS=$(kubectl get deployment api -n workloads -o jsonpath='{.spec.replicas}' 2>/dev/null)\nSTRATEGY=$(kubectl get deployment api -n workloads -o jsonpath='{.spec.strategy.type}' 2>/dev/null)\ntest \"${REPLICAS:-0}\" -eq 3 && test \"$STRATEGY\" = \"RollingUpdate\"","hint_context":"Create Deployment YAML with strategy.type: RollingUpdate and rollingUpdate.maxSurge: 1, maxUnavailable: 0","explanation_context":"maxUnavailable=0 ensures zero downtime during rolling update","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000092002","lab_id":"00000000-0000-0000-0000-000000090002","position":2,"title":"Perform a rolling update to nginx:1.27","description":"Update api Deployment image to nginx:1.27 and wait for rollout completion.","verification_script":"#!/bin/bash\nIMG=$(kubectl get deployment api -n workloads -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)\nREADY=$(kubectl get deployment api -n workloads -o jsonpath='{.status.readyReplicas}' 2>/dev/null)\ntest \"$IMG\" = \"nginx:1.27\" && test \"${READY:-0}\" -eq 3","hint_context":"kubectl set image deployment/api api=nginx:1.27 -n workloads","explanation_context":"Rolling update incrementally shifts pods from old to new ReplicaSet","points":15,"is_optional":false,"is_stateful":true},
    {"id":"00000000-0000-0000-0000-000000092003","lab_id":"00000000-0000-0000-0000-000000090002","position":3,"title":"Roll back to the previous image version","description":"Roll back api Deployment to previous revision (nginx:1.25).","verification_script":"#!/bin/bash\nIMG=$(kubectl get deployment api -n workloads -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)\ntest \"$IMG\" = \"nginx:1.25\"","hint_context":"kubectl rollout undo deployment/api -n workloads","explanation_context":"undo scales up the previous ReplicaSet and scales down the current one","points":15,"is_optional":false,"is_stateful":true},
    {"id":"00000000-0000-0000-0000-000000092004","lab_id":"00000000-0000-0000-0000-000000090002","position":4,"title":"Add a liveness probe to the Deployment","description":"Add HTTP liveness probe on path / port 80 with initialDelaySeconds=10.","verification_script":"#!/bin/bash\nPATH_VAL=$(kubectl get deployment api -n workloads -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.path}' 2>/dev/null)\ntest \"$PATH_VAL\" = \"/\"","hint_context":"Add livenessProbe.httpGet.path: / and livenessProbe.httpGet.port: 80 to container spec","explanation_context":"Liveness probes detect hung containers and trigger restarts","points":20,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000092005","lab_id":"00000000-0000-0000-0000-000000090002","position":5,"title":"Create a PodDisruptionBudget for the api Deployment","description":"Create PDB api-pdb in workloads with minAvailable=2.","verification_script":"#!/bin/bash\nkubectl get pdb api-pdb -n workloads >/dev/null 2>&1 && MIN=$(kubectl get pdb api-pdb -n workloads -o jsonpath='{.spec.minAvailable}' 2>/dev/null) && test \"${MIN:-0}\" -ge 2","hint_context":"Create PDB YAML with spec.minAvailable: 2 and selector matching app=api","explanation_context":"PDBs protect against voluntary disruptions by enforcing minimum available pods","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000092006","lab_id":"00000000-0000-0000-0000-000000090002","position":6,"title":"Configure a HorizontalPodAutoscaler targeting 50% CPU","description":"Create HPA api-hpa in workloads: min=2, max=10, target CPU=50%.","verification_script":"#!/bin/bash\nkubectl get hpa api-hpa -n workloads >/dev/null 2>&1 && MAX=$(kubectl get hpa api-hpa -n workloads -o jsonpath='{.spec.maxReplicas}' 2>/dev/null) && test \"${MAX:-0}\" -eq 10","hint_context":"kubectl autoscale deployment api --min=2 --max=10 --cpu-percent=50 -n workloads","explanation_context":"HPA syncs every 15s and uses metrics-server data for CPU-based scaling","points":20,"is_optional":false,"is_stateful":false}
  ]$json$::jsonb,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

UPDATE lab_definitions
SET is_published = true, published_version_id = '00000000-0000-0000-0000-000000099002', updated_at = now()
WHERE id = '00000000-0000-0000-0000-000000090002'
  AND published_version_id IS NULL;
