-- ════════════════════════════════════════════════════════════════════════════
-- k8s_02_questions_q1q2.sql — Questions for Quiz 1 (Fundamentals) & Quiz 2 (Workloads)
-- Assessment 000000060001 and 000000060002
-- ════════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════════
-- QUIZ 1 — Kubernetes Fundamentals (5 questions, total 17 pts)
-- ════════════════════════════════════════════════════════════════════════════

-- Q1-1: MCQ single, intermediate, 2 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000051001','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Kubernetes Pod definition','intermediate',2,ARRAY['k8s','pod','fundamentals'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000051101','00000000-0000-0000-0000-000000051001',1,
  $json${
    "prompt": "Which of the following best describes a Kubernetes Pod?",
    "multiple": false,
    "options": [
      {"id":"a","text":"A single container deployed directly on a host OS without any abstraction","is_correct":false},
      {"id":"b","text":"The smallest deployable unit in Kubernetes; one or more tightly coupled containers sharing the same network namespace, IP address, and storage volumes","is_correct":true},
      {"id":"c","text":"A logical grouping of worker nodes within a cluster","is_correct":false},
      {"id":"d","text":"A configuration template that defines container images and restart policies","is_correct":false}
    ],
    "explanation":"A Pod is Kubernetes' smallest deployable unit. All containers in a Pod share the same IP, port space, and localhost, and can share mounted volumes. Pods are ephemeral — they are not self-healing; controllers like Deployments manage that."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q1-2: MCQ multiple, intermediate, 3 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000051002','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Valid Kubernetes Pod phases','intermediate',3,ARRAY['k8s','pod','lifecycle'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000051102','00000000-0000-0000-0000-000000051002',1,
  $json${
    "prompt": "Select all phases that are part of the official Kubernetes Pod lifecycle.",
    "multiple": true,
    "options": [
      {"id":"a","text":"Pending","is_correct":true},
      {"id":"b","text":"Running","is_correct":true},
      {"id":"c","text":"Succeeded","is_correct":true},
      {"id":"d","text":"Initializing","is_correct":false}
    ],
    "explanation":"Valid Pod phases: Pending, Running, Succeeded, Failed, Unknown. 'Initializing' is not a phase — init containers running is represented within the Pending phase via the Pod's containerStatuses."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q1-3: MCQ single, advanced, 2 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000051003','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Init container execution guarantee','advanced',2,ARRAY['k8s','pod','init-container'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000051103','00000000-0000-0000-0000-000000051003',1,
  $json${
    "prompt": "What does Kubernetes guarantee about init containers before starting main application containers?",
    "multiple": false,
    "options": [
      {"id":"a","text":"Init containers run in parallel with app containers to reduce total startup time","is_correct":false},
      {"id":"b","text":"Init containers run sequentially to completion — each must exit 0 before the next starts, and all must complete before any app container starts","is_correct":true},
      {"id":"c","text":"Init containers share the same PID namespace as the main containers and can signal them","is_correct":false},
      {"id":"d","text":"Init containers are skipped if the node is under memory pressure and a QoS eviction is pending","is_correct":false}
    ],
    "explanation":"Init containers always complete before app containers start. They run sequentially — a failure causes kubelet to restart that init container (subject to the Pod's restartPolicy). They have separate resource accounting and their filesystems are isolated from app containers unless volumes are shared."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q1-4: coding, advanced, 5 pts — compute total CPU millicores from kubectl top output
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000051004','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','coding',
  'Sum pod CPU millicores from metrics output','advanced',5,ARRAY['k8s','resources','parsing'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000051104','00000000-0000-0000-0000-000000051004',1,
  $json${
    "prompt": "You receive simplified `kubectl top pods` output. The first line is N (number of pods). Each following line is `NAME CPU MEMORY` where CPU ends with `m` (millicores) and MEMORY ends with `Mi` or `Gi`.\n\nPrint the **total CPU in millicores** as a single integer.\n\n**Example:**\n```\n3\nnginx-abc 100m 128Mi\napi-xyz 250m 512Mi\ndb-pod 500m 1Gi\n```\nOutput: `850`",
    "languages": ["python","javascript"],
    "starter_code": {
      "python": "import sys\nlines = sys.stdin.read().split('\\n')\nn = int(lines[0])\ntotal = 0\nfor i in range(1, n + 1):\n    parts = lines[i].split()\n    total += int(parts[1].rstrip('m'))\nprint(total)\n",
      "javascript": "const lines = require('fs').readFileSync(0,'utf8').trim().split('\\n');\nconst n = parseInt(lines[0]);\nlet total = 0;\nfor (let i = 1; i <= n; i++) {\n  const parts = lines[i].trim().split(/\\s+/);\n  total += parseInt(parts[1]);\n}\nconsole.log(total);\n"
    },
    "time_limit_ms": 2000,
    "memory_limit_kb": 262144,
    "test_cases": [
      {"id":"t1","stdin":"3\nnginx-abc 100m 128Mi\napi-xyz 250m 512Mi\ndb-pod 500m 1Gi","expected":"850","hidden":false,"weight":1},
      {"id":"t2","stdin":"1\nsingle-pod 750m 256Mi","expected":"750","hidden":true,"weight":1},
      {"id":"t3","stdin":"5\nweb-1 200m 512Mi\nweb-2 200m 512Mi\napi-1 400m 1Gi\napi-2 400m 1Gi\ndb-1 1000m 4Gi","expected":"2200","hidden":true,"weight":1},
      {"id":"t4","stdin":"2\ncache 50m 64Mi\nmonitor 125m 128Mi","expected":"175","hidden":true,"weight":1}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q1-5: subjective, advanced, 5 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000051005','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','subjective',
  'Resource requests vs limits in Kubernetes','advanced',5,ARRAY['k8s','resources','qos','scheduling'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000051105','00000000-0000-0000-0000-000000051005',1,
  $json${
    "prompt": "Explain the difference between resource **requests** and **limits** in Kubernetes. Cover: (1) how requests influence scheduling, (2) how CPU and memory limits are enforced differently at runtime, (3) the three QoS classes (Guaranteed, Burstable, BestEffort) and when each is assigned, and (4) what happens when a container exceeds its memory limit versus its CPU limit.",
    "word_limit": 400,
    "rubric": [
      {"criterion":"Scheduling role of requests","weight":0.25,"description":"kube-scheduler sums requests on a node against its allocatable capacity; only nodes with sufficient remaining capacity are candidates"},
      {"criterion":"CPU throttling vs OOM kill","weight":0.30,"description":"CPU is compressible — cgroups throttle the container when it exceeds the limit. Memory is not compressible — kernel OOMKills the container when it exceeds the limit"},
      {"criterion":"QoS classes","weight":0.30,"description":"Guaranteed: requests == limits for all containers. Burstable: at least one container has requests < limits. BestEffort: no requests or limits set. Eviction order: BestEffort first"},
      {"criterion":"Practical implications","weight":0.15,"description":"Mentions at least one production concern such as noisy-neighbor CPU contention, OOM risk with Java heap sizing, or vertical pod autoscaler integration"}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- QUIZ 2 — Workloads & Controllers (5 questions, total 17 pts)
-- ════════════════════════════════════════════════════════════════════════════

-- Q2-1: MCQ single, intermediate, 2 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000052001','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Default RollingUpdate maxSurge value','intermediate',2,ARRAY['k8s','deployment','rolling-update'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000052101','00000000-0000-0000-0000-000000052001',1,
  $json${
    "prompt": "When a Deployment's `.spec.strategy.type` is `RollingUpdate` and no explicit `maxSurge` is configured, what is the default value?",
    "multiple": false,
    "options": [
      {"id":"a","text":"0 (no extra pods during the rollout)","is_correct":false},
      {"id":"b","text":"25% (rounded up)","is_correct":true},
      {"id":"c","text":"50%","is_correct":false},
      {"id":"d","text":"1 (exactly one extra pod at a time)","is_correct":false}
    ],
    "explanation":"Both `maxSurge` and `maxUnavailable` default to 25%. For a 4-replica Deployment, maxSurge=1 (ceil(25%)) meaning at most 5 pods can exist during a rollout, and maxUnavailable=1 meaning at least 3 pods must be available."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q2-2: MCQ multiple, advanced, 3 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000052002','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Controllers that run pods on every node','advanced',3,ARRAY['k8s','daemonset','controllers'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000052102','00000000-0000-0000-0000-000000052002',1,
  $json${
    "prompt": "Select all controllers that are typically used when you need exactly one pod instance running on every (eligible) node in the cluster.",
    "multiple": true,
    "options": [
      {"id":"a","text":"DaemonSet","is_correct":true},
      {"id":"b","text":"Deployment","is_correct":false},
      {"id":"c","text":"StatefulSet","is_correct":false},
      {"id":"d","text":"DaemonSet with node affinity rules to restrict which nodes qualify","is_correct":true}
    ],
    "explanation":"DaemonSet guarantees one pod per qualifying node (all nodes by default, or a subset via node selectors/affinity). Deployments and StatefulSets manage a fixed replica count spread across available nodes — they don't guarantee one-per-node placement."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q2-3: MCQ single, advanced, 2 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000052003','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Deployment revision history and rollback','advanced',2,ARRAY['k8s','deployment','rollback'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000052103','00000000-0000-0000-0000-000000052003',1,
  $json${
    "prompt": "A Deployment has `revisionHistoryLimit: 3` and has been updated 10 times. How many old ReplicaSets are kept, and what happens when `kubectl rollout undo` is run?",
    "multiple": false,
    "options": [
      {"id":"a","text":"10 ReplicaSets are kept; undo recreates the very first revision","is_correct":false},
      {"id":"b","text":"3 old (scaled-to-zero) ReplicaSets are kept; undo scales up the immediately previous revision's ReplicaSet and scales down the current one","is_correct":true},
      {"id":"c","text":"All ReplicaSets are deleted after a rollout completes; rollback is not possible","is_correct":false},
      {"id":"d","text":"3 ReplicaSets are kept including the current one; undo can only go back 2 revisions","is_correct":false}
    ],
    "explanation":"revisionHistoryLimit controls how many old (scaled-to-zero) ReplicaSets are retained. The current active ReplicaSet is never counted against this limit. `kubectl rollout undo` switches to the REVISION-1 ReplicaSet by scaling it up and the current down, using the same RollingUpdate strategy."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q2-4: coding, intermediate, 5 pts — max pods during rolling update
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000052004','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','coding',
  'Compute max pods during Deployment rolling update','intermediate',5,ARRAY['k8s','deployment','math'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000052104','00000000-0000-0000-0000-000000052004',1,
  $json${
    "prompt": "Given a Deployment with `replicas=D` and `maxSurge=S` (both absolute integers), compute the **maximum number of pods** that can exist simultaneously during the rolling update.\n\nInput: two space-separated integers `D S`\nOutput: one integer\n\n**Example:**\n```\n5 1\n```\nOutput: `6`",
    "languages": ["python","javascript"],
    "starter_code": {
      "python": "d, s = map(int, input().split())\nprint(d + s)\n",
      "javascript": "const [d, s] = require('fs').readFileSync(0,'utf8').trim().split(' ').map(Number);\nconsole.log(d + s);\n"
    },
    "time_limit_ms": 2000,
    "memory_limit_kb": 262144,
    "test_cases": [
      {"id":"t1","stdin":"5 1","expected":"6","hidden":false,"weight":1},
      {"id":"t2","stdin":"10 2","expected":"12","hidden":true,"weight":1},
      {"id":"t3","stdin":"3 1","expected":"4","hidden":true,"weight":1},
      {"id":"t4","stdin":"100 25","expected":"125","hidden":true,"weight":1}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q2-5: subjective, advanced, 5 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000052005','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','subjective',
  'Horizontal Pod Autoscaler mechanism and limitations','advanced',5,ARRAY['k8s','hpa','autoscaling'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000052105','00000000-0000-0000-0000-000000052005',1,
  $json${
    "prompt": "Explain how the Kubernetes Horizontal Pod Autoscaler (HPA) works. Your answer must cover: (1) the control loop sync period and how it fetches metrics, (2) the scaling formula and how the desired replica count is calculated, (3) the stabilization window and why it exists, and (4) at least two production limitations of HPA.",
    "word_limit": 450,
    "rubric": [
      {"criterion":"Control loop and metrics source","weight":0.25,"description":"HPA controller syncs every 15s (default), fetches metrics from metrics-server (resource metrics) or custom/external adapters via the metrics API"},
      {"criterion":"Scaling formula","weight":0.25,"description":"desiredReplicas = ceil(currentReplicas * (currentMetricValue / desiredMetricValue)); handles scale-down conservatively"},
      {"criterion":"Stabilization window","weight":0.25,"description":"Scale-down stabilization window (default 5 min) prevents thrashing by requiring the recommendation to be stable for the window duration before acting"},
      {"criterion":"Limitations","weight":0.25,"description":"Any two of: no scale-to-zero, metrics lag means reactive not predictive, requires metrics-server overhead, conflicts with VPA on resource requests, cold start latency on pod creation"}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;
