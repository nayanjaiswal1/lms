-- ════════════════════════════════════════════════════════════════════════════
-- k8s_05_questions_q7q8.sql — Questions for Quiz 7 (Observability) & Quiz 8 (CKA Prep)
-- Assessment 000000060007 and 000000060008
-- ════════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════════
-- QUIZ 7 — Observability, Logging & Troubleshooting (5 questions, total 20 pts)
-- ════════════════════════════════════════════════════════════════════════════

-- Q7-1: MCQ single, advanced, 3 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000057001','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Kubernetes metrics-server API surface','advanced',3,ARRAY['k8s','metrics-server','hpa','monitoring'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000057101','00000000-0000-0000-0000-000000057001',1,
  $json${
    "prompt": "Which Kubernetes API does metrics-server implement, and what does it expose?",
    "multiple": false,
    "options": [
      {"id":"a","text":"It implements the custom.metrics.k8s.io API, exposing arbitrary application metrics for HPA v2","is_correct":false},
      {"id":"b","text":"It implements the metrics.k8s.io API (resource metrics API), exposing current CPU and memory usage for nodes and pods — used by HPA and kubectl top","is_correct":true},
      {"id":"c","text":"It implements the events.k8s.io API, exposing cluster event history for debugging","is_correct":false},
      {"id":"d","text":"It implements Prometheus /metrics endpoints and translates them to Kubernetes-native objects","is_correct":false}
    ],
    "explanation":"metrics-server implements the resource metrics API (metrics.k8s.io/v1beta1) which exposes CPU and memory for pods/nodes as point-in-time samples. HPA uses this for CPU/memory autoscaling. For custom metrics (e.g. requests/sec), you need a custom metrics adapter like prometheus-adapter that implements custom.metrics.k8s.io."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q7-2: MCQ multiple, expert, 4 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000057002','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Valid Kubernetes audit log event stages','expert',4,ARRAY['k8s','audit','logging','security'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000057102','00000000-0000-0000-0000-000000057002',1,
  $json${
    "prompt": "Select all stages that are valid in a Kubernetes audit log event lifecycle.",
    "multiple": true,
    "options": [
      {"id":"a","text":"RequestReceived","is_correct":true},
      {"id":"b","text":"ResponseStarted","is_correct":true},
      {"id":"c","text":"ResponseComplete","is_correct":true},
      {"id":"d","text":"RequestValidated","is_correct":false}
    ],
    "explanation":"Kubernetes audit event stages: RequestReceived (request arrives at API server before authentication), ResponseStarted (response headers sent, body not yet complete — used for watch/streaming), ResponseComplete (response body sent in full), Panic (panic in API server handler). 'RequestValidated' is not a real stage."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q7-3: MCQ single, expert, 3 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000057003','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Liveness probe vs startup probe behavior','expert',3,ARRAY['k8s','probes','health','reliability'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000057103','00000000-0000-0000-0000-000000057003',1,
  $json${
    "prompt": "A slow-starting Java application takes up to 120 seconds to become healthy. You configure a liveness probe with `initialDelaySeconds: 30`. What problem occurs, and how does the startup probe solve it?",
    "multiple": false,
    "options": [
      {"id":"a","text":"No problem occurs; initialDelaySeconds prevents liveness checks until the app is ready","is_correct":false},
      {"id":"b","text":"The liveness probe fires during startup before the app is healthy, causing kubelet to restart the container in a CrashLoopBackOff loop. A startup probe disables the liveness probe until it succeeds, giving the app time to boot","is_correct":true},
      {"id":"c","text":"The readiness probe is the correct fix — setting readinessProbe.initialDelaySeconds to 120 prevents liveness kills","is_correct":false},
      {"id":"d","text":"The startup probe and liveness probe run simultaneously; whichever succeeds first determines container health","is_correct":false}
    ],
    "explanation":"If a liveness probe with initialDelaySeconds=30 fires at 31s but the app needs 120s, it will fail repeatedly, triggering restarts before the app ever starts. The startup probe blocks liveness/readiness until it succeeds (up to failureThreshold × periodSeconds). Once the startup probe passes, liveness and readiness probes take over for the running container."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q7-4: coding, advanced, 5 pts — compute average CPU usage
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000057004','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','coding',
  'Compute average CPU usage from pod metrics samples','advanced',5,ARRAY['k8s','metrics','monitoring','math'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000057104','00000000-0000-0000-0000-000000057004',1,
  $json${
    "prompt": "Given N CPU usage samples in millicores (integers, one per line), compute the **floor average** and print it as a single integer.\n\n**Example:**\n```\n5\n120\n250\n80\n310\n195\n```\nOutput: `191`  (955 / 5 = 191.0)",
    "languages": ["python","javascript"],
    "starter_code": {
      "python": "n = int(input())\ntotal = sum(int(input()) for _ in range(n))\nprint(total // n)\n",
      "javascript": "const lines = require('fs').readFileSync(0,'utf8').trim().split('\\n');\nconst n = parseInt(lines[0]);\nlet total = 0;\nfor (let i = 1; i <= n; i++) total += parseInt(lines[i]);\nconsole.log(Math.floor(total / n));\n"
    },
    "time_limit_ms": 2000,
    "memory_limit_kb": 262144,
    "test_cases": [
      {"id":"t1","stdin":"5\n120\n250\n80\n310\n195","expected":"191","hidden":false,"weight":1},
      {"id":"t2","stdin":"3\n100\n200\n300","expected":"200","hidden":true,"weight":1},
      {"id":"t3","stdin":"1\n500","expected":"500","hidden":true,"weight":1},
      {"id":"t4","stdin":"4\n333\n667\n250\n750","expected":"500","hidden":true,"weight":1}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q7-5: subjective, expert, 5 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000057005','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','subjective',
  'Liveness vs readiness vs startup probes','expert',5,ARRAY['k8s','probes','health','reliability'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000057105','00000000-0000-0000-0000-000000057005',1,
  $json${
    "prompt": "Explain the three Kubernetes container probes: liveness, readiness, and startup. Your answer must cover: (1) what action kubelet takes when each probe fails, (2) the interaction between startup probe and liveness/readiness probes, (3) when you would use each probe in a production service, and (4) why setting liveness probe thresholds too aggressively can cause cascading failures.",
    "word_limit": 450,
    "rubric": [
      {"criterion":"Failure actions","weight":0.25,"description":"Liveness failure: kubelet restarts the container (subject to restartPolicy). Readiness failure: pod is removed from Service Endpoints — traffic stops but container keeps running. Startup failure: same as liveness (restart), but only fires until the probe succeeds the first time"},
      {"criterion":"Startup probe interaction","weight":0.25,"description":"While startup probe is in progress, liveness and readiness probes are disabled. Once startup probe passes, both activate. Allows slow-starting apps to not be killed by liveness before they are ready"},
      {"criterion":"When to use each","weight":0.25,"description":"Liveness: detect deadlocks or hung processes that can't self-recover. Readiness: signal temporary unreadiness (cache warming, dependency unavailable) without restarting. Startup: slow-booting apps (JVM, model loading) needing a grace period"},
      {"criterion":"Cascading failure risk","weight":0.25,"description":"Aggressive liveness (low failureThreshold, short periodSeconds) can restart pods under transient load spikes, causing a stampede: restarted pods fail to acquire connections, more restarts, Endpoints churn causes traffic spikes on remaining pods, cascading OOM/OOMKill cluster-wide"}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- QUIZ 8 — CKA Exam Preparation (5 questions, total 20 pts)
-- ════════════════════════════════════════════════════════════════════════════

-- Q8-1: MCQ single, expert, 3 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000058001','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Correct kubeadm cluster upgrade order','expert',3,ARRAY['k8s','kubeadm','upgrade','cka'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000058101','00000000-0000-0000-0000-000000058001',1,
  $json${
    "prompt": "When upgrading a kubeadm-managed cluster from v1.30 to v1.31, what is the correct sequence of operations?",
    "multiple": false,
    "options": [
      {"id":"a","text":"1. Upgrade all worker nodes first, 2. Upgrade kubeadm on control plane, 3. Run kubeadm upgrade apply, 4. Upgrade kubelet/kubectl on control plane","is_correct":false},
      {"id":"b","text":"1. Upgrade kubeadm on control plane node, 2. Run kubeadm upgrade apply v1.31.x, 3. Upgrade kubelet and kubectl on control plane, 4. Drain and upgrade each worker node one at a time, 5. Uncordon each worker","is_correct":true},
      {"id":"c","text":"1. Download new container images on all nodes simultaneously, 2. Rolling restart all control plane pods, 3. Upgrade kubelet on all nodes at once","is_correct":false},
      {"id":"d","text":"1. Update the cluster-info ConfigMap, 2. Restart kube-apiserver, 3. kubeadm automatically upgrades all other components","is_correct":false}
    ],
    "explanation":"kubeadm upgrade sequence: (1) Upgrade kubeadm binary on control plane, (2) `kubeadm upgrade apply vX.Y.Z` — upgrades control plane components (apiserver, scheduler, controller-manager, etcd), (3) Upgrade kubelet+kubectl on control plane and restart kubelet, (4) For each worker: drain node, upgrade kubeadm/kubelet/kubectl, `kubeadm upgrade node`, restart kubelet, uncordon. Never skip minor versions."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q8-2: MCQ multiple, expert, 4 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000058002','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Required etcdctl snapshot backup flags','expert',4,ARRAY['k8s','etcd','backup','cka'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000058102','00000000-0000-0000-0000-000000058002',1,
  $json${
    "prompt": "Which flags are required when running `ETCDCTL_API=3 etcdctl snapshot save` against a TLS-secured etcd cluster?",
    "multiple": true,
    "options": [
      {"id":"a","text":"--endpoints (etcd server address)","is_correct":true},
      {"id":"b","text":"--cacert (CA certificate to verify the etcd server)","is_correct":true},
      {"id":"c","text":"--cert and --key (client certificate and key for mutual TLS auth)","is_correct":true},
      {"id":"d","text":"--compression-level (to reduce backup file size)","is_correct":false}
    ],
    "explanation":"A TLS-secured etcd requires: --endpoints (e.g. https://127.0.0.1:2379), --cacert (path to etcd CA cert to verify server identity), --cert and --key (client cert/key for mTLS authentication). --compression-level is not a real etcdctl flag. In kubeadm clusters, these certs are at /etc/kubernetes/pki/etcd/."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q8-3: MCQ single, expert, 3 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000058003','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'kubectl drain vs kubectl cordon','expert',3,ARRAY['k8s','maintenance','drain','cordon','cka'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000058103','00000000-0000-0000-0000-000000058003',1,
  $json${
    "prompt": "What does `kubectl drain` do in addition to what `kubectl cordon` does?",
    "multiple": false,
    "options": [
      {"id":"a","text":"drain terminates all pods immediately without respecting PodDisruptionBudgets; cordon only marks the node as unschedulable","is_correct":false},
      {"id":"b","text":"drain marks the node unschedulable (same as cordon) AND evicts all pods gracefully, respecting PodDisruptionBudgets and grace periods — pods backed by controllers are rescheduled elsewhere","is_correct":true},
      {"id":"c","text":"drain deletes the node from the cluster permanently; cordon is reversible with uncordon","is_correct":false},
      {"id":"d","text":"drain and cordon are identical — they both only add the node.kubernetes.io/unschedulable taint","is_correct":false}
    ],
    "explanation":"cordon: adds the node.kubernetes.io/unschedulable taint and marks node.spec.unschedulable=true, preventing new pods from being scheduled. drain: does all of the above PLUS evicts running pods gracefully (DELETE on each pod, respecting terminationGracePeriodSeconds and PodDisruptionBudgets). DaemonSet pods and mirror pods are ignored by drain unless --ignore-daemonsets is set."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q8-4: coding, expert, 5 pts — etcd backup size estimation
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000058004','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','coding',
  'Estimate etcd snapshot size in KiB','expert',5,ARRAY['k8s','etcd','backup','math'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000058104','00000000-0000-0000-0000-000000058004',1,
  $json${
    "prompt": "A simplified etcd backup size model: given N objects and S bytes per object, total size = N * S bytes. Output the size in **KiB** (integer, floor division by 1024).\n\nInput: two space-separated integers `N S`\nOutput: one integer (size in KiB)\n\n**Example:**\n```\n100 4096\n```\nOutput: `400`  (100 * 4096 = 409600 bytes = 400 KiB)",
    "languages": ["python","javascript"],
    "starter_code": {
      "python": "n, s = map(int, input().split())\nprint((n * s) // 1024)\n",
      "javascript": "const [n, s] = require('fs').readFileSync(0,'utf8').trim().split(' ').map(Number);\nconsole.log(Math.floor((n * s) / 1024));\n"
    },
    "time_limit_ms": 2000,
    "memory_limit_kb": 262144,
    "test_cases": [
      {"id":"t1","stdin":"100 4096","expected":"400","hidden":false,"weight":1},
      {"id":"t2","stdin":"1000 2048","expected":"2000","hidden":true,"weight":1},
      {"id":"t3","stdin":"5000 512","expected":"2500","hidden":true,"weight":1},
      {"id":"t4","stdin":"1 1023","expected":"0","hidden":true,"weight":1}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q8-5: subjective, expert, 5 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000058005','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','subjective',
  'Restore Kubernetes control plane from etcd snapshot','expert',5,ARRAY['k8s','etcd','restore','disaster-recovery','cka'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000058105','00000000-0000-0000-0000-000000058005',1,
  $json${
    "prompt": "Describe the complete procedure to restore a kubeadm-managed Kubernetes cluster from an etcd snapshot backup. Include: (1) which services to stop before restore and why, (2) the exact etcdctl command with all required flags, (3) what to update after restore so the control plane reconnects to the restored etcd data directory, and (4) verification steps to confirm the cluster returned to the expected state.",
    "word_limit": 600,
    "rubric": [
      {"criterion":"Pre-restore service shutdown","weight":0.25,"description":"Stop kube-apiserver, kube-controller-manager, kube-scheduler, and etcd (move their static pod manifests out of /etc/kubernetes/manifests/ to stop kubelet from running them). Avoids split-brain between old etcd data and restored data"},
      {"criterion":"etcdctl restore command","weight":0.30,"description":"ETCDCTL_API=3 etcdctl snapshot restore /path/to/backup.db --data-dir=/var/lib/etcd-restored --name=<node-name> --initial-cluster=<node-name>=https://<ip>:2380 --initial-advertise-peer-urls=https://<ip>:2380. The restored data-dir replaces the old /var/lib/etcd"},
      {"criterion":"Control plane reconnection","weight":0.25,"description":"Update etcd static pod manifest (etcd.yaml) to point --data-dir at the restored directory. Move manifests back to /etc/kubernetes/manifests/. kubelet restarts all control plane pods. The kube-apiserver reconnects to the restored etcd"},
      {"criterion":"Verification","weight":0.20,"description":"kubectl get nodes shows expected node count. kubectl get pods -A shows workloads from the backup snapshot time. etcdctl endpoint health confirms etcd cluster is healthy. Check cluster-info and version match expectations"}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;
