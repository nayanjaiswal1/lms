-- ════════════════════════════════════════════════════════════════════════════
-- k8s_03_questions_q3q4.sql — Questions for Quiz 3 (Networking) & Quiz 4 (Storage)
-- Assessment 000000060003 and 000000060004
-- ════════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════════
-- QUIZ 3 — Networking & Services (5 questions, total 17 pts)
-- ════════════════════════════════════════════════════════════════════════════

-- Q3-1: MCQ single, intermediate, 2 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000053001','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'ClusterIP vs NodePort service types','intermediate',2,ARRAY['k8s','services','networking'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000053101','00000000-0000-0000-0000-000000053001',1,
  $json${
    "prompt": "What is the key difference between a ClusterIP and a NodePort service in Kubernetes?",
    "multiple": false,
    "options": [
      {"id":"a","text":"ClusterIP is faster because it bypasses iptables; NodePort uses iptables rules","is_correct":false},
      {"id":"b","text":"ClusterIP is only reachable within the cluster; NodePort additionally opens a static port on every node's IP, making the service reachable from outside the cluster","is_correct":true},
      {"id":"c","text":"ClusterIP supports TCP only; NodePort supports both TCP and UDP","is_correct":false},
      {"id":"d","text":"NodePort is deprecated in Kubernetes 1.28 and replaced by Gateway API","is_correct":false}
    ],
    "explanation":"ClusterIP assigns a virtual IP reachable only inside the cluster. NodePort builds on ClusterIP and additionally binds a port (30000-32767) on every node. External traffic hits <NodeIP>:<NodePort> and kube-proxy forwards it to the ClusterIP, which distributes to pods."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q3-2: MCQ multiple, advanced, 3 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000053002','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Kubernetes networking model requirements','advanced',3,ARRAY['k8s','networking','cni'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000053102','00000000-0000-0000-0000-000000053002',1,
  $json${
    "prompt": "Select all requirements that are part of the Kubernetes networking model that every CNI plugin must satisfy.",
    "multiple": true,
    "options": [
      {"id":"a","text":"Every pod gets its own unique IP address","is_correct":true},
      {"id":"b","text":"Pods on the same node can communicate without NAT","is_correct":true},
      {"id":"c","text":"Pods on different nodes must communicate through a load balancer","is_correct":false},
      {"id":"d","text":"Agents on a node (e.g., kubelet) can communicate with all pods on that node without NAT","is_correct":true}
    ],
    "explanation":"The Kubernetes networking model requires: all pods can communicate with all other pods without NAT; nodes can communicate with all pods without NAT; the IP a pod sees for itself is the same IP others use to reach it. CNI plugins (Calico, Flannel, Cilium, etc.) implement this — it does NOT require a load balancer between nodes."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q3-3: MCQ single, advanced, 2 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000053003','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'kube-proxy default load balancing mechanism','advanced',2,ARRAY['k8s','kube-proxy','iptables'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000053103','00000000-0000-0000-0000-000000053003',1,
  $json${
    "prompt": "What mechanism does kube-proxy use by default (in most managed Kubernetes distributions) to implement Service load balancing and virtual IP routing?",
    "multiple": false,
    "options": [
      {"id":"a","text":"Userspace proxying — kube-proxy accepts connections and forwards them to backend pods","is_correct":false},
      {"id":"b","text":"iptables rules — kube-proxy programs NAT rules in the kernel's netfilter subsystem to DNAT traffic to a randomly selected pod endpoint","is_correct":true},
      {"id":"c","text":"IPVS virtual servers — kube-proxy creates L4 load balancer entries in the Linux Virtual Server module","is_correct":false},
      {"id":"d","text":"eBPF programs — kube-proxy attaches XDP hooks at the NIC driver level to bypass the kernel stack","is_correct":false}
    ],
    "explanation":"iptables is the historical default. kube-proxy watches Services and Endpoints, then writes iptables PREROUTING/OUTPUT chain rules that DNAT ClusterIP traffic to a randomly chosen pod IP. IPVS mode is available but not the default everywhere. eBPF (used by Cilium in kube-proxy replacement mode) requires disabling kube-proxy entirely."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q3-4: coding, intermediate, 5 pts — filter services by port
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000053004','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','coding',
  'Filter Kubernetes services by port number','intermediate',5,ARRAY['k8s','services','parsing'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000053104','00000000-0000-0000-0000-000000053004',1,
  $json${
    "prompt": "You receive simplified `kubectl get svc` output. First line is N (service count). Each line is `NAME TYPE PORT`. Print the names of all services on port **443**, one per line, in input order.\n\n**Example:**\n```\n5\napi-svc ClusterIP 443\nweb-svc NodePort 80\nssl-svc ClusterIP 443\ndb-svc ClusterIP 5432\ncache-svc ClusterIP 6379\n```\nOutput:\n```\napi-svc\nssl-svc\n```",
    "languages": ["python","javascript"],
    "starter_code": {
      "python": "n = int(input())\nfor _ in range(n):\n    name, stype, port = input().split()\n    if port == '443':\n        print(name)\n",
      "javascript": "const lines = require('fs').readFileSync(0,'utf8').trim().split('\\n');\nconst n = parseInt(lines[0]);\nfor (let i = 1; i <= n; i++) {\n  const [name, , port] = lines[i].trim().split(/\\s+/);\n  if (port === '443') console.log(name);\n}\n"
    },
    "time_limit_ms": 2000,
    "memory_limit_kb": 262144,
    "test_cases": [
      {"id":"t1","stdin":"5\napi-svc ClusterIP 443\nweb-svc NodePort 80\nssl-svc ClusterIP 443\ndb-svc ClusterIP 5432\ncache-svc ClusterIP 6379","expected":"api-svc\nssl-svc","hidden":false,"weight":1},
      {"id":"t2","stdin":"3\nfront NodePort 80\nback ClusterIP 8080\nmonitor ClusterIP 443","expected":"monitor","hidden":true,"weight":1},
      {"id":"t3","stdin":"2\nfoo ClusterIP 80\nbar ClusterIP 8080","expected":"","hidden":true,"weight":1},
      {"id":"t4","stdin":"1\nhttps-svc ClusterIP 443","expected":"https-svc","hidden":true,"weight":1}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q3-5: subjective, advanced, 5 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000053005','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','subjective',
  'CNI plugin architecture and kubelet integration','advanced',5,ARRAY['k8s','cni','networking'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000053105','00000000-0000-0000-0000-000000053005',1,
  $json${
    "prompt": "Describe the CNI (Container Network Interface) plugin architecture in Kubernetes. Your answer must include: (1) how kubelet invokes a CNI plugin when a pod is scheduled, (2) what the CNI plugin is responsible for (veth pair creation, IP allocation, routing), (3) the role of IPAM (IP Address Management) plugins, and (4) how a pod communicates with another pod on a different node (using any specific CNI example such as Flannel VXLAN or Calico BGP).",
    "word_limit": 500,
    "rubric": [
      {"criterion":"kubelet invocation mechanism","weight":0.25,"description":"kubelet calls the CNI binary (found in /opt/cni/bin) via exec, passing pod namespace/name/container ID and the network config from /etc/cni/net.d/"},
      {"criterion":"CNI plugin responsibilities","weight":0.30,"description":"Creates a veth pair (one end in pod netns, one on host), assigns IP from IPAM, sets up routes and default gateway in pod namespace"},
      {"criterion":"IPAM role","weight":0.20,"description":"IPAM plugin (host-local, DHCP, or Whereabouts) tracks which IPs are allocated per node and returns an available IP with subnet/gateway config"},
      {"criterion":"Cross-node communication","weight":0.25,"description":"Correct description of one encapsulation/routing mechanism: Flannel VXLAN wraps pod packets in UDP and decaps on the destination node; Calico BGP advertises pod CIDRs as routes so packets are routed natively without encapsulation"}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- QUIZ 4 — Storage & Configuration (5 questions, total 17 pts)
-- ════════════════════════════════════════════════════════════════════════════

-- Q4-1: MCQ single, intermediate, 2 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000054001','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'PersistentVolume access mode for multi-node read-write','intermediate',2,ARRAY['k8s','storage','pv','pvc'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000054101','00000000-0000-0000-0000-000000054001',1,
  $json${
    "prompt": "Which PersistentVolume access mode must a volume support to be mounted as read-write by multiple nodes simultaneously?",
    "multiple": false,
    "options": [
      {"id":"a","text":"ReadWriteOnce (RWO)","is_correct":false},
      {"id":"b","text":"ReadOnlyMany (ROX)","is_correct":false},
      {"id":"c","text":"ReadWriteMany (RWX)","is_correct":true},
      {"id":"d","text":"ReadWriteOncePod (RWOP)","is_correct":false}
    ],
    "explanation":"ReadWriteMany (RWX) allows the volume to be mounted read-write by many nodes at once. RWO restricts to one node. ROX allows read-only from many nodes. RWOP (added in 1.22) restricts to a single pod. NFS and CephFS support RWX; most cloud block volumes only support RWO."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q4-2: MCQ multiple, advanced, 3 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000054002','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'Valid ways to pass configuration data to a Pod','advanced',3,ARRAY['k8s','configmap','secret','env'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000054102','00000000-0000-0000-0000-000000054002',1,
  $json${
    "prompt": "Select all mechanisms that are valid for injecting configuration data into a running Kubernetes Pod.",
    "multiple": true,
    "options": [
      {"id":"a","text":"ConfigMap mounted as a volume (each key becomes a file)","is_correct":true},
      {"id":"b","text":"Secret values injected as environment variables via envFrom","is_correct":true},
      {"id":"c","text":"Directly editing the container filesystem at runtime via kubectl patch","is_correct":false},
      {"id":"d","text":"Downward API volumes exposing pod metadata (labels, annotations, resource limits) as files","is_correct":true}
    ],
    "explanation":"ConfigMaps and Secrets can be consumed as environment variables or mounted as volumes. The Downward API exposes pod and node metadata to containers as files or env vars. `kubectl patch` updates the Kubernetes API object spec but cannot directly write into a running container's filesystem."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q4-3: MCQ single, advanced, 2 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000054003','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','mcq',
  'PVC behavior when PV is deleted with Retain reclaim policy','advanced',2,ARRAY['k8s','pvc','pv','reclaim'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000054103','00000000-0000-0000-0000-000000054003',1,
  $json${
    "prompt": "A PersistentVolumeClaim is bound to a PersistentVolume with `persistentVolumeReclaimPolicy: Retain`. The PV is then manually deleted by an admin. What is the state of the PVC?",
    "multiple": false,
    "options": [
      {"id":"a","text":"The PVC is also automatically deleted since the bound PV no longer exists","is_correct":false},
      {"id":"b","text":"The PVC transitions to Lost state — it is still present in the API but no longer bound, and pods using it will fail to mount","is_correct":true},
      {"id":"c","text":"Kubernetes automatically rebinds the PVC to another available PV with matching storage class and access mode","is_correct":false},
      {"id":"d","text":"The PVC remains Bound indefinitely because the Retain policy prevents changes to both PV and PVC","is_correct":false}
    ],
    "explanation":"When a bound PV is deleted, the PVC transitions to Lost. The Retain policy affects what happens to the underlying storage when the PVC is deleted (the storage is not reclaimed), not what happens when the PV itself is deleted. Lost PVCs must be manually recovered by an admin who creates a new PV and rebinds."
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q4-4: coding, intermediate, 5 pts — ConfigMap key lookup
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000054004','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','coding',
  'ConfigMap key-value lookup','intermediate',5,ARRAY['k8s','configmap','parsing'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000054104','00000000-0000-0000-0000-000000054004',1,
  $json${
    "prompt": "You receive a simplified ConfigMap dump. First line is N (number of key-value pairs). Each of the following N lines is `KEY=VALUE`. The last line is a key to look up. Print the value, or `NOT_FOUND` if the key does not exist.\n\n**Example:**\n```\n3\nDB_HOST=postgres.default.svc\nDB_PORT=5432\nDB_NAME=appdb\nDB_PORT\n```\nOutput: `5432`",
    "languages": ["python","javascript"],
    "starter_code": {
      "python": "n = int(input())\nconfig = {}\nfor _ in range(n):\n    k, v = input().split('=', 1)\n    config[k] = v\nprint(config.get(input(), 'NOT_FOUND'))\n",
      "javascript": "const lines = require('fs').readFileSync(0,'utf8').trim().split('\\n');\nconst n = parseInt(lines[0]);\nconst config = {};\nfor (let i = 1; i <= n; i++) {\n  const idx = lines[i].indexOf('=');\n  config[lines[i].slice(0,idx)] = lines[i].slice(idx+1);\n}\nconsole.log(config[lines[n+1]] ?? 'NOT_FOUND');\n"
    },
    "time_limit_ms": 2000,
    "memory_limit_kb": 262144,
    "test_cases": [
      {"id":"t1","stdin":"3\nDB_HOST=postgres.default.svc\nDB_PORT=5432\nDB_NAME=appdb\nDB_PORT","expected":"5432","hidden":false,"weight":1},
      {"id":"t2","stdin":"2\nAPP_ENV=production\nLOG_LEVEL=info\nAPP_ENV","expected":"production","hidden":true,"weight":1},
      {"id":"t3","stdin":"1\nFOO=bar\nBAZ","expected":"NOT_FOUND","hidden":true,"weight":1},
      {"id":"t4","stdin":"2\nURL=https://api.example.com/v2\nTIMEOUT=30\nURL","expected":"https://api.example.com/v2","hidden":true,"weight":1}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- Q4-5: subjective, advanced, 5 pts
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000054005','00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000050000','subjective',
  'StorageClass dynamic vs static PV provisioning','advanced',5,ARRAY['k8s','storage','storageclass','pv'],1,
  '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000054105','00000000-0000-0000-0000-000000054005',1,
  $json${
    "prompt": "Compare StorageClass-based **dynamic provisioning** with **static PersistentVolume provisioning** in Kubernetes. Cover: (1) how each approach works (who creates the PV), (2) how binding occurs in each case, (3) at least two trade-offs between the approaches for production use, and (4) when you would choose static provisioning over dynamic even if a dynamic provisioner is available.",
    "word_limit": 450,
    "rubric": [
      {"criterion":"Provisioning mechanism","weight":0.25,"description":"Static: admin pre-creates PVs; PVC binds to a matching available PV. Dynamic: PVC references a StorageClass; the provisioner (e.g. aws-ebs-csi) creates the PV and backing storage automatically on PVC creation"},
      {"criterion":"Binding process","weight":0.20,"description":"Static binding: kube-controller-manager matches PVC to PV by accessMode, storageClassName, and capacity. Dynamic: StorageClass provisioner creates the PV with exactly the PVC's requested size, then binding is immediate"},
      {"criterion":"Trade-offs","weight":0.30,"description":"Dynamic: self-service, no admin bottleneck, exact size allocation, but cost risk from over-provisioning and orphaned volumes. Static: precise cost control and pre-validated storage, but operational overhead and capacity planning required"},
      {"criterion":"When to prefer static","weight":0.25,"description":"Any valid scenario: compliance requires pre-approved storage tiers; migrating data from existing block volumes; high-performance volumes needing specific IOPS provisioned in advance; airgapped environments without cloud API access"}
    ]
  }$json$::jsonb,'00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;
