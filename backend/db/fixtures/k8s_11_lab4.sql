-- ════════════════════════════════════════════════════════════════════════════
-- k8s_11_lab4.sql — Lab 4: ConfigMaps, Secrets & Persistent Volumes
-- Module: 000000074002 (Advanced course, Section 4, Module 2)
-- 5 tasks, lab ID: 000000090004, version ID: 000000099004
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO lab_definitions (
  id, org_id, course_id, module_id, scope, title, description,
  lab_type, environment, setup_script,
  max_duration, max_resets, hint_penalty_pct, is_required, is_published,
  published_version_id, created_by
) VALUES (
  '00000000-0000-0000-0000-000000090004',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000070000',
  '00000000-0000-0000-0000-000000074002',
  'module',
  'ConfigMaps, Secrets & Persistent Volumes',
  'Learn the full Kubernetes configuration and storage stack: create a ConfigMap and consume it as environment variables, store database credentials in a Secret, mount the Secret as a volume, and provision persistent storage via a PersistentVolumeClaim.',
  'terminal', 'mindforge/lab-k8s:1.31',
  '#!/bin/bash
kubectl delete namespace config-lab --ignore-not-found=true >/dev/null 2>&1 || true
kubectl create namespace config-lab >/dev/null 2>&1 || true',
  65, 3, 10, true, false, NULL,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
(
  '00000000-0000-0000-0000-000000094001',
  '00000000-0000-0000-0000-000000090004', 1,
  'Create a ConfigMap with application settings',
  'Create a ConfigMap named `app-config` in namespace `config-lab` with the following key-value pairs: `APP_ENV=production`, `LOG_LEVEL=info`, `MAX_CONNECTIONS=100`.',
  '#!/bin/bash
kubectl get configmap app-config -n config-lab >/dev/null 2>&1 && \
kubectl get configmap app-config -n config-lab \
  -o jsonpath=''{.data.APP_ENV}'' | grep -q production',
  'Use `kubectl create configmap app-config --from-literal=APP_ENV=production --from-literal=LOG_LEVEL=info --from-literal=MAX_CONNECTIONS=100 -n config-lab`.',
  'ConfigMaps store non-sensitive configuration as key-value pairs. Unlike Secrets they are not base64-encoded and are visible to anyone with read access to the namespace. Use Secrets for sensitive values.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000094002',
  '00000000-0000-0000-0000-000000090004', 2,
  'Deploy an app Pod consuming ConfigMap as environment variables',
  'Create a Pod named `app-pod` in namespace `config-lab` using image `nginx:1.27` that loads **all keys** from the `app-config` ConfigMap as environment variables using `envFrom.configMapRef`.',
  '#!/bin/bash
kubectl get pod app-pod -n config-lab >/dev/null 2>&1 && \
kubectl get pod app-pod -n config-lab \
  -o jsonpath=''{.spec.containers[0].envFrom[0].configMapRef.name}'' | grep -q app-config',
  'In the Pod spec under `containers[0]`, add `envFrom: [{configMapRef: {name: app-config}}]`. This injects all ConfigMap keys as environment variables.',
  'envFrom.configMapRef injects all keys as env vars in one declaration. Individual keys can be injected with env.valueFrom.configMapKeyRef. Mounted volume files are updated dynamically when ConfigMap changes; env vars are not.',
  15, false, true
),
(
  '00000000-0000-0000-0000-000000094003',
  '00000000-0000-0000-0000-000000090004', 3,
  'Create a Secret for database credentials',
  'Create an Opaque Secret named `db-secret` in namespace `config-lab` with keys: `DB_USER=admin` and `DB_PASSWORD=S3cur3P@ss`.',
  '#!/bin/bash
kubectl get secret db-secret -n config-lab >/dev/null 2>&1 && \
kubectl get secret db-secret -n config-lab -o jsonpath=''{.type}'' | grep -q Opaque',
  'Use `kubectl create secret generic db-secret --from-literal=DB_USER=admin --from-literal=DB_PASSWORD=S3cur3P@ss -n config-lab`. Values are automatically base64-encoded.',
  'Secrets are base64-encoded at rest by default (not encrypted). For true encryption, configure EncryptionConfiguration on the API server. Types: Opaque (generic), kubernetes.io/tls (cert+key), kubernetes.io/dockerconfigjson (image pull), etc.',
  15, false, false
),
(
  '00000000-0000-0000-0000-000000094004',
  '00000000-0000-0000-0000-000000090004', 4,
  'Mount the Secret as a volume in a Pod',
  'Create a Pod named `db-pod` in namespace `config-lab` using image `nginx:1.27` that mounts the `db-secret` Secret as a volume at path `/etc/db-creds`. Each Secret key should appear as a file.',
  '#!/bin/bash
kubectl get pod db-pod -n config-lab >/dev/null 2>&1 && \
kubectl get pod db-pod -n config-lab \
  -o jsonpath=''{.spec.volumes[0].secret.secretName}'' | grep -q db-secret',
  'In Pod spec: add `volumes: [{name: db-vol, secret: {secretName: db-secret}}]` and `volumeMounts: [{name: db-vol, mountPath: /etc/db-creds}]`.',
  'When mounted as a volume, each Secret key becomes a file at mountPath/key-name. The file content is the decoded value. Volume-mounted Secrets are updated automatically (with a kubelet sync delay) when the Secret changes — env var injection is not updated until pod restart.',
  20, false, false
),
(
  '00000000-0000-0000-0000-000000094005',
  '00000000-0000-0000-0000-000000090004', 5,
  'Create a PersistentVolumeClaim and mount it in a Pod',
  'Create a PVC named `data-pvc` in namespace `config-lab` requesting **1Gi** of storage with access mode **ReadWriteOnce**. Then create a Pod named `storage-pod` that mounts this PVC at `/data`.',
  '#!/bin/bash
kubectl get pvc data-pvc -n config-lab >/dev/null 2>&1 && \
kubectl get pod storage-pod -n config-lab >/dev/null 2>&1 && \
MOUNT=$(kubectl get pod storage-pod -n config-lab \
  -o jsonpath=''{.spec.volumes[0].persistentVolumeClaim.claimName}'' 2>/dev/null) && \
test "$MOUNT" = "data-pvc"',
  'Create PVC YAML with `spec.accessModes: [ReadWriteOnce]` and `resources.requests.storage: 1Gi`. Then create Pod with `volumes[0].persistentVolumeClaim.claimName: data-pvc` and corresponding volumeMount.',
  'PVCs abstract the storage backend. The cluster''s StorageClass dynamically provisions a PV matching the claim. ReadWriteOnce (RWO) allows mounting from a single node. The PVC must be in Bound state before the Pod can start.',
  20, false, false
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES (
  '00000000-0000-0000-0000-000000099004',
  '00000000-0000-0000-0000-000000090004',
  1,
  $json$[
    {"id":"00000000-0000-0000-0000-000000094001","lab_id":"00000000-0000-0000-0000-000000090004","position":1,"title":"Create a ConfigMap with application settings","description":"Create ConfigMap app-config in config-lab with APP_ENV=production, LOG_LEVEL=info, MAX_CONNECTIONS=100.","verification_script":"#!/bin/bash\nkubectl get configmap app-config -n config-lab >/dev/null 2>&1 && kubectl get configmap app-config -n config-lab -o jsonpath='{.data.APP_ENV}' | grep -q production","hint_context":"kubectl create configmap app-config --from-literal=APP_ENV=production --from-literal=LOG_LEVEL=info --from-literal=MAX_CONNECTIONS=100 -n config-lab","explanation_context":"ConfigMaps store non-sensitive key-value configuration for pods","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000094002","lab_id":"00000000-0000-0000-0000-000000090004","position":2,"title":"Deploy an app Pod consuming ConfigMap as environment variables","description":"Create Pod app-pod in config-lab loading all app-config keys via envFrom.configMapRef.","verification_script":"#!/bin/bash\nkubectl get pod app-pod -n config-lab >/dev/null 2>&1 && kubectl get pod app-pod -n config-lab -o jsonpath='{.spec.containers[0].envFrom[0].configMapRef.name}' | grep -q app-config","hint_context":"Add envFrom: [{configMapRef: {name: app-config}}] to container spec","explanation_context":"envFrom.configMapRef injects all ConfigMap keys as environment variables","points":15,"is_optional":false,"is_stateful":true},
    {"id":"00000000-0000-0000-0000-000000094003","lab_id":"00000000-0000-0000-0000-000000090004","position":3,"title":"Create a Secret for database credentials","description":"Create Opaque Secret db-secret in config-lab with DB_USER=admin and DB_PASSWORD.","verification_script":"#!/bin/bash\nkubectl get secret db-secret -n config-lab >/dev/null 2>&1 && kubectl get secret db-secret -n config-lab -o jsonpath='{.type}' | grep -q Opaque","hint_context":"kubectl create secret generic db-secret --from-literal=DB_USER=admin --from-literal=DB_PASSWORD=S3cur3P@ss -n config-lab","explanation_context":"Secrets are base64-encoded; configure EncryptionConfiguration for true at-rest encryption","points":15,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000094004","lab_id":"00000000-0000-0000-0000-000000090004","position":4,"title":"Mount the Secret as a volume in a Pod","description":"Create Pod db-pod in config-lab mounting db-secret at /etc/db-creds.","verification_script":"#!/bin/bash\nkubectl get pod db-pod -n config-lab >/dev/null 2>&1 && kubectl get pod db-pod -n config-lab -o jsonpath='{.spec.volumes[0].secret.secretName}' | grep -q db-secret","hint_context":"Add volumes[0].secret.secretName: db-secret and volumeMounts[0].mountPath: /etc/db-creds","explanation_context":"Volume-mounted Secrets create one file per key; updated dynamically unlike env var injection","points":20,"is_optional":false,"is_stateful":false},
    {"id":"00000000-0000-0000-0000-000000094005","lab_id":"00000000-0000-0000-0000-000000090004","position":5,"title":"Create a PersistentVolumeClaim and mount it in a Pod","description":"Create PVC data-pvc (1Gi RWO) in config-lab and Pod storage-pod mounting it at /data.","verification_script":"#!/bin/bash\nkubectl get pvc data-pvc -n config-lab >/dev/null 2>&1 && kubectl get pod storage-pod -n config-lab >/dev/null 2>&1 && MOUNT=$(kubectl get pod storage-pod -n config-lab -o jsonpath='{.spec.volumes[0].persistentVolumeClaim.claimName}' 2>/dev/null) && test \"$MOUNT\" = \"data-pvc\"","hint_context":"Create PVC with accessModes: [ReadWriteOnce] and resources.requests.storage: 1Gi; mount in Pod","explanation_context":"PVCs abstract storage backend; StorageClass dynamically provisions the backing PV","points":20,"is_optional":false,"is_stateful":false}
  ]$json$::jsonb,
  '00000000-0000-0000-0000-000000000012'
) ON CONFLICT (id) DO NOTHING;

UPDATE lab_definitions
SET is_published = true, published_version_id = '00000000-0000-0000-0000-000000099004', updated_at = now()
WHERE id = '00000000-0000-0000-0000-000000090004'
  AND published_version_id IS NULL;
