-- ════════════════════════════════════════════════════════════════════════════
-- k8s_04_questions_q5q6.sql — Questions for Quiz 5 (Cluster Admin) & Quiz 6 (Adv Networking)
-- Assessment 000000060005 and 000000060006
-- ════════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════════
-- QUIZ 5 — Cluster Administration (5 questions, total 20 pts)
-- ════════════════════════════════════════════════════════════════════════════

-- Q5-1: MCQ single, advanced, 3 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000055001','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'etcd quorum requirement for 5-node cluster','advanced',3,ARRAY['k8s','etcd','ha','quorum'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000055101','00000000-0000-0000-0000-000000055001',1,
  $json${
    "prompt": "A production Kubernetes cluster uses a dedicated 5-node etcd cluster. What is the minimum number of etcd members that must be healthy and reachable to maintain quorum, and how many simultaneous node failures can the cluster tolerate?",
    "multiple": false,
    "options": [
      {"id":"a","text":"Quorum requires 2 nodes; can tolerate 3 failures","is_correct":false},
      {"id":"b","text":"Quorum requires 3 nodes (majority of 5); can tolerate 2 simultaneous failures","is_correct":true},
      {"id":"c","text":"Quorum requires 4 nodes; can tolerate only 1 failure","is_correct":false},
      {"id":"d","text":"Quorum requires all 5 nodes; any failure halts the cluster","is_correct":false}
    ],
    "explanation":"etcd uses the Raft consensus algorithm. Quorum = floor(N/2) + 1. For N=5: floor(5/2)+1 = 3. So 3 healthy nodes maintain quorum and the cluster can lose up to 2 nodes. With N=3 you tolerate 1 failure; N=7 tolerates 3. Adding more than 7 etcd nodes increases write latency without fault-tolerance benefit."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q5-2: MCQ multiple, expert, 4 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000055002','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Valid Kubernetes audit policy log levels','expert',4,ARRAY['k8s','audit','security'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000055102','00000000-0000-0000-0000-000000055002',1,
  $json${
    "prompt": "Select all values that are valid audit log levels in a Kubernetes audit policy rule.",
    "multiple": true,
    "options": [
      {"id":"a","text":"None","is_correct":true},
      {"id":"b","text":"Metadata","is_correct":true},
      {"id":"c","text":"Request","is_correct":true},
      {"id":"d","text":"Verbose","is_correct":false}
    ],
    "explanation":"Kubernetes audit policy supports four log levels: None (don't log), Metadata (log request metadata — user, timestamp, verb, resource), Request (Metadata + request body), RequestResponse (Request + response body). 'Verbose' is not a valid level. Higher levels increase storage cost significantly."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q5-3: MCQ single, expert, 3 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000055003','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Kubernetes Node Authorizer purpose','expert',3,ARRAY['k8s','rbac','authorization','security'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000055103','00000000-0000-0000-0000-000000055003',1,
  $json${
    "prompt": "What is the primary purpose of the Node Authorizer in a Kubernetes cluster?",
    "multiple": false,
    "options": [
      {"id":"a","text":"It grants cluster-admin privileges to system:nodes group members for cross-namespace pod scheduling","is_correct":false},
      {"id":"b","text":"It authorizes kubelet API requests, limiting each node to read only the secrets, configmaps, PVCs, and pods scheduled on that specific node — preventing cross-node secret exfiltration","is_correct":true},
      {"id":"c","text":"It validates that nodes meet minimum resource requirements before admitting them to the cluster","is_correct":false},
      {"id":"d","text":"It controls which container images a node is permitted to pull based on OPA policies","is_correct":false}
    ],
    "explanation":"The Node Authorizer enforces node isolation at the API level. A compromised node's kubelet is limited to reading only the secrets/configmaps/PVCs bound to pods scheduled on that node. Without this, a single compromised node could read all secrets cluster-wide. It works in concert with NodeRestriction admission plugin for full isolation."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q5-4: coding, expert, 5 pts — count distinct cluster-admin subjects
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000055004','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','coding',
  'Count distinct cluster-admin subjects in RBAC bindings','expert',5,ARRAY['k8s','rbac','security','parsing'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000055104','00000000-0000-0000-0000-000000055004',1,
  $json${
    "prompt": "You receive simplified ClusterRoleBinding output. First line is N (number of entries). Each line is `ROLE SUBJECT`. Count the number of **distinct** subjects bound to the `cluster-admin` role.\n\n**Example:**\n```\n5\ncluster-admin alice\ncluster-admin bob\nedit carol\nview dave\ncluster-admin alice\n```\nOutput: `2`",
    "languages": ["python","javascript"],
    "starter_code": {
      "python": "n = int(input())\nadmins = set()\nfor _ in range(n):\n    parts = input().split()\n    if parts[0] == 'cluster-admin':\n        admins.add(parts[1])\nprint(len(admins))\n",
      "javascript": "const lines = require('fs').readFileSync(0,'utf8').trim().split('\\n');\nconst n = parseInt(lines[0]);\nconst admins = new Set();\nfor (let i = 1; i <= n; i++) {\n  const [role, subject] = lines[i].trim().split(/\\s+/);\n  if (role === 'cluster-admin') admins.add(subject);\n}\nconsole.log(admins.size);\n"
    },
    "time_limit_ms": 2000,
    "memory_limit_kb": 262144,
    "test_cases": [
      {"id":"t1","stdin":"5\ncluster-admin alice\ncluster-admin bob\nedit carol\nview dave\ncluster-admin alice","expected":"2","hidden":false,"weight":1},
      {"id":"t2","stdin":"3\nedit user1\nview user2\nedit user1","expected":"0","hidden":true,"weight":1},
      {"id":"t3","stdin":"4\ncluster-admin sa:default\ncluster-admin sa:default\ncluster-admin system:masters\ncluster-admin devops-team","expected":"3","hidden":true,"weight":1},
      {"id":"t4","stdin":"1\ncluster-admin root","expected":"1","hidden":true,"weight":1}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q5-5: subjective, expert, 5 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000055005','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','subjective',
  'Admission controller webhook lifecycle','expert',5,ARRAY['k8s','admission','webhooks','security'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000055105','00000000-0000-0000-0000-000000055005',1,
  $json${
    "prompt": "Describe the Kubernetes admission controller webhook lifecycle. Your answer must cover: (1) the order in which mutating vs validating webhooks run relative to built-in admission controllers, (2) the structure of an AdmissionReview request and response, (3) the difference between Fail and Ignore failurePolicy and when to use each, and (4) one security risk introduced by mutating webhooks and how to mitigate it.",
    "word_limit": 500,
    "rubric": [
      {"criterion":"Webhook execution order","weight":0.25,"description":"All MutatingAdmissionWebhooks run first (sequentially), then object is re-evaluated against schema, then all ValidatingAdmissionWebhooks run. Built-in controllers like NamespaceLifecycle run before webhooks"},
      {"criterion":"AdmissionReview structure","weight":0.25,"description":"API server sends AdmissionReview with request.uid, object (new), oldObject (for UPDATE), operation, userInfo. Webhook returns response.uid (same as request.uid), allowed bool, and optionally patch (base64 JSON patch) for mutating"},
      {"criterion":"failurePolicy semantics","weight":0.25,"description":"Fail: if webhook is unreachable or returns an error, the admission is denied — safe for security-critical webhooks. Ignore: failures are silently allowed through — appropriate for non-security advisory webhooks where availability matters more"},
      {"criterion":"Mutating webhook security risk","weight":0.25,"description":"A compromised or malicious mutating webhook can inject sidecars, environment variables, or hostPath mounts. Mitigate with: webhook namespace selector to exclude kube-system, timeoutSeconds to prevent DoS, TLS authentication, admission webhook policy auditing, or using OPA/Gatekeeper for immutable policies"}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- QUIZ 6 — Advanced Networking (5 questions, total 20 pts)
-- ════════════════════════════════════════════════════════════════════════════

-- Q6-1: MCQ single, advanced, 3 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000056001','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'eBPF CNI advantage over iptables-based CNI','advanced',3,ARRAY['k8s','ebpf','cilium','networking'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000056101','00000000-0000-0000-0000-000000056001',1,
  $json${
    "prompt": "What is a key capability that eBPF-based CNI plugins (like Cilium) provide that traditional iptables-based CNI plugins (like Flannel) cannot?",
    "multiple": false,
    "options": [
      {"id":"a","text":"eBPF plugins can assign multiple IP addresses per pod, enabling dual-stack IPv4/IPv6","is_correct":false},
      {"id":"b","text":"eBPF enables L7 (HTTP/gRPC) network policy enforcement and per-request observability without a sidecar proxy","is_correct":true},
      {"id":"c","text":"eBPF eliminates the need for a container runtime by managing namespaces directly in kernel space","is_correct":false},
      {"id":"d","text":"eBPF is the only approach that supports NetworkPolicy — iptables CNI plugins ignore NetworkPolicy objects","is_correct":false}
    ],
    "explanation":"eBPF programs can inspect and filter at L7 (parsing HTTP headers, gRPC methods, Kafka topics) in kernel space, enabling identity-aware microsegmentation without sidecar overhead. iptables operates only at L3/L4. Both support NetworkPolicy. Dual-stack is a Kubernetes feature independent of CNI choice."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q6-2: MCQ multiple, expert, 4 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000056002','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Components involved in Kubernetes DNS service discovery','expert',4,ARRAY['k8s','dns','coredns','networking'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000056102','00000000-0000-0000-0000-000000056002',1,
  $json${
    "prompt": "Select all components that play a role in Kubernetes DNS-based service discovery for a pod doing `nslookup api-svc.default.svc.cluster.local`.",
    "multiple": true,
    "options": [
      {"id":"a","text":"CoreDNS — receives the DNS query and resolves the service name to the ClusterIP","is_correct":true},
      {"id":"b","text":"kubelet — configures /etc/resolv.conf in each pod with the cluster DNS server and search domains","is_correct":true},
      {"id":"c","text":"kube-proxy — intercepts DNS queries and rewrites them before forwarding to CoreDNS","is_correct":false},
      {"id":"d","text":"Endpoints controller — maintains the Endpoints object that maps the Service to pod IPs","is_correct":true}
    ],
    "explanation":"DNS discovery chain: kubelet sets /etc/resolv.conf with nameserver=ClusterIP of kube-dns Service and search=default.svc.cluster.local svc.cluster.local cluster.local. The pod's resolver queries CoreDNS, which consults the Kubernetes plugin to return the Service ClusterIP. kube-proxy does not touch DNS traffic. The Endpoints object is needed for actual traffic forwarding after DNS resolves the ClusterIP."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q6-3: MCQ single, expert, 3 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000056003','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'IPVS vs iptables kube-proxy performance characteristics','expert',3,ARRAY['k8s','kube-proxy','ipvs','performance'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000056103','00000000-0000-0000-0000-000000056003',1,
  $json${
    "prompt": "How does kube-proxy in IPVS mode differ from iptables mode in terms of performance at scale?",
    "multiple": false,
    "options": [
      {"id":"a","text":"IPVS is slower because it requires a userspace daemon to forward packets between virtual servers","is_correct":false},
      {"id":"b","text":"IPVS uses hash tables for O(1) service lookup regardless of service count; iptables rules are evaluated linearly, causing latency to grow O(n) with the number of services","is_correct":true},
      {"id":"c","text":"IPVS eliminates the need for kube-proxy entirely — it operates purely in eBPF","is_correct":false},
      {"id":"d","text":"Both modes have identical performance; the difference is only in supported load-balancing algorithms","is_correct":false}
    ],
    "explanation":"In iptables mode, kube-proxy creates one rule per Service endpoint. With thousands of Services, the kernel must traverse the entire chain sequentially for each packet — O(n) lookup. IPVS (Linux Virtual Server) uses a kernel hash table, giving O(1) lookup per packet regardless of Service count. IPVS also supports richer LB algorithms: round-robin, least-connection, source-hash, etc."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q6-4: coding, expert, 5 pts — NetworkPolicy rule counter
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000056004','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','coding',
  'Find NetworkPolicy with the most total rules','expert',5,ARRAY['k8s','networkpolicy','parsing'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000056104','00000000-0000-0000-0000-000000056004',1,
  $json${
    "prompt": "You receive N lines of NetworkPolicy rule entries, each as `POLICY_NAME DIRECTION` (direction is `ingress` or `egress`). Find the policy with the most total rules. Output `NAME COUNT`. On tie, output the one that appears first.\n\n**Example:**\n```\n6\ndb-policy ingress\ndb-policy ingress\ndb-policy egress\nweb-policy ingress\nweb-policy egress\nweb-policy egress\n```\nOutput: `db-policy 3`",
    "languages": ["python","javascript"],
    "starter_code": {
      "python": "from collections import defaultdict\nn = int(input())\ncounts = defaultdict(int)\norder = []\nfor _ in range(n):\n    name, _ = input().split()\n    if name not in counts:\n        order.append(name)\n    counts[name] += 1\nbest = max(order, key=lambda x: counts[x])\nprint(best, counts[best])\n",
      "javascript": "const lines = require('fs').readFileSync(0,'utf8').trim().split('\\n');\nconst n = parseInt(lines[0]);\nconst counts = {};\nconst order = [];\nfor (let i = 1; i <= n; i++) {\n  const [name] = lines[i].trim().split(/\\s+/);\n  if (!(name in counts)) { counts[name] = 0; order.push(name); }\n  counts[name]++;\n}\nconst best = order.reduce((a,b) => counts[a] >= counts[b] ? a : b);\nconsole.log(best, counts[best]);\n"
    },
    "time_limit_ms": 2000,
    "memory_limit_kb": 262144,
    "test_cases": [
      {"id":"t1","stdin":"6\ndb-policy ingress\ndb-policy ingress\ndb-policy egress\nweb-policy ingress\nweb-policy egress\nweb-policy egress","expected":"db-policy 3","hidden":false,"weight":1},
      {"id":"t2","stdin":"4\nalpha ingress\nbeta egress\nalpha egress\nbeta ingress","expected":"alpha 2","hidden":true,"weight":1},
      {"id":"t3","stdin":"1\nsingle ingress","expected":"single 1","hidden":true,"weight":1},
      {"id":"t4","stdin":"3\np1 ingress\np2 ingress\np3 egress","expected":"p1 1","hidden":true,"weight":1}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q6-5: subjective, expert, 5 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000056005','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','subjective',
  'Kubernetes service discovery end-to-end','expert',5,ARRAY['k8s','dns','services','kube-proxy'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000056105','00000000-0000-0000-0000-000000056005',1,
  $json${
    "prompt": "Trace the complete path of a request from Pod A (in namespace `frontend`) making an HTTP call to `http://api-svc.backend.svc.cluster.local:8080`. Describe every component involved, from DNS resolution through packet forwarding to reaching the destination pod. Include: DNS search domain resolution, CoreDNS response, iptables/IPVS rules, Endpoints lookup, and connection establishment.",
    "word_limit": 600,
    "rubric": [
      {"criterion":"DNS resolution path","weight":0.25,"description":"Container's /etc/resolv.conf has search backend.svc.cluster.local svc.cluster.local cluster.local. The glibc/musl resolver appends each search domain. CoreDNS serves the A record for api-svc.backend.svc.cluster.local returning the Service ClusterIP"},
      {"criterion":"iptables/IPVS interception","weight":0.30,"description":"Packet destined for ClusterIP:8080 hits PREROUTING/OUTPUT chains. kube-proxy's iptables rules DNAT to one of the ready pod endpoints selected probabilistically (iptables) or via LB algorithm (IPVS). SNAT may be applied for return path"},
      {"criterion":"Endpoints and readiness","weight":0.25,"description":"kube-proxy watches Endpoints/EndpointSlices; only Ready pods are included. A pod is removed from endpoints when its readiness probe fails, preventing traffic to unhealthy pods"},
      {"criterion":"Connection establishment","weight":0.20,"description":"After DNAT, the packet arrives at the destination pod's veth interface with the original source IP preserved (or SNAT'd node IP for cross-node). TCP 3-way handshake completes with the destination container process bound to port 8080"}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;
