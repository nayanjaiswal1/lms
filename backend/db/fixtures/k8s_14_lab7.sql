-- ════════════════════════════════════════════════════════════════════════════
-- k8s_14_lab7.sql — Lab 7: Monitoring, Debugging & Resource Quotas
-- Module: 000000083002 (Master course, Section 3, Module 2)
-- 5 tasks, lab ID: 000000090007, version ID: 000000099007
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO lab_definitions (
  id, org_id, course_id, module_id, scope, title, description,
  lab_type, environment, setup_script,
  max_duration, max_resets, hint_penalty_pct, is_required, is_published,
  published_version_id, created_by
) VALUES (
  '00000000-0000-0000-0000-000000090007',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000080000',
  '00000000-0000-0000-0000-000000083002',
  'module',
  'Monitoring, Debugging & Resource Quotas',
  'Master production observability: deploy metrics-server, use kubectl top to inspect resource usage, diagnose a deliberately broken pod, exec into containers for live debugging, and enforce namespace-level resource quotas.',
  'terminal', 'mindforge/lab-k8s:1.31',
  '#!/bin/bash
kubectl delete namespace observe --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create namespace observe >/dev/null 2>&1 || true
# Create a broken pod for debugging task
cat <<EOF | kubectl apply -f - >/dev/null 2>&1 || true
apiVersion: v1
kind: Pod
metadata:
  name: broken-pod
  namespace: observe
spec:
  containers:
  - name: app
    image: nginx:bad-tag-that-does-not-exist
    resources:
      requests:
        cpu: 10m
        memory: 16Mi
EOF',
  80, 3, 10, true, false, NULL,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
(
  '00000000-0000-0000-0000-000000097001',
  '00000000-0000-0000-0000-000000090007', 1,
  'Deploy a resource-bounded pod for monitoring',
  'Create a Pod named `monitored-pod` in namespace `observe` using `nginx:1.27` with resource requests of `cpu=50m, memory=64Mi` and limits of `cpu=200m, memory=128Mi`.',
  '#!/bin/bash
kubectl get pod monitored-pod -n observe >/dev/null 2>&1 && \
CPU_REQ=$(kubectl get pod monitored-pod -n observe \
  -o jsonpath=''{.spec.containers[0].resources.requests.cpu}'' 2>/dev/null) && \
test -n "$CPU_REQ"',
  'Create Pod YAML with resources.requests.cpu: 50m, memory: 64Mi and resources.limits.cpu: 200m, memory: 128Mi. Apply with kubectl apply -f.',
  'Setting both requests and limits allows the scheduler to place the pod and the kubelet to enforce cgroup constraints. Requests determine scheduling; limits cap runtime usage. Without requests, metrics-server CPU utilization cannot be computed as a percentage.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000097002',
  '00000000-0000-0000-0000-000000090007', 2,
  'Inspect resource usage with kubectl top',
  'Run `kubectl top pod monitored-pod -n observe` and confirm it outputs CPU and memory usage. This requires metrics-server to be running in the cluster (pre-installed in this lab environment).',
  '#!/bin/bash
kubectl top pod monitored-pod -n observe >/dev/null 2>&1',
  'If metrics-server is not running, deploy it: `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`. Wait 60s for metrics to populate.',
  'kubectl top uses the metrics.k8s.io API served by metrics-server. It shows current CPU (millicores) and memory (bytes) consumption. It does NOT show historical data — use Prometheus/Grafana for that. The data has a 15-30s lag.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000097003',
  '00000000-0000-0000-0000-000000090007', 3,
  'Diagnose and fix the broken pod',
  'The `broken-pod` in namespace `observe` is failing because it uses a non-existent image tag. Fix it by patching the image to `nginx:1.27` so the pod reaches Running state.',
  '#!/bin/bash
STATUS=$(kubectl get pod broken-pod -n observe \
  -o jsonpath=''{.status.phase}'' 2>/dev/null)
IMG=$(kubectl get pod broken-pod -n observe \
  -o jsonpath=''{.spec.containers[0].image}'' 2>/dev/null)
test "$STATUS" = "Running" && test "$IMG" = "nginx:1.27"',
  'Use `kubectl describe pod broken-pod -n observe` to see the ErrImagePull/ImagePullBackOff event. Patch with: `kubectl patch pod broken-pod -n observe -p "{\"spec\":{\"containers\":[{\"name\":\"app\",\"image\":\"nginx:1.27\"}]}}"`. Note: static Pod image patches may require delete and recreate.',
  'ErrImagePull means the container runtime cannot pull the image (bad tag, no registry access, private registry without imagePullSecret). ImagePullBackOff is the back-off state after repeated failures. `kubectl describe pod` Events section shows the exact error message from the container runtime.',
  25, false, true
),
(
  '00000000-0000-0000-0000-000000097004',
  '00000000-0000-0000-0000-000000090007', 4,
  'Debug a running pod with kubectl exec',
  'Exec into the `monitored-pod` container and verify the Nginx welcome page is reachable on localhost:80. Use `kubectl exec` to run a curl command (or wget) inside the container.',
  '#!/bin/bash
kubectl exec monitored-pod -n observe -- \
  sh -c "wget -qO- localhost:80 2>/dev/null || curl -s localhost:80 2>/dev/null" | \
  grep -q "Welcome to nginx"',
  'Use `kubectl exec -it monitored-pod -n observe -- curl localhost:80` or `wget -qO- localhost:80`. If curl is not available in the image, use wget.',
  'kubectl exec opens an exec session via the API server → kubelet → container runtime. It is the primary tool for live debugging. For production, prefer ephemeral debug containers (`kubectl debug`) to avoid modifying running pods.',
  20, false, false
),
(
  '00000000-0000-0000-0000-000000097005',
  '00000000-0000-0000-0000-000000090007', 5,
  'Create a ResourceQuota for the observe namespace',
  'Create a ResourceQuota named `observe-quota` in namespace `observe` that limits: `pods=10`, `requests.cpu=500m`, `requests.memory=512Mi`, `limits.cpu=2000m`, `limits.memory=2Gi`.',
  '#!/bin/bash
kubectl get resourcequota observe-quota -n observe >/dev/null 2>&1 && \
kubectl get resourcequota observe-quota -n observe \
  -o jsonpath=''{.spec.hard.pods}'' | grep -q 10',
  'Create ResourceQuota YAML with spec.hard.pods: "10", spec.hard.requests.cpu: 500m, spec.hard.requests.memory: 512Mi, spec.hard.limits.cpu: "2000m", spec.hard.limits.memory: 2Gi.',
  'ResourceQuota enforces aggregate limits for a namespace. Once a quota is set, ALL new pods must declare both requests AND limits (LimitRanger can inject defaults). Exceeding a quota returns a 403 Forbidden from the API server. Use `kubectl describe resourcequota -n observe` to see current usage vs limits.',
  20, false, false
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES (
  '00000000-0000-0000-0000-000000099007',
  '00000000-0000-0000-0000-000000090007',
  1,
  $json$[
    {"id":"00000000-0000-0000-0000-000000097001","lab_id":"00000000-0000-0000-0000-000000090007","position":1,"title":"Deploy a resource-bounded pod for monitoring","description":"Create Pod monitored-pod in observe with cpu=50m/200m, memory=64Mi/128Mi requests/limits.","verification_script":"#!/bin/bash\nkubectl get pod monitored-pod -n observe >/dev/null 2>&1 && CPU_REQ=$(kubectl get pod monitored-pod -n observe -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null) && test -n \"$CPU_REQ\"","hint_context":"Create Pod YAML with resources.requests.cpu: 50m and resources.limits.cpu: 200m","explanation_context":"Requests determine scheduling; limits cap runtime usage via cgroups","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000097002","lab_id":"00000000-0000-0000-0000-000000090007","position":2,"title":"Inspect resource usage with kubectl top","description":"Run kubectl top pod monitored-pod in observe namespace successfully.","verification_script":"#!/bin/bash\nkubectl top pod monitored-pod -n observe >/dev/null 2>&1","hint_context":"kubectl top pod monitored-pod -n observe; requires metrics-server to be running","explanation_context":"kubectl top uses the metrics.k8s.io API; data has 15-30s lag from metrics-server","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000097003","lab_id":"00000000-0000-0000-0000-000000090007","position":3,"title":"Diagnose and fix the broken pod","description":"Fix broken-pod (ImagePullBackOff) by patching its image to nginx:1.27.","verification_script":"#!/bin/bash\nSTATUS=$(kubectl get pod broken-pod -n observe -o jsonpath='{.status.phase}' 2>/dev/null)\nIMG=$(kubectl get pod broken-pod -n observe -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)\ntest \"$STATUS\" = \"Running\" && test \"$IMG\" = \"nginx:1.27\"","hint_context":"kubectl describe pod broken-pod -n observe to see the error; patch the image to nginx:1.27","explanation_context":"ErrImagePull/ImagePullBackOff indicates the container runtime cannot pull the image","points":25,"is_optional":false,"is_stateful":true},
    {"id":"00000000-0000-0000-0000-000000097004","lab_id":"00000000-0000-0000-0000-000000090007","position":4,"title":"Debug a running pod with kubectl exec","description":"Exec into monitored-pod and verify nginx welcome page on localhost:80.","verification_script":"#!/bin/bash\nkubectl exec monitored-pod -n observe -- sh -c 'wget -qO- localhost:80 2>/dev/null || curl -s localhost:80 2>/dev/null' | grep -q 'Welcome to nginx'","hint_context":"kubectl exec -it monitored-pod -n observe -- curl localhost:80","explanation_context":"kubectl exec opens a live shell session via API server and kubelet for debugging","points":20,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000097005","lab_id":"00000000-0000-0000-0000-000000090007","position":5,"title":"Create a ResourceQuota for the observe namespace","description":"Create ResourceQuota observe-quota in observe limiting pods=10, requests.cpu=500m, etc.","verification_script":"#!/bin/bash\nkubectl get resourcequota observe-quota -n observe >/dev/null 2>&1 && kubectl get resourcequota observe-quota -n observe -o jsonpath='{.spec.hard.pods}' | grep -q 10","hint_context":"ResourceQuota YAML with spec.hard.pods: 10 and CPU/memory request/limit constraints","explanation_context":"ResourceQuota enforces aggregate namespace limits; all pods must declare requests when quota is set","points":20,"is_optional":false,"is_stateful":false}
  ]$json$::jsonb,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

UPDATE lab_definitions
SET is_published = true, published_version_id = '00000000-0000-0000-0000-000000099007', updated_at = now()
WHERE id = '00000000-0000-0000-0000-000000090007'
  AND published_version_id IS NULL;
