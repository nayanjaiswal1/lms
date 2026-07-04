-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-07-03T11:42:15Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: Fast Kubernetes ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, difficulty, tags, status, is_free, estimated_hours)
VALUES ('36d5d8be-468e-5eb6-b650-0f5c827cb390', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'Fast Kubernetes', 'fast-kubernetes', 'Course content imported and generated from the canonical markdown content pipeline for "Fast Kubernetes".', 'intermediate', ARRAY['kubernetes','k8s','devops','containers'], 'published', true, 16.2)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, tags=EXCLUDED.tags, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();

-- Section: Pod Fundamentals
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('375a87e0-e417-5b1c-8bc5-3852ed089e52', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Pod Fundamentals', 1)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes)
VALUES ('6d93934c-2315-5e0e-adcc-774073f33cd5', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '375a87e0-e417-5b1c-8bc5-3852ed089e52', 'Pod Fundamentals', 'notes', 0, $md$
## K8s CreatingPod Imperative

## LAB: K8s Creating Pod - Imperative Way

This scenario shows:
- how to create basic K8s pod using imperative commands,
- how to get more information about pod (to solve troubleshooting),
- how to run commands in pod,
- how to delete pod. 



### Steps

- Run minikube  (in this scenario, K8s runs on WSL2- Ubuntu 20.04)

  ![image](https://user-images.githubusercontent.com/10358317/153183333-371fe598-d5a4-4b86-9b5d-9e33f35063cc.png)

- Run pod in imperative way
  - "kubectl run **podName** --image=**imageName**"
  - "kubectl get pods -o wide" : get info about pods

  ![image](https://user-images.githubusercontent.com/10358317/153183932-f8cd1547-3b10-47af-be3a-a1aedbfcf4ad.png)

- Describe pod to get mor information about pods (when encountered troubleshooting):
  
  ![image](https://user-images.githubusercontent.com/10358317/153184743-b0617841-db71-4c02-8d7b-c0054d9249bd.png)
  
- To reach logs in the pod (when encountered troubleshooting):
  
  ![image](https://user-images.githubusercontent.com/10358317/153185140-e7c2a4e3-29d0-4636-9586-62eec358c6bb.png)

- To reach logs in the pod 2ith "-f" (LIVE Logs, attach to the pod's log):
  
  ![image](https://user-images.githubusercontent.com/10358317/153185353-1969fe8c-e166-492e-b55d-2d96cedf3709.png)
  
 - Run command on pod ("kubectl exec **podName** -- **command**"):
  
   ![image](https://user-images.githubusercontent.com/10358317/153185867-fbe27ddb-619d-4d3e-bbce-3f021c073ad8.png)
  
  - Entering into the pod and running bash or sh on pod:
    - "kubectl exec -it **podName** -- bash"
    - "kubectl exec -it **podName** -- /bins/sh"
    - exit from pods 2 ways:
      - "exit" command
      - "CTRL+P+Q"
 
    ![image](https://user-images.githubusercontent.com/10358317/153186349-4dff117c-66ca-46a9-8030-2bdf27e6e0bb.png)
  
- Delete pod:
  
  ![image](https://user-images.githubusercontent.com/10358317/153187052-d3b12b0d-85cb-4885-afa9-9a7904dc964b.png)

- Imperative way could be difficult to store and manage process. Every time we have to enter commands. To prevent this, we can use YAML file to define pods and pods' feature. This way is called Declerative Way.
  


## K8 CreatingPod Declerative

## LAB: K8s Creating Pod - Declarative Way (With Yaml File)

This scenario shows:
- how to create basic K8s pod using yaml file,
- how to get more information about pod (to solve troubleshooting),


### Steps

- Run minikube  (in this scenario, K8s runs on WSL2- Ubuntu 20.04) ("minikube start")

  ![image](https://user-images.githubusercontent.com/10358317/153183333-371fe598-d5a4-4b86-9b5d-9e33f35063cc.png)
  
- Create Yaml file (pod1.yaml) in your directory and copy the below definition into the file:
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/pod/pod1.yaml 

```
apiVersion: v1      
kind: Pod                         # type of K8s object: Pod
metadata:
  name: firstpod                  # name of pod
  labels:
    app: frontend                 # label pod with "app:frontend"   
spec:
  containers: 
  - name: nginx                   
    image: nginx:latest           # image name:image version, nginx downloads from DockerHub
    ports:
    - containerPort: 80           # open ports in the container
    env:                          # environment variables
      - name: USER
        value: "username"
```

![image](https://user-images.githubusercontent.com/10358317/153674646-8997eb99-12b9-4394-91f2-2de4032ee3db.png)


 - Apply/run the file to create pod in declerative way ("kubectl apply -f pod1.yaml"):
   
   ![image](https://user-images.githubusercontent.com/10358317/153198471-55d92940-1141-4e04-a701-6356daaf0181.png)
  
- Describe firstpod ("kubectl describe pods firstpod"):

  ![image](https://user-images.githubusercontent.com/10358317/153199893-95bfbef0-61b4-4c41-bd89-481d976c272c.png)

- Delete pod and get all pods in the default namepace  ("kubectl delete -f pod1.yaml"):

  ![image](https://user-images.githubusercontent.com/10358317/153200081-3f7823a8-e5d0-4143-aac4-157948fe2a61.png)
  
 - If you want to delete minikube  ("minikube delete"):
   
   ![image](https://user-images.githubusercontent.com/10358317/153200584-01971754-0739-4c8f-8446-d2d3ab5bed31.png)



## K8s Multicontainer Sidecar

## LAB: K8s Multicontainer - Sidecar - Emptydir Volume - Port-Forwarding 

This scenario shows:
- how to create multicontainer in one pod,
- how the multicontainers in the same pod have same ethernet interface (IPs),
- how the multicontainers in the same pod can reach the shared volume area,
- how to make port-forwarding to host PC ports

### Steps

- Run minikube  (in this scenario, K8s runs on WSL2- Ubuntu 20.04) ("minikube start")

  ![image](https://user-images.githubusercontent.com/10358317/153183333-371fe598-d5a4-4b86-9b5d-9e33f35063cc.png)
  
- Create Yaml file (multicontainer.yaml) in your directory and copy the below definition into the file.
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/pod/multicontainer.yaml 

```
apiVersion: v1
kind: Pod
metadata:
  name: multicontainer
spec:
  containers:
  - name: webcontainer                           # container name: webcontainer
    image: nginx                                 # image from nginx
    ports:                                       # opening-port: 80
      - containerPort: 80
    volumeMounts:
    - name: sharedvolume                          
      mountPath: /usr/share/nginx/html          # path in the container
  - name: sidecarcontainer
    image: busybox                              # sidecar, second container image is busybox
    command: ["/bin/sh"]                        # it pulls index.html file from github every 15 seconds
    args: ["-c", "while true; do wget -O /var/log/index.html https://raw.githubusercontent.com/omerbsezer/Fast-Kubernetes/main/index.html; sleep 15; done"]
    volumeMounts:
    - name: sharedvolume
      mountPath: /var/log
  volumes:                                      # define emptydir temporary volume, when the pod is deleted, volume also deleted
  - name: sharedvolume                          # name of volume 
    emptyDir: {}                                # volume type emtpydir: creates empty directory where the pod is runnning
```

![image](https://user-images.githubusercontent.com/10358317/154714091-7355eb36-20d1-4002-a46e-dce56bba5570.png)

- Create multicontainer on the pod (webcontainer and sidecarcontainer):

![image](https://user-images.githubusercontent.com/10358317/153407239-c74aa02d-dc51-4ce3-a680-ec777db8477b.png)

- Connect (/bin/sh of the webcontainer) and install net-tools to show ethernet interface (IP: 172.17.0.3) 

![image](https://user-images.githubusercontent.com/10358317/153408261-bdd4b6b5-c44f-4a12-9959-85cb9c582178.png)

- Connect (/bin/sh of the sidecarcontainer) and show ethernet interface (IP: 172.17.0.3). 
- Containers running on same pod have same ethernet interfaces and same IPs (172.17.0.3).

![image](https://user-images.githubusercontent.com/10358317/153408722-d01eff1c-64e9-4020-a556-9d44a7a0a4f8.png)

- Under the webcontainer, the shared volume with sidecarcontainer can be reachable: 
 
![image](https://user-images.githubusercontent.com/10358317/153412202-bfb7533a-1960-4436-b10b-69f4d788a4ae.png)

- It can be seen from sidecarcontainer. Both of the container can reach same volume area.
- If the new file is created on this volume, other container can also reach same new file. 

![image](https://user-images.githubusercontent.com/10358317/153412522-9214cf3c-d529-4381-b668-a8ad84f95ad5.png)

- When we look at the sidecarcontainer logs, it pulls index.html file from "https://raw.githubusercontent.com/omerbsezer/Fast-Kubernetes/main/index.html" every 15 seconds.

![image](https://user-images.githubusercontent.com/10358317/153412851-3f9763b8-9cfe-4822-b869-b2333f580e77.png)

- We can forward the port of the pod to the host PC port (hostPort:containerPort, e.g: 8080:80):

![image](https://user-images.githubusercontent.com/10358317/153413173-55554d77-2531-4fbe-88e2-1e84ded64be7.png)

- On the browser, goto http://127.0.0.1:8080/

![image](https://user-images.githubusercontent.com/10358317/153413389-f5eec26e-b2cd-44f9-a968-e6133550bfc6.png)


- After updating the content of the index.html, new html page will be downloaded by the sidecarcontainer:

![image](https://user-images.githubusercontent.com/10358317/153414407-3caf71b0-1286-42e8-87e4-d7d1ba47c356.png)

- Exit from the container shell and delete multicontainer in a one pod:

![image](https://user-images.githubusercontent.com/10358317/153416457-65d792fb-62f2-4015-aefd-8f7305379f23.png)
$md$, 45)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('d9f9a269-17b3-56ec-9885-3b8af346cd13', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '375a87e0-e417-5b1c-8bc5-3852ed089e52', 'Lab: Pod', 'lab', 1, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('3a2dfb5c-a7c1-589b-814e-0179fd5221b3', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'd9f9a269-17b3-56ec-9885-3b8af346cd13', 'module', 'Lab: Pod', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/multicontainer.yaml <<'MFEOF'
apiVersion: v1
kind: Pod
metadata:
  name: multicontainer
spec:
  containers:
  - name: webcontainer
    image: nginx
    ports:
      - containerPort: 80
    volumeMounts:
    - name: sharedvolume
      mountPath: /usr/share/nginx/html
  - name: sidecarcontainer
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do wget -O /var/log/index.html https://raw.githubusercontent.com/omerbsezer/Fast-Kubernetes/main/index.html; sleep 15; done"]
    volumeMounts:
    - name: sharedvolume
      mountPath: /var/log
  volumes:
  - name: sharedvolume
    emptyDir: {}
MFEOF
cat > /home/labuser/work/pod1.yaml <<'MFEOF'
apiVersion: v1
kind: Pod
metadata:
  name: firstpod
  labels:
    app: frontend
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
    env: 
    - name: USER    
      value: "username"
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('35c00541-ecb7-5129-b857-15fe47f52414', '3a2dfb5c-a7c1-589b-814e-0179fd5221b3', 1, 'Create the firstpod Pod', $md$Apply `pod1.yaml` (already in your workdir) to create a Pod named **firstpod** with
label `app=frontend`, running image `nginx:latest`.
$md$, $script$#!/bin/bash
kubectl get pod firstpod --no-headers 2>/dev/null | grep -q Running || exit 1
kubectl get pod firstpod -o jsonpath='{.metadata.labels.app}' | grep -qx frontend
$script$, 'Use `kubectl apply -f pod1.yaml`.', 'A bare Pod (no Deployment/ReplicaSet owner) is created directly from the manifest.
kwok''s fast pod-ready stage marks it Running almost immediately once the scheduler
binds it to the (fake) node.
', 10, false, true),
('264ef9d2-1468-51af-b2e2-493aa035eeee', '3a2dfb5c-a7c1-589b-814e-0179fd5221b3', 2, 'Confirm the USER environment variable', $md$Confirm that `firstpod`'s container defines the environment variable `USER` with
value `username`, as declared in `pod1.yaml`.
$md$, $script$#!/bin/bash
kubectl get pod firstpod -o jsonpath='{.spec.containers[0].env[?(@.name=="USER")].value}' | grep -qx username
$script$, 'Inspect the Pod spec with `kubectl get pod firstpod -o yaml` or a `jsonpath` query
against `.spec.containers[0].env`.
', 'Environment variables declared under a container''s `env:` list are injected into the
container''s process environment at start — this is the simplest way to pass
configuration into a container without a ConfigMap or Secret.
', 10, false, false),
('68a23f47-a859-5a4c-9f24-dedc941e49f5', '3a2dfb5c-a7c1-589b-814e-0179fd5221b3', 3, 'Create the multicontainer Pod', $md$Apply `multicontainer.yaml` to create a Pod named **multicontainer** with two
containers — `webcontainer` (nginx) and `sidecarcontainer` (busybox) — sharing an
`emptyDir` volume named `sharedvolume`.
$md$, $script$#!/bin/bash
kubectl get pod multicontainer --no-headers 2>/dev/null | grep -q Running || exit 1
NAMES=$(kubectl get pod multicontainer -o jsonpath='{.spec.containers[*].name}')
echo "$NAMES" | grep -qw webcontainer || exit 1
echo "$NAMES" | grep -qw sidecarcontainer
$script$, 'Use `kubectl apply -f multicontainer.yaml`.', 'All containers in a Pod share the same network namespace (one IP, localhost between
containers) and can share storage via volumes — the sidecar pattern uses this to run a
helper process (here, busybox polling a remote file) alongside the main app container.
', 15, false, true),
('b443715c-5da6-5b2e-b92c-e3cb34d4da66', '3a2dfb5c-a7c1-589b-814e-0179fd5221b3', 4, 'Confirm the shared emptyDir volume is mounted in both containers', $md$Confirm that the `sharedvolume` `emptyDir` volume is mounted into both
`webcontainer` and `sidecarcontainer` in the `multicontainer` Pod.
$md$, $script$#!/bin/bash
kubectl get pod multicontainer -o jsonpath='{.spec.volumes[?(@.name=="sharedvolume")].emptyDir}' >/dev/null 2>&1 || exit 1
MOUNTS=$(kubectl get pod multicontainer -o jsonpath='{.spec.containers[*].volumeMounts[?(@.name=="sharedvolume")].name}')
test "$(echo "$MOUNTS" | wc -w)" -ge 2
$script$, 'Inspect `.spec.volumes` for the `emptyDir` definition and each container''s
`.volumeMounts` for a matching `name: sharedvolume` entry.
', 'An `emptyDir` volume is created fresh when the Pod is scheduled and lives as long as
the Pod does — every container that mounts it sees the same directory, which is how
the sidecar in this Pod delivers files to the main nginx container.
', 15, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('56093b77-4d3c-5060-90f2-2a7b752fb261', '3a2dfb5c-a7c1-589b-814e-0179fd5221b3', 1, $json$[{"id":"35c00541-ecb7-5129-b857-15fe47f52414","lab_id":"3a2dfb5c-a7c1-589b-814e-0179fd5221b3","position":1,"title":"Create the firstpod Pod","description":"Apply `pod1.yaml` (already in your workdir) to create a Pod named **firstpod** with\nlabel `app=frontend`, running image `nginx:latest`.\n","verification_script":"#!/bin/bash\nkubectl get pod firstpod --no-headers 2\u003e/dev/null | grep -q Running || exit 1\nkubectl get pod firstpod -o jsonpath='{.metadata.labels.app}' | grep -qx frontend\n","hint_context":"Use `kubectl apply -f pod1.yaml`.","explanation_context":"A bare Pod (no Deployment/ReplicaSet owner) is created directly from the manifest.\nkwok's fast pod-ready stage marks it Running almost immediately once the scheduler\nbinds it to the (fake) node.\n","points":10,"is_optional":false,"is_stateful":true},{"id":"264ef9d2-1468-51af-b2e2-493aa035eeee","lab_id":"3a2dfb5c-a7c1-589b-814e-0179fd5221b3","position":2,"title":"Confirm the USER environment variable","description":"Confirm that `firstpod`'s container defines the environment variable `USER` with\nvalue `username`, as declared in `pod1.yaml`.\n","verification_script":"#!/bin/bash\nkubectl get pod firstpod -o jsonpath='{.spec.containers[0].env[?(@.name==\"USER\")].value}' | grep -qx username\n","hint_context":"Inspect the Pod spec with `kubectl get pod firstpod -o yaml` or a `jsonpath` query\nagainst `.spec.containers[0].env`.\n","explanation_context":"Environment variables declared under a container's `env:` list are injected into the\ncontainer's process environment at start — this is the simplest way to pass\nconfiguration into a container without a ConfigMap or Secret.\n","points":10,"is_optional":false,"is_stateful":false},{"id":"68a23f47-a859-5a4c-9f24-dedc941e49f5","lab_id":"3a2dfb5c-a7c1-589b-814e-0179fd5221b3","position":3,"title":"Create the multicontainer Pod","description":"Apply `multicontainer.yaml` to create a Pod named **multicontainer** with two\ncontainers — `webcontainer` (nginx) and `sidecarcontainer` (busybox) — sharing an\n`emptyDir` volume named `sharedvolume`.\n","verification_script":"#!/bin/bash\nkubectl get pod multicontainer --no-headers 2\u003e/dev/null | grep -q Running || exit 1\nNAMES=$(kubectl get pod multicontainer -o jsonpath='{.spec.containers[*].name}')\necho \"$NAMES\" | grep -qw webcontainer || exit 1\necho \"$NAMES\" | grep -qw sidecarcontainer\n","hint_context":"Use `kubectl apply -f multicontainer.yaml`.","explanation_context":"All containers in a Pod share the same network namespace (one IP, localhost between\ncontainers) and can share storage via volumes — the sidecar pattern uses this to run a\nhelper process (here, busybox polling a remote file) alongside the main app container.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"b443715c-5da6-5b2e-b92c-e3cb34d4da66","lab_id":"3a2dfb5c-a7c1-589b-814e-0179fd5221b3","position":4,"title":"Confirm the shared emptyDir volume is mounted in both containers","description":"Confirm that the `sharedvolume` `emptyDir` volume is mounted into both\n`webcontainer` and `sidecarcontainer` in the `multicontainer` Pod.\n","verification_script":"#!/bin/bash\nkubectl get pod multicontainer -o jsonpath='{.spec.volumes[?(@.name==\"sharedvolume\")].emptyDir}' \u003e/dev/null 2\u003e\u00261 || exit 1\nMOUNTS=$(kubectl get pod multicontainer -o jsonpath='{.spec.containers[*].volumeMounts[?(@.name==\"sharedvolume\")].name}')\ntest \"$(echo \"$MOUNTS\" | wc -w)\" -ge 2\n","hint_context":"Inspect `.spec.volumes` for the `emptyDir` definition and each container's\n`.volumeMounts` for a matching `name: sharedvolume` entry.\n","explanation_context":"An `emptyDir` volume is created fresh when the Pod is scheduled and lives as long as\nthe Pod does — every container that mounts it sees the same directory, which is how\nthe sidecar in this Pod delivers files to the main nginx container.\n","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = '56093b77-4d3c-5060-90f2-2a7b752fb261', updated_at = now()
WHERE id = '3a2dfb5c-a7c1-589b-814e-0179fd5221b3' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ed5daec9-cbbf-522a-82dc-99453e20dd44', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which of the following best describes a Kubernetes Pod?', 'intermediate', 2, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('dd355da9-cdb5-5eea-ac7d-9aca920d93c9', 'ed5daec9-cbbf-522a-82dc-99453e20dd44', 1, $json${"prompt":"Which of the following best describes a Kubernetes Pod?","multiple":false,"options":[{"id":"a","text":"A single container deployed directly on a host OS without any abstraction","is_correct":false},{"id":"b","text":"The smallest deployable unit in Kubernetes; one or more tightly coupled containers sharing the same network namespace, IP address, and storage volumes","is_correct":true},{"id":"c","text":"A logical grouping of worker nodes within a cluster","is_correct":false},{"id":"d","text":"A configuration template that defines container images and restart policies","is_correct":false}],"explanation":"A Pod is Kubernetes' smallest deployable unit. All containers in a Pod share the same\nIP, port space, and localhost, and can share mounted volumes. Pods are ephemeral —\nthey are not self-healing on their own; controllers like Deployments manage that.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a9efe830-6e2c-5102-8b10-4bbeae811655', '00000000-0000-0000-0000-000000000001', 'mcq', 'In a multi-container Pod using the sidecar pattern (e.g. an nginx container p...', 'intermediate', 3, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('84a4c890-2e0d-561c-bd7c-555968d87a4f', 'a9efe830-6e2c-5102-8b10-4bbeae811655', 1, $json${"prompt":"In a multi-container Pod using the sidecar pattern (e.g. an nginx container plus a busybox helper), how do the two containers share files?","multiple":false,"options":[{"id":"a","text":"They cannot share files; each container has a fully isolated filesystem","is_correct":false},{"id":"b","text":"Through a shared volume (e.g. emptyDir) mounted into both containers' filesystems","is_correct":true},{"id":"c","text":"Automatically, because containers in the same Pod always share the same filesystem root","is_correct":false},{"id":"d","text":"Only via a NodePort Service exposing a shared path","is_correct":false}],"explanation":"Containers in a Pod share network and IPC namespaces but NOT filesystems by default —\nan explicit volume (commonly emptyDir for ephemeral sharing) must be declared and\nmounted into each container that needs access to the shared data.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('dd94a27e-2662-562a-9a21-dfd675dc4585', '00000000-0000-0000-0000-000000000001', 'coding', 'You receive a list of Pod statuses, one per line, in the form `NAME PHASE`. C...', 'beginner', 5, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f6b76fdc-0f6e-59b8-a94f-d4f7e60a452c', 'dd94a27e-2662-562a-9a21-dfd675dc4585', 1, $json${"prompt":"You receive a list of Pod statuses, one per line, in the form `NAME PHASE`. Count how\nmany Pods are in the `Running` phase and print that count.\n\n**Example:**\n```\n3\nweb-1 Running\nweb-2 Pending\nweb-3 Running\n```\nOutput: `2`\n","languages":["python","javascript"],"starter_code":{"javascript":"const lines = require('fs').readFileSync(0, 'utf8').trim().split('\\n');\nconst n = parseInt(lines[0]);\nlet count = 0;\nfor (let i = 1; i \u003c= n; i++) {\n  const parts = lines[i].trim().split(/\\s+/);\n  if (parts[1] === 'Running') count++;\n}\nconsole.log(count);\n","python":"import sys\nlines = sys.stdin.read().split('\\n')\nn = int(lines[0])\ncount = 0\nfor i in range(1, n + 1):\n    parts = lines[i].split()\n    if parts[1] == 'Running':\n        count += 1\nprint(count)\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"3\nweb-1 Running\nweb-2 Pending\nweb-3 Running\n","expected":"2","hidden":false,"weight":1},{"id":"t2","stdin":"1\nsingle-pod Running\n","expected":"1","hidden":true,"weight":1},{"id":"t3","stdin":"4\na Pending\nb Pending\nc Running\nd Failed\n","expected":"1","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('5e2d8ed2-43f0-5529-b423-1c1399dde5df', '00000000-0000-0000-0000-000000000001', 'Quiz: Pod Fundamentals', 'k8s-pod-fundamentals-quiz', 'Quiz covering Pod Fundamentals.', 'mixed', 'published', 'module', 'f9a32647-aa50-5e64-beaf-e8af561b8c06', 15, 60, 5, 10, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('99374a14-302e-514d-8603-54c5b697d9bf', '5e2d8ed2-43f0-5529-b423-1c1399dde5df', 'ed5daec9-cbbf-522a-82dc-99453e20dd44', 'dd355da9-cdb5-5eea-ac7d-9aca920d93c9', 0, 2),
('358ba2f1-beaf-5b72-9110-0b935e6edbb0', '5e2d8ed2-43f0-5529-b423-1c1399dde5df', 'a9efe830-6e2c-5102-8b10-4bbeae811655', '84a4c890-2e0d-561c-bd7c-555968d87a4f', 1, 3),
('98ab90a1-dead-5b34-ad46-319d526dfd0a', '5e2d8ed2-43f0-5529-b423-1c1399dde5df', 'dd94a27e-2662-562a-9a21-dfd675dc4585', 'f6b76fdc-0f6e-59b8-a94f-d4f7e60a452c', 2, 5)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('f9a32647-aa50-5e64-beaf-e8af561b8c06', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '375a87e0-e417-5b1c-8bc5-3852ed089e52', 'Quiz: Pod Fundamentals', 'assessment', 2, 15, '5e2d8ed2-43f0-5529-b423-1c1399dde5df')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Workloads & Controllers
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('c70cffde-a094-57b7-b0b9-8bbbaa0578e0', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Workloads & Controllers', 2)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes)
VALUES ('66141cf6-373d-5e3a-a4f6-ebaa45838fba', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Workloads & Controllers', 'notes', 0, $md$
## K8s Deployment

## LAB: K8s Deployment - Scale Up/Down - Bash Connection - Port Forwarding

This scenario shows:
- how to create deployment,
- how to get detail information of deployment and pods,
- how to scale up and down of deployment,
- how to connect to the one of the pods with bash,
- how to show ethernet interfaces of the pod and ping other pods,
- how to forward ports to see nginx server page using browser.

### Steps

- Run minikube  (in this scenario, K8s runs on WSL2- Ubuntu 20.04) ("minikube start")

  ![image](https://user-images.githubusercontent.com/10358317/153183333-371fe598-d5a4-4b86-9b5d-9e33f35063cc.png)
  
- Create Yaml file (deployment1.yaml) in your directory and copy the below definition into the file.
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/deployment/deployment1.yaml

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: firstdeployment
  labels:
    team: development
spec:
  replicas: 3
  selector:                        # deployment selector
    matchLabels:                   # deployment selects "app:frontend" pods, monitors and traces these pods 
      app: frontend                # if one of the pod is killed, K8s looks at the desire state (replica:3), it recreats another pods to protect number of replicas
  template:
    metadata:
      labels:                      # pod labels, if the deployment selector is same with these labels, deployment follows pods that have these labels         
        app: frontend              # key: value        
    spec:                                   
      containers:
      - name: nginx                
        image: nginx:latest        # image download from DockerHub
        ports:
        - containerPort: 80        # open following ports
```

![image](https://user-images.githubusercontent.com/10358317/154119883-5ffcaaaa-572e-427e-b6d6-65e3a8723121.png)


- Create deployment and list the deployment's pods:

![image](https://user-images.githubusercontent.com/10358317/153439583-c445b070-ac27-4838-8943-466261abf635.png)

- Delete one of the pod, then K8s automatically creates new pod:

![image](https://user-images.githubusercontent.com/10358317/153440362-a95dbc41-2cc0-4ec6-8830-8924f3c4a2f7.png)

- Scale up to 5 replicas:

![image](https://user-images.githubusercontent.com/10358317/153440932-39f98de1-c129-4d7d-a4e6-79acbed070ea.png)

- Scale down to 3 replicas:

![image](https://user-images.githubusercontent.com/10358317/153441111-558460c7-e35e-4db3-9028-50b6c9149043.png)

- Get more information about pods (ip, node):

![image](https://user-images.githubusercontent.com/10358317/153442941-da17b07e-ad14-49ae-84b3-d9902535f9a7.png)


- Connect one of the pod with bash:

![image](https://user-images.githubusercontent.com/10358317/153442294-efb4dfa5-0753-404c-b1bf-896a8d8ed436.png)

- To install ifconfig, run: "apt update", "apt install net-tools"
- To install ping, run: "apt install iputils-ping"
- Show ethernet interfaces:

![image](https://user-images.githubusercontent.com/10358317/153442647-32ea74cd-dd46-4631-b896-f90ec1afb1a3.png)

- Ping other pods:

![image](https://user-images.githubusercontent.com/10358317/153443214-d0e3dc55-e4ef-449a-8b9e-35a45ecb2675.png)

- Port-forward from one of the pod to host (8085:80):

![image](https://user-images.githubusercontent.com/10358317/153443668-18071c34-0e80-4ecd-a3e9-ae9570bd9d7d.png)

- On the browser, goto http://127.0.0.1:8085/

![image](https://user-images.githubusercontent.com/10358317/153443803-709fdf31-7d16-4268-a1f1-8fc822abc471.png)

- Delete deployment:

![image](https://user-images.githubusercontent.com/10358317/153444098-e52f2cde-3fd2-4606-b68c-89e6f9194398.png)



## K8s Rollout Rollback

## LAB: K8s Rollout - Rollback 

This scenario shows:
- how to roll out deployments with 2 different strategy: recreate and rollingUpdate,
- how to save/record deployments' revision while rolling out with "--record" (e.g. changing image):
  - imperative:             "kubectl set image deployment rcdeployment nginx=httpd --record",
  - declerative, edit file: "kubectl edit deployment rolldeployment --record", 
- how to rollback (rollout undo) the desired deployment revisions: 
  - "kubectl rollout undo deployment rolldeployment --to-revision=2",
- how to pause/resume rollout:
  - pause:  "kubectl rollout pause deployment rolldeployment",
  - resume: "kubectl rollout resume deployment rolldeployment",
- how to see the status of rollout deployment:
  - "kubectl rollout status deployment rolldeployment -w". 

### Steps

- Run minikube  (in this scenario, K8s runs on WSL2- Ubuntu 20.04) ("minikube start")

![image](https://user-images.githubusercontent.com/10358317/153183333-371fe598-d5a4-4b86-9b5d-9e33f35063cc.png)
  
- Create Yaml file (recreate-deployment.yaml) in your directory and copy the below definition into the file.
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/deployment/recreate-deployment.yaml

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rcdeployment
  labels:
    team: development
spec:
  replicas: 5                        # create 5 replicas
  selector:
    matchLabels:                     # labelselector of deployment: selects pods which have "app:recreate" labels
      app: recreate
  strategy:                          # deployment roll up strategy: recreate => Delete all pods firstly and create Pods from scratch.
    type: Recreate
  template:
    metadata:
      labels:                        # labels the pod with "app:recreate" 
        app: recreate
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```

![image](https://user-images.githubusercontent.com/10358317/154661824-0e6db25e-cf67-4789-97be-acd8d90f7c07.png)


- Create Yaml file (rolling-deployment.yaml) in your directory and copy the below definition into the file.
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/deployment/rolling-deployment.yaml

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolldeployment
  labels:
    team: development
spec:
  replicas: 10                     
  selector:
    matchLabels:                     # labelselector of deployment: selects pods which have "app:rolling" labels
      app: rolling
  strategy:
    type: RollingUpdate              # deployment roll up strategy: rollingUpdate => Pods are updated step by step, all pods are not deleted at the same time.
    rollingUpdate:                   
      maxUnavailable: 2              # shows the max number of deleted containers => total:10 container; if maxUnava:2, min:8 containers run in that time period
      maxSurge: 2                    # shows that the max number of containers    => total:10 container; if maxSurge:2, max:12 containers run in a time
  template:
    metadata:
      labels:                        # labels the pod with "app:rolling"
        app: rolling
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```

![image](https://user-images.githubusercontent.com/10358317/154661909-087ac83a-d5ee-4268-805c-c4a7179dfafd.png)

- Run deployment: 

![image](https://user-images.githubusercontent.com/10358317/153604472-8af9e7d9-7d22-47e2-b02d-2e6c36c86de5.png)

- Watching pods' status (on linux: "watch kubectl get pods", on win: "kubectl get pods -w")

![image](https://user-images.githubusercontent.com/10358317/153604648-9944dfd4-3148-4e8c-b52b-ef801a695ed2.png)

- Watching replica set's status (on linux: "watch kubectl get rs", on win: "kubectl get rs -w")

![image](https://user-images.githubusercontent.com/10358317/153604880-a0697649-967d-4255-bc4d-e72446568844.png)

- Update image version ("kubectl set image deployment rcdeployment nginx=httpd"), after new replicaset and pods are created, old ones are deleted. 

![image](https://user-images.githubusercontent.com/10358317/153605645-3bd72a89-9840-4d6b-9c6c-3b8c251cf2e9.png)

- With "recreate" strategy, pods are terminated:
 
![image](https://user-images.githubusercontent.com/10358317/153605318-8f71959d-3c44-4c72-bdd5-674aea6d1afc.png)

- New pods are creating:

![image](https://user-images.githubusercontent.com/10358317/153605365-bc6ffcbe-cadc-4760-b85a-a4844fa1ccb4.png)

- New replicaset created:

![image](https://user-images.githubusercontent.com/10358317/153605416-80d63de8-dee6-4131-bb24-a1a8f8e47cda.png)

- Delete this deployment:

![image](https://user-images.githubusercontent.com/10358317/153605871-6ca3810d-ce23-4442-ae2c-44c362ada13d.png)

- Run deployment (rolling-deployment.yaml): 

![image](https://user-images.githubusercontent.com/10358317/153610269-96541251-b039-4393-87e3-a1e93e234753.png)


- Watching pods' status (on linux: "watch kubectl get pods", on win: "kubectl get pods -w")

![image](https://user-images.githubusercontent.com/10358317/153610371-5836cf65-2a60-4e94-b96e-e4b8643412a2.png)

- Watching replica set's status (on linux: "watch kubectl get rs", on win: "kubectl get rs -w")

![image](https://user-images.githubusercontent.com/10358317/153610454-e27200ec-1c52-48aa-89de-c798fa6d8d5f.png)

- Run: "kubectl edit deployment rolldeployment --record", it opens vim editor on linux to edit
- Find image definition, press "i" for insert mode, change to "httpd" instead of "nginx", press "ESC", press ":wq" to save and exit

![image](https://user-images.githubusercontent.com/10358317/153610924-b2fc3730-de65-4138-8ee8-d4675badd651.png)

- New pods are creating with new version:

![image](https://user-images.githubusercontent.com/10358317/153614766-027ee933-0788-4418-8577-70f0860a8841.png)

- New replicaset created:

![image](https://user-images.githubusercontent.com/10358317/153614901-55137709-b79a-4bfd-866b-a259b299cda5.png)

- Run new deployment version:

![image](https://user-images.githubusercontent.com/10358317/153615453-95067330-5056-4103-a396-db2979d0b98a.png)

- New pods are creating with new version:

![image](https://user-images.githubusercontent.com/10358317/153615342-043787b0-bb8a-438b-ba35-65e0a71985ac.png)

- New replicaset created:

![image](https://user-images.githubusercontent.com/10358317/153615533-9af6f608-c94b-4a45-baf9-c68d394a3308.png)

- To show history of the deployments (**important:** --record should be used to add old deployment versions in the history list):

![image](https://user-images.githubusercontent.com/10358317/153615727-30cfa59d-a144-41ed-9685-f4ec8a562ed0.png)

- To show/describe the selected revision:

![image](https://user-images.githubusercontent.com/10358317/153616272-3fd95a8b-3b6c-42a7-add6-ae40550a47e8.png)

- Rollback to the revision=1 (with undo: "kubectl rollout undo deployment rolldeployment --to-revision=1"):

![image](https://user-images.githubusercontent.com/10358317/153616842-e5a544c8-0d1b-4843-a263-d7fb7c51df22.png)


- Pod status:

![image](https://user-images.githubusercontent.com/10358317/153616616-30b635d2-c95f-47ea-8abd-5fdcd4646719.png)

- Replicaset revision=1:

![image](https://user-images.githubusercontent.com/10358317/153616770-5c72a691-8028-4bc1-9111-b1f63504b7c7.png)

- It is possible to return from revision=1 to revision=2 (with undo: "kubectl rollout undo deployment rolldeployment --to-revision=2"):

![image](https://user-images.githubusercontent.com/10358317/153618994-f5b072c7-c758-46ce-bcb6-1c48e255200e.png)


- It is also to pause rollout:

![image](https://user-images.githubusercontent.com/10358317/153617586-011a90d9-d4b7-4813-b191-75069ee5ffd0.png)

- While rollback to the revision=3 from revision=2, it was paused:

![image](https://user-images.githubusercontent.com/10358317/153617783-da05f8a8-5b1b-4473-9bd6-47f709ab8349.png)

- Resume the pause of rollout of deployment:

![image](https://user-images.githubusercontent.com/10358317/153617914-3ed84d3f-20a0-4693-bb9e-17e1346f28b5.png)

- Now deployment's revision is 3:

![image](https://user-images.githubusercontent.com/10358317/153618035-5b506540-dc63-45fd-af83-d2bedb5b192e.png)

- It is also possible to see the logs of rollout with:
  - "kubectl rollout status deployment rolldeployment -w"

- Delete deployment:

![image](https://user-images.githubusercontent.com/10358317/153620662-bbd8d7e4-572b-4261-b300-f350ee655711.png)


## K8s Daemon Sets

## LAB: K8s Daemon Sets

This scenario shows how K8s Daemonsets work on minikube by adding new nodes

### Steps

- Copy and save (below) as file on your PC (daemonset.yaml). 
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/daemonset/daemonset.yaml

```     
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: logdaemonset
  labels:
    app: fluentd-logging
spec:
  selector:
    matchLabels:                                                 # label selector should be same labels in the template (template > metadata > labels)
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:
      - key: node-role.kubernetes.io/master                      # this toleration is to have the daemonset runnable on master nodes
        effect: NoSchedule                                       # remove it if your masters can't run pods  
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2      # installing fluentd elasticsearch on each nodes
        resources:
          limits:
            memory: 200Mi                                        # resource limitations configured           
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:                                            # definition of volumeMounts for each pod 
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:                                                   # ephemerial volumes on node (hostpath defined)   
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers    
```

![image](https://user-images.githubusercontent.com/10358317/154733287-2c65a70a-2d9f-4b69-969e-8e2938ce425d.png)

- Create daemonset on minikube:

![image](https://user-images.githubusercontent.com/10358317/152146006-265e0595-cdf5-43c7-aea2-5437700323fd.png)

- Run watch command on Linux: "watch kubectl get daemonset", on Win: "kubectl get daemonset -w"

![image](https://user-images.githubusercontent.com/10358317/152146266-00d1f1b8-f2dc-495f-ab35-15e3d1629278.png)

- Add new node on the cluster:

![image](https://user-images.githubusercontent.com/10358317/152146458-14a66e8a-fcad-4a15-ac3e-6df1af4a43a4.png)

- To see, app runs automatically on the new node:

![image](https://user-images.githubusercontent.com/10358317/152147031-b934d393-8caf-49c3-ac4c-3b704f2d646a.png)

- Add new node (3rd):

![image](https://user-images.githubusercontent.com/10358317/152151984-ac8fd54c-676d-4be4-b2f1-4356613a8fed.png)

- Now daemonset have 3rd node:

![image](https://user-images.githubusercontent.com/10358317/152152156-c8cd559e-48dc-4ea3-85c9-6da7fbeb0794.png)

- Delete one of the pod:

![image](https://user-images.githubusercontent.com/10358317/152152437-7c883cd5-e809-4386-8832-362a612acf5f.png)

- Pod deletion can be seen here:

![image](https://user-images.githubusercontent.com/10358317/152152613-854c5340-c73b-4d72-bd08-951aa640d8ad.png)

- Daemonset create new pod automatically:

![image](https://user-images.githubusercontent.com/10358317/152152744-9f14751b-e214-4621-8208-1cb5437b6d71.png)

- See the nodes resource on dashboard:

![image](https://user-images.githubusercontent.com/10358317/152153072-5e53cd9c-42ba-4f50-85d8-c82ea1e39752.png)

- Delete nodes and delete daemonset:

![image](https://user-images.githubusercontent.com/10358317/152153355-b98bca05-87cd-46d2-a26d-eb614ca263ca.png)





## K8s Statefulset

## LAB: K8s Stateful Set - Nginx

This scenario shows how K8s statefulset object works on minikube

### Steps

- Copy and save (below) as file on your PC (statefulset_nginx.yaml).
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/statefulset/statefulset.yaml 

```     
apiVersion: v1
kind: Service
metadata:
  name: nginx                                     # create a service with "nginx" name
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web                                     # create headless service if clusterIP:None
  clusterIP: None                                 # when requesting service name, service returns one of the IP of pods
  selector:                                       # headless service provides to reach pod with podName.serviceName
    app: nginx                                    # selects/binds to app:nginx (defined in: spec > template > metadata > labels > app:nginx)
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web                                       # statefulset name: web
spec:
  serviceName: nginx                              # binds/selects service (defined in metadata > name: nginx)            
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx                            
    spec:
      containers:
      - name: nginx
        image: k8s.gcr.io/nginx-slim:0.8
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]              # creates PVCs for each pod automatically
      resources:                                    # hence, each node has own PV
        requests:
          storage: 512Mi
```

![image](https://user-images.githubusercontent.com/10358317/154945153-d9b61958-94d2-44f0-a900-14494aeb41f7.png)

![image](https://user-images.githubusercontent.com/10358317/154945314-974de8ae-4456-4711-b499-8aad664b847a.png)

- Create statefulset and pvc:

![image](https://user-images.githubusercontent.com/10358317/152322911-47e14c25-9f86-49ff-bdcf-df74e38e5939.png)

- Pods are created with statefulsetName-0,1,2 (e.g. web-0)

![image](https://user-images.githubusercontent.com/10358317/152323071-a79b5d15-22e4-424b-86a3-f84a77377b69.png)

- PVCs and PVs are automatically created for each pod. Even if pod is restarted again, same PV is bound to same pod.
 
![image](https://user-images.githubusercontent.com/10358317/152324124-bbae308a-533f-4476-8206-6d53c6b9b648.png)

- Scaled from 3 Pods to 4 Pods:

![image](https://user-images.githubusercontent.com/10358317/152324908-762100ca-94b3-4db4-b73e-9ad09c32588d.png)

- New pod's name is not assigned randomly, assigned in order and got "web-4" name. 

![image](https://user-images.githubusercontent.com/10358317/152325051-2f757f13-77ae-4aab-84d9-d6f6c8a04c1c.png)

- Scale down to 3 Pods again:

![image](https://user-images.githubusercontent.com/10358317/152325305-c10782a2-a8e2-4c5b-8da9-7ca90de9e00a.png)

- Last created pod is deleted: 

![image](https://user-images.githubusercontent.com/10358317/152325429-20d84fdf-aeb2-45e7-8790-55ba3a28b197.png)

- When creating headless service, service does not get any IP (e.g. None)

![image](https://user-images.githubusercontent.com/10358317/152325883-3b833268-cae9-4863-9e05-af80b0cefa8d.png)

- With headless service, service returns one of the IP, service balances the load between pods (loadbalacing between pods)

![image](https://user-images.githubusercontent.com/10358317/152327066-45cb6cf0-b988-48a7-aef7-2e8295334280.png)

- If we ping the specific pod with podName.serviceName (e.g. ping web-0.nginx), it returns the IP of the that pod.
- With statefulset, the name of the pod is known, this helps to ping pods with name of the pod.

![image](https://user-images.githubusercontent.com/10358317/152327651-449cb69b-fe2e-45a9-b0b1-bd01fa340eff.png)



## K8s Job

## LAB: K8s Job

This scenario shows how K8s job object works on minikube

### Steps

- Copy and save (below) as file on your PC (job.yaml).
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/job/job.yaml 

```     
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  parallelism: 2               # each step how many pods start in parallel at a time
  completions: 10              # number of pods that run and complete job at the end of the time
  backoffLimit: 5              # to tolerate fail number of job, after 5 times of failure, not try to continue job, fail the job
  activeDeadlineSeconds: 100   # if this job is not completed in 100 seconds, fail the job
  template:
    spec:
      containers:
      - name: pi
        image: perl           # image is perl from docker   
        command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]    # it calculates the first 2000 digits of pi number
      restartPolicy: Never   
```

![image](https://user-images.githubusercontent.com/10358317/154946885-80e87f3c-5120-4c09-bde2-a35cd09a7383.png)

- Create job:

![image](https://user-images.githubusercontent.com/10358317/152507949-922134f4-28cb-4d4f-8ccf-d5c5657b79c3.png)

- Watch pods' status:

![image](https://user-images.githubusercontent.com/10358317/152507888-21b8de27-c4a4-4772-8209-072bdcd66ad5.png)

- Watch job's status:

![image](https://user-images.githubusercontent.com/10358317/152508221-1795ed68-083b-4e23-b0e5-8c97a0672141.png)

- After pods' completion, we can see the logs of each pods. Pods are not deleted after the completion of task on each pod. 

![image](https://user-images.githubusercontent.com/10358317/152508363-a61e5c7a-57fa-4030-a8b0-d9baed027146.png)

- Delete job: 

![image](https://user-images.githubusercontent.com/10358317/152508749-049880e4-96b5-4dfd-96c2-107796366c02.png)


## K8s CronJob

## LAB: K8s Cron Job

This scenario shows how K8s Cron job object works on minikube

### Steps

- Copy and save (below) as file on your PC (cronjob.yaml). 
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/cronjob/cronjob.yaml

```     
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            imagePullPolicy: IfNotPresent
            command:
            - /bin/sh
            - -c
            - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure
```

![image](https://user-images.githubusercontent.com/10358317/154947805-0c1db85f-fd52-4e3e-8e86-5afca73359ca.png)


- Create Cron Job:

![image](https://user-images.githubusercontent.com/10358317/152511636-b68caefa-1d1a-48a4-bc2b-a773e0ba5eef.png)

- Watch pods' status:

![image](https://user-images.githubusercontent.com/10358317/152511899-cb32ee77-b3b2-4cf5-ad44-f3b1187555f2.png)

- Watch job's status:

![image](https://user-images.githubusercontent.com/10358317/152511995-4a6ca576-99e1-4dbf-bf26-73c150a36b5b.png)

- Delete job: 

![image](https://user-images.githubusercontent.com/10358317/152512127-2410d92d-4555-45d7-ab3f-cac0d80839df.png)
$md$, 90)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('ca5caa6c-ca1c-5408-8c6d-f0028b82abac', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Lab: Deployment', 'lab', 1, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('8a39f024-139f-52e2-ba2a-2c6c4c5cc370', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'ca5caa6c-ca1c-5408-8c6d-f0028b82abac', 'module', 'Lab: Deployment', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/deployment1.yaml <<'MFEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: firstdeployment
  labels:
    team: development
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
MFEOF
cat > /home/labuser/work/recreate-deployment.yaml <<'MFEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rcdeployment
  labels:
    team: development
spec:
  replicas: 5
  selector:
    matchLabels:
      app: recreate
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: recreate
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
MFEOF
cat > /home/labuser/work/rolling-deployment.yaml <<'MFEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolldeployment
  labels:
    team: development
spec:
  replicas: 10
  selector:
    matchLabels:
      app: rolling
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 2
      maxSurge: 2
  template:
    metadata:
      labels:
        app: rolling
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('f09c8d93-14b0-577e-bcda-9a7f984e1aed', '8a39f024-139f-52e2-ba2a-2c6c4c5cc370', 1, 'Create the firstdeployment Deployment', $md$Apply `deployment1.yaml` (already in your workdir) to create a Deployment named
**firstdeployment** with **3 replicas**, image `nginx:latest`, and label `app=frontend`.
$md$, $script$#!/bin/bash
kubectl get deployment firstdeployment >/dev/null 2>&1 || exit 1
READY=$(kubectl get deployment firstdeployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
test "${READY:-0}" -ge 3
$script$, 'Use `kubectl apply -f deployment1.yaml`.', '`kubectl apply` reconciles the cluster to match the manifest declaratively. The
Deployment controller creates a ReplicaSet, which creates 3 Pods matching the
`app=frontend` selector.
', 15, false, true),
('4ae360b6-396a-5b51-bd92-c600a1c4ccad', '8a39f024-139f-52e2-ba2a-2c6c4c5cc370', 2, 'Create the rcdeployment Deployment (Recreate strategy)', $md$Apply `recreate-deployment.yaml` to create a Deployment named **rcdeployment** with
**5 replicas** and `strategy.type: Recreate`.
$md$, $script$#!/bin/bash
kubectl get deployment rcdeployment >/dev/null 2>&1 || exit 1
kubectl get deployment rcdeployment -o jsonpath='{.spec.strategy.type}' | grep -q Recreate || exit 1
READY=$(kubectl get deployment rcdeployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
test "${READY:-0}" -ge 5
$script$, 'Use `kubectl apply -f recreate-deployment.yaml`.', 'The `Recreate` strategy kills every existing Pod before creating replacements — unlike
`RollingUpdate`, there is a window with zero available Pods, but it guarantees no two
versions ever run simultaneously.
', 15, false, true),
('6247de56-7646-54b3-93ba-e8a3de75e32c', '8a39f024-139f-52e2-ba2a-2c6c4c5cc370', 3, 'Create the rolldeployment Deployment (RollingUpdate strategy)', $md$Apply `rolling-deployment.yaml` to create a Deployment named **rolldeployment** with
**10 replicas** and a `RollingUpdate` strategy configured with `maxSurge: 2` and
`maxUnavailable: 2`.
$md$, $script$#!/bin/bash
kubectl get deployment rolldeployment >/dev/null 2>&1 || exit 1
kubectl get deployment rolldeployment -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' | grep -qx 2 || exit 1
kubectl get deployment rolldeployment -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' | grep -qx 2 || exit 1
READY=$(kubectl get deployment rolldeployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
test "${READY:-0}" -ge 10
$script$, 'Use `kubectl apply -f rolling-deployment.yaml`.', '`maxSurge` caps how many extra Pods above the desired count may exist during a rollout;
`maxUnavailable` caps how many desired Pods may be missing. Both default to 25% when
unset — this manifest sets them explicitly to absolute counts instead.
', 20, false, true),
('3a35b142-5453-5172-9486-b9a02c9ba94e', '8a39f024-139f-52e2-ba2a-2c6c4c5cc370', 4, 'Scale firstdeployment down to 1 replica', $md$Scale the **firstdeployment** Deployment down to **1 replica** using `kubectl scale`.
$md$, $script$#!/bin/bash
DESIRED=$(kubectl get deployment firstdeployment -o jsonpath='{.spec.replicas}' 2>/dev/null)
READY=$(kubectl get deployment firstdeployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
test "${DESIRED:-0}" -eq 1 && test "${READY:-0}" -le 1
$script$, 'Use `kubectl scale deployment firstdeployment --replicas=1`.', 'Scaling updates `.spec.replicas`; the Deployment controller adjusts the ReplicaSet''s
replica count, which schedules or terminates Pods to match.
', 15, false, true),
('1d54c4f5-b5ee-5dca-9d27-1b2c4b49f955', '8a39f024-139f-52e2-ba2a-2c6c4c5cc370', 5, 'Roll out a new image on firstdeployment', $md$Update `firstdeployment`'s container image to `nginx:1.27` and wait for the rollout to
finish. Use `kubectl set image` and `kubectl rollout status`.
$md$, $script$#!/bin/bash
IMAGE=$(kubectl get deployment firstdeployment -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
test "$IMAGE" = "nginx:1.27" || exit 1
kubectl rollout status deployment/firstdeployment --timeout=30s >/dev/null 2>&1
$script$, 'Use `kubectl set image deployment/firstdeployment nginx=nginx:1.27`, then
`kubectl rollout status deployment/firstdeployment`.
', '`kubectl set image` patches `.spec.template.spec.containers[].image`, which changes the
Pod template hash and triggers a new ReplicaSet. `kubectl rollout status` blocks until
the new ReplicaSet is fully available — the same mechanism `kubectl rollout undo` reverses.
', 20, false, true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('8d979332-41b9-5f85-9a37-e15f4ff97ee9', '8a39f024-139f-52e2-ba2a-2c6c4c5cc370', 1, $json$[{"id":"f09c8d93-14b0-577e-bcda-9a7f984e1aed","lab_id":"8a39f024-139f-52e2-ba2a-2c6c4c5cc370","position":1,"title":"Create the firstdeployment Deployment","description":"Apply `deployment1.yaml` (already in your workdir) to create a Deployment named\n**firstdeployment** with **3 replicas**, image `nginx:latest`, and label `app=frontend`.\n","verification_script":"#!/bin/bash\nkubectl get deployment firstdeployment \u003e/dev/null 2\u003e\u00261 || exit 1\nREADY=$(kubectl get deployment firstdeployment -o jsonpath='{.status.readyReplicas}' 2\u003e/dev/null)\ntest \"${READY:-0}\" -ge 3\n","hint_context":"Use `kubectl apply -f deployment1.yaml`.","explanation_context":"`kubectl apply` reconciles the cluster to match the manifest declaratively. The\nDeployment controller creates a ReplicaSet, which creates 3 Pods matching the\n`app=frontend` selector.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"4ae360b6-396a-5b51-bd92-c600a1c4ccad","lab_id":"8a39f024-139f-52e2-ba2a-2c6c4c5cc370","position":2,"title":"Create the rcdeployment Deployment (Recreate strategy)","description":"Apply `recreate-deployment.yaml` to create a Deployment named **rcdeployment** with\n**5 replicas** and `strategy.type: Recreate`.\n","verification_script":"#!/bin/bash\nkubectl get deployment rcdeployment \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get deployment rcdeployment -o jsonpath='{.spec.strategy.type}' | grep -q Recreate || exit 1\nREADY=$(kubectl get deployment rcdeployment -o jsonpath='{.status.readyReplicas}' 2\u003e/dev/null)\ntest \"${READY:-0}\" -ge 5\n","hint_context":"Use `kubectl apply -f recreate-deployment.yaml`.","explanation_context":"The `Recreate` strategy kills every existing Pod before creating replacements — unlike\n`RollingUpdate`, there is a window with zero available Pods, but it guarantees no two\nversions ever run simultaneously.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"6247de56-7646-54b3-93ba-e8a3de75e32c","lab_id":"8a39f024-139f-52e2-ba2a-2c6c4c5cc370","position":3,"title":"Create the rolldeployment Deployment (RollingUpdate strategy)","description":"Apply `rolling-deployment.yaml` to create a Deployment named **rolldeployment** with\n**10 replicas** and a `RollingUpdate` strategy configured with `maxSurge: 2` and\n`maxUnavailable: 2`.\n","verification_script":"#!/bin/bash\nkubectl get deployment rolldeployment \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get deployment rolldeployment -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' | grep -qx 2 || exit 1\nkubectl get deployment rolldeployment -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' | grep -qx 2 || exit 1\nREADY=$(kubectl get deployment rolldeployment -o jsonpath='{.status.readyReplicas}' 2\u003e/dev/null)\ntest \"${READY:-0}\" -ge 10\n","hint_context":"Use `kubectl apply -f rolling-deployment.yaml`.","explanation_context":"`maxSurge` caps how many extra Pods above the desired count may exist during a rollout;\n`maxUnavailable` caps how many desired Pods may be missing. Both default to 25% when\nunset — this manifest sets them explicitly to absolute counts instead.\n","points":20,"is_optional":false,"is_stateful":true},{"id":"3a35b142-5453-5172-9486-b9a02c9ba94e","lab_id":"8a39f024-139f-52e2-ba2a-2c6c4c5cc370","position":4,"title":"Scale firstdeployment down to 1 replica","description":"Scale the **firstdeployment** Deployment down to **1 replica** using `kubectl scale`.\n","verification_script":"#!/bin/bash\nDESIRED=$(kubectl get deployment firstdeployment -o jsonpath='{.spec.replicas}' 2\u003e/dev/null)\nREADY=$(kubectl get deployment firstdeployment -o jsonpath='{.status.readyReplicas}' 2\u003e/dev/null)\ntest \"${DESIRED:-0}\" -eq 1 \u0026\u0026 test \"${READY:-0}\" -le 1\n","hint_context":"Use `kubectl scale deployment firstdeployment --replicas=1`.","explanation_context":"Scaling updates `.spec.replicas`; the Deployment controller adjusts the ReplicaSet's\nreplica count, which schedules or terminates Pods to match.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"1d54c4f5-b5ee-5dca-9d27-1b2c4b49f955","lab_id":"8a39f024-139f-52e2-ba2a-2c6c4c5cc370","position":5,"title":"Roll out a new image on firstdeployment","description":"Update `firstdeployment`'s container image to `nginx:1.27` and wait for the rollout to\nfinish. Use `kubectl set image` and `kubectl rollout status`.\n","verification_script":"#!/bin/bash\nIMAGE=$(kubectl get deployment firstdeployment -o jsonpath='{.spec.template.spec.containers[0].image}' 2\u003e/dev/null)\ntest \"$IMAGE\" = \"nginx:1.27\" || exit 1\nkubectl rollout status deployment/firstdeployment --timeout=30s \u003e/dev/null 2\u003e\u00261\n","hint_context":"Use `kubectl set image deployment/firstdeployment nginx=nginx:1.27`, then\n`kubectl rollout status deployment/firstdeployment`.\n","explanation_context":"`kubectl set image` patches `.spec.template.spec.containers[].image`, which changes the\nPod template hash and triggers a new ReplicaSet. `kubectl rollout status` blocks until\nthe new ReplicaSet is fully available — the same mechanism `kubectl rollout undo` reverses.\n","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = '8d979332-41b9-5f85-9a37-e15f4ff97ee9', updated_at = now()
WHERE id = '8a39f024-139f-52e2-ba2a-2c6c4c5cc370' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('18597e54-2b4f-598f-9f1f-86857c5162e6', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Lab: DaemonSet', 'lab', 2, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('bb0913dc-02d9-580b-95e0-0023ff31b9ea', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '18597e54-2b4f-598f-9f1f-86857c5162e6', 'module', 'Lab: DaemonSet', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/daemonset.yaml <<'MFEOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: logdaemonset
  labels:
    app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:
      # this toleration is to have the daemonset runnable on master nodes
      # remove it if your masters can't run pods
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('894fa5fd-ee5e-57a2-9c0f-aaa24d3d8b6f', 'bb0913dc-02d9-580b-95e0-0023ff31b9ea', 1, 'Create the logdaemonset DaemonSet', $md$Apply `daemonset.yaml` (already in your workdir) to create a DaemonSet named
**logdaemonset** with label `app=fluentd-logging` and pod selector
`matchLabels: name=fluentd-elasticsearch`.
$md$, $script$#!/bin/bash
kubectl get daemonset logdaemonset >/dev/null 2>&1 || exit 1
kubectl get daemonset logdaemonset -o jsonpath='{.metadata.labels.app}' | grep -qx fluentd-logging || exit 1
kubectl get daemonset logdaemonset -o jsonpath='{.spec.selector.matchLabels.name}' | grep -qx fluentd-elasticsearch
$script$, 'Use `kubectl apply -f daemonset.yaml`.', '`kubectl apply` creates the DaemonSet API object from the manifest. Unlike a Deployment, a
DaemonSet has no `replicas` field — its `.spec.selector` must match
`.spec.template.metadata.labels` exactly, and the DaemonSet controller normally uses that
template to run one Pod per eligible node.
', 15, false, true),
('4b7e4d22-9586-5d72-9008-a146a87a2f89', 'bb0913dc-02d9-580b-95e0-0023ff31b9ea', 2, 'Confirm the fluentd-elasticsearch container spec', $md$Confirm that `logdaemonset`'s pod template defines a single container named
**fluentd-elasticsearch** running image `quay.io/fluentd_elasticsearch/fluentd:v2.5.2`,
with a memory limit of `200Mi` and requests of `cpu: 100m` / `memory: 200Mi`.
$md$, $script$#!/bin/bash
NAME=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].name}')
IMAGE=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].image}')
LIMIT=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')
REQCPU=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
REQMEM=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}')
echo "$NAME" | grep -qx fluentd-elasticsearch || exit 1
echo "$IMAGE" | grep -qx "quay.io/fluentd_elasticsearch/fluentd:v2.5.2" || exit 1
echo "$LIMIT" | grep -qx 200Mi || exit 1
echo "$REQCPU" | grep -qx 100m || exit 1
echo "$REQMEM" | grep -qx 200Mi
$script$, 'Inspect `.spec.template.spec.containers[0]` with `kubectl get daemonset logdaemonset -o yaml`.
', 'A DaemonSet''s `.spec.template` is the Pod template every node-local copy is stamped from —
it is structurally identical to a Deployment''s template. Setting `resources.limits.memory`
without a matching `resources.limits.cpu` leaves the container''s CPU unbounded while still
capping memory.
', 15, false, false),
('218aa489-dbd2-5930-a1d1-5585eb40a96a', 'bb0913dc-02d9-580b-95e0-0023ff31b9ea', 3, 'Confirm the hostPath volumes and mounts', $md$Confirm `logdaemonset` declares two `hostPath` volumes — **varlog** (`/var/log`) and
**varlibdockercontainers** (`/var/lib/docker/containers`) — and that the container mounts
`varlibdockercontainers` as `readOnly`.
$md$, $script$#!/bin/bash
VARLOG=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.volumes[?(@.name=="varlog")].hostPath.path}')
VARLIB=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.volumes[?(@.name=="varlibdockercontainers")].hostPath.path}')
echo "$VARLOG" | grep -qx /var/log || exit 1
echo "$VARLIB" | grep -qx /var/lib/docker/containers || exit 1
RO=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.name=="varlibdockercontainers")].readOnly}')
echo "$RO" | grep -qx true
$script$, 'Inspect `.spec.template.spec.volumes` and `.spec.template.spec.containers[0].volumeMounts`
with `kubectl get daemonset logdaemonset -o yaml`.
', '`hostPath` volumes mount a path from the **node''s own filesystem** into the Pod — this is
how a logging DaemonSet like fluentd reads every other Pod''s log files (`/var/log`) and
container runtime state (`/var/lib/docker/containers`) without those files ever going
through the container image. Mounting the containers directory `readOnly: true` stops the
log shipper from ever mutating runtime state it only needs to read.
', 15, false, false),
('e9b73a24-e557-54c3-b837-b0a78a17a910', 'bb0913dc-02d9-580b-95e0-0023ff31b9ea', 4, 'Confirm the master-node toleration', $md$Confirm `logdaemonset`'s pod template tolerates the `node-role.kubernetes.io/master` taint
with effect `NoSchedule`, as declared in `daemonset.yaml`.
$md$, $script$#!/bin/bash
KEY=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.tolerations[0].key}')
EFFECT=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.tolerations[0].effect}')
echo "$KEY" | grep -qx node-role.kubernetes.io/master || exit 1
echo "$EFFECT" | grep -qx NoSchedule
$script$, 'Use `kubectl get daemonset logdaemonset -o jsonpath=''{.spec.template.spec.tolerations}''`.
', 'DaemonSets commonly tolerate the control-plane''s `NoSchedule` taint because node-local
agents — log shippers, CNI plugins, monitoring agents — need to run on every node,
including control-plane nodes that regular workloads are excluded from. This lab''s single
fake node carries the `node-role.kubernetes.io/agent` label and no taints at all, so the
toleration is inert here — it exists purely to demonstrate the pattern.
', 10, false, false),
('689b197f-1485-5f10-8fcf-756074400688', 'bb0913dc-02d9-580b-95e0-0023ff31b9ea', 5, 'Confirm the DaemonSet controller never reconciles Pods in this lab', $md$This lab's `kube-controller-manager` is started with an explicit `--controllers` allowlist
that does **not** include `daemonset` — so, unlike the Deployment lab, no controller ever
reads `logdaemonset`'s spec and turns it into Pods. Confirm this:
`.status.desiredNumberScheduled` and `.status.numberReady` on `logdaemonset` both remain
`0`, and no Pod carrying the `name=fluentd-elasticsearch` selector label exists anywhere in
the cluster — even though the single fake node would otherwise be perfectly eligible (no
`nodeSelector`, no unsatisfied taint).
$md$, $script$#!/bin/bash
DESIRED=$(kubectl get daemonset logdaemonset -o jsonpath='{.status.desiredNumberScheduled}')
READY=$(kubectl get daemonset logdaemonset -o jsonpath='{.status.numberReady}')
test "${DESIRED:-0}" -eq 0 || exit 1
test "${READY:-0}" -eq 0 || exit 1
COUNT=$(kubectl get pods -l name=fluentd-elasticsearch --no-headers 2>/dev/null | wc -l)
test "$COUNT" -eq 0
$script$, 'Compare `kubectl get daemonset logdaemonset -o yaml`''s `.status` block against
`kubectl get pods -l name=fluentd-elasticsearch` — the object exists, but nothing is
scheduling Pods for it.
', 'A DaemonSet''s `.status` fields (`desiredNumberScheduled`, `currentNumberScheduled`,
`numberReady`, ...) are not computed by the API server — they are written by the DaemonSet
controller inside `kube-controller-manager` as it watches nodes and reconciles one Pod per
eligible node. This lab''s control plane starts `kube-controller-manager` with a scoped
`--controllers` list (`deployment,replicaset,namespace,endpoint,endpointslice,
endpointslicemirroring,resourcequota,garbagecollector`) that omits `daemonset`, so
`logdaemonset` sits in etcd as a valid, well-formed spec that nothing ever acts on — a
useful reminder that a resource existing in the API is not the same as a controller
reconciling it.
', 20, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('e858ff7d-9bf2-5c07-b12b-e0ffb4e9af9f', 'bb0913dc-02d9-580b-95e0-0023ff31b9ea', 1, $json$[{"id":"894fa5fd-ee5e-57a2-9c0f-aaa24d3d8b6f","lab_id":"bb0913dc-02d9-580b-95e0-0023ff31b9ea","position":1,"title":"Create the logdaemonset DaemonSet","description":"Apply `daemonset.yaml` (already in your workdir) to create a DaemonSet named\n**logdaemonset** with label `app=fluentd-logging` and pod selector\n`matchLabels: name=fluentd-elasticsearch`.\n","verification_script":"#!/bin/bash\nkubectl get daemonset logdaemonset \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get daemonset logdaemonset -o jsonpath='{.metadata.labels.app}' | grep -qx fluentd-logging || exit 1\nkubectl get daemonset logdaemonset -o jsonpath='{.spec.selector.matchLabels.name}' | grep -qx fluentd-elasticsearch\n","hint_context":"Use `kubectl apply -f daemonset.yaml`.","explanation_context":"`kubectl apply` creates the DaemonSet API object from the manifest. Unlike a Deployment, a\nDaemonSet has no `replicas` field — its `.spec.selector` must match\n`.spec.template.metadata.labels` exactly, and the DaemonSet controller normally uses that\ntemplate to run one Pod per eligible node.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"4b7e4d22-9586-5d72-9008-a146a87a2f89","lab_id":"bb0913dc-02d9-580b-95e0-0023ff31b9ea","position":2,"title":"Confirm the fluentd-elasticsearch container spec","description":"Confirm that `logdaemonset`'s pod template defines a single container named\n**fluentd-elasticsearch** running image `quay.io/fluentd_elasticsearch/fluentd:v2.5.2`,\nwith a memory limit of `200Mi` and requests of `cpu: 100m` / `memory: 200Mi`.\n","verification_script":"#!/bin/bash\nNAME=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].name}')\nIMAGE=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].image}')\nLIMIT=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')\nREQCPU=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')\nREQMEM=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}')\necho \"$NAME\" | grep -qx fluentd-elasticsearch || exit 1\necho \"$IMAGE\" | grep -qx \"quay.io/fluentd_elasticsearch/fluentd:v2.5.2\" || exit 1\necho \"$LIMIT\" | grep -qx 200Mi || exit 1\necho \"$REQCPU\" | grep -qx 100m || exit 1\necho \"$REQMEM\" | grep -qx 200Mi\n","hint_context":"Inspect `.spec.template.spec.containers[0]` with `kubectl get daemonset logdaemonset -o yaml`.\n","explanation_context":"A DaemonSet's `.spec.template` is the Pod template every node-local copy is stamped from —\nit is structurally identical to a Deployment's template. Setting `resources.limits.memory`\nwithout a matching `resources.limits.cpu` leaves the container's CPU unbounded while still\ncapping memory.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"218aa489-dbd2-5930-a1d1-5585eb40a96a","lab_id":"bb0913dc-02d9-580b-95e0-0023ff31b9ea","position":3,"title":"Confirm the hostPath volumes and mounts","description":"Confirm `logdaemonset` declares two `hostPath` volumes — **varlog** (`/var/log`) and\n**varlibdockercontainers** (`/var/lib/docker/containers`) — and that the container mounts\n`varlibdockercontainers` as `readOnly`.\n","verification_script":"#!/bin/bash\nVARLOG=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.volumes[?(@.name==\"varlog\")].hostPath.path}')\nVARLIB=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.volumes[?(@.name==\"varlibdockercontainers\")].hostPath.path}')\necho \"$VARLOG\" | grep -qx /var/log || exit 1\necho \"$VARLIB\" | grep -qx /var/lib/docker/containers || exit 1\nRO=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.name==\"varlibdockercontainers\")].readOnly}')\necho \"$RO\" | grep -qx true\n","hint_context":"Inspect `.spec.template.spec.volumes` and `.spec.template.spec.containers[0].volumeMounts`\nwith `kubectl get daemonset logdaemonset -o yaml`.\n","explanation_context":"`hostPath` volumes mount a path from the **node's own filesystem** into the Pod — this is\nhow a logging DaemonSet like fluentd reads every other Pod's log files (`/var/log`) and\ncontainer runtime state (`/var/lib/docker/containers`) without those files ever going\nthrough the container image. Mounting the containers directory `readOnly: true` stops the\nlog shipper from ever mutating runtime state it only needs to read.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"e9b73a24-e557-54c3-b837-b0a78a17a910","lab_id":"bb0913dc-02d9-580b-95e0-0023ff31b9ea","position":4,"title":"Confirm the master-node toleration","description":"Confirm `logdaemonset`'s pod template tolerates the `node-role.kubernetes.io/master` taint\nwith effect `NoSchedule`, as declared in `daemonset.yaml`.\n","verification_script":"#!/bin/bash\nKEY=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.tolerations[0].key}')\nEFFECT=$(kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.tolerations[0].effect}')\necho \"$KEY\" | grep -qx node-role.kubernetes.io/master || exit 1\necho \"$EFFECT\" | grep -qx NoSchedule\n","hint_context":"Use `kubectl get daemonset logdaemonset -o jsonpath='{.spec.template.spec.tolerations}'`.\n","explanation_context":"DaemonSets commonly tolerate the control-plane's `NoSchedule` taint because node-local\nagents — log shippers, CNI plugins, monitoring agents — need to run on every node,\nincluding control-plane nodes that regular workloads are excluded from. This lab's single\nfake node carries the `node-role.kubernetes.io/agent` label and no taints at all, so the\ntoleration is inert here — it exists purely to demonstrate the pattern.\n","points":10,"is_optional":false,"is_stateful":false},{"id":"689b197f-1485-5f10-8fcf-756074400688","lab_id":"bb0913dc-02d9-580b-95e0-0023ff31b9ea","position":5,"title":"Confirm the DaemonSet controller never reconciles Pods in this lab","description":"This lab's `kube-controller-manager` is started with an explicit `--controllers` allowlist\nthat does **not** include `daemonset` — so, unlike the Deployment lab, no controller ever\nreads `logdaemonset`'s spec and turns it into Pods. Confirm this:\n`.status.desiredNumberScheduled` and `.status.numberReady` on `logdaemonset` both remain\n`0`, and no Pod carrying the `name=fluentd-elasticsearch` selector label exists anywhere in\nthe cluster — even though the single fake node would otherwise be perfectly eligible (no\n`nodeSelector`, no unsatisfied taint).\n","verification_script":"#!/bin/bash\nDESIRED=$(kubectl get daemonset logdaemonset -o jsonpath='{.status.desiredNumberScheduled}')\nREADY=$(kubectl get daemonset logdaemonset -o jsonpath='{.status.numberReady}')\ntest \"${DESIRED:-0}\" -eq 0 || exit 1\ntest \"${READY:-0}\" -eq 0 || exit 1\nCOUNT=$(kubectl get pods -l name=fluentd-elasticsearch --no-headers 2\u003e/dev/null | wc -l)\ntest \"$COUNT\" -eq 0\n","hint_context":"Compare `kubectl get daemonset logdaemonset -o yaml`'s `.status` block against\n`kubectl get pods -l name=fluentd-elasticsearch` — the object exists, but nothing is\nscheduling Pods for it.\n","explanation_context":"A DaemonSet's `.status` fields (`desiredNumberScheduled`, `currentNumberScheduled`,\n`numberReady`, ...) are not computed by the API server — they are written by the DaemonSet\ncontroller inside `kube-controller-manager` as it watches nodes and reconciles one Pod per\neligible node. This lab's control plane starts `kube-controller-manager` with a scoped\n`--controllers` list (`deployment,replicaset,namespace,endpoint,endpointslice,\nendpointslicemirroring,resourcequota,garbagecollector`) that omits `daemonset`, so\n`logdaemonset` sits in etcd as a valid, well-formed spec that nothing ever acts on — a\nuseful reminder that a resource existing in the API is not the same as a controller\nreconciling it.\n","points":20,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'e858ff7d-9bf2-5c07-b12b-e0ffb4e9af9f', updated_at = now()
WHERE id = 'bb0913dc-02d9-580b-95e0-0023ff31b9ea' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('eef498be-cf84-549f-bcc0-9d59d5bc9f8d', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Lab: StatefulSet', 'lab', 3, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('7827e8aa-3e5c-54a0-b5b6-c88138a496d6', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'eef498be-cf84-549f-bcc0-9d59d5bc9f8d', 'module', 'Lab: StatefulSet', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/statefulset.yaml <<'MFEOF'
apiVersion: v1
kind: Service
metadata:
  labels:
    app: cassandra
  name: cassandra
spec:
  clusterIP: None
  ports:
  - port: 9042
  selector:
    app: cassandra
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cassandra
  labels:
    app: cassandra
spec:
  serviceName: cassandra
  replicas: 2
  selector:
    matchLabels:
      app: cassandra
  template:
    metadata:
      labels:
        app: cassandra
    spec:
      terminationGracePeriodSeconds: 1800
      containers:
      - name: cassandra
        image: gcr.io/google-samples/cassandra:v13
        imagePullPolicy: Always
        ports:
        - containerPort: 7000
          name: intra-node
        - containerPort: 7001
          name: tls-intra-node
        - containerPort: 7199
          name: jmx
        - containerPort: 9042
          name: cql
        resources:
          limits:
            cpu: "500m"
            memory: 1Gi
          requests:
            cpu: "500m"
            memory: 1Gi
        securityContext:
          capabilities:
            add:
              - IPC_LOCK
        lifecycle:
          preStop:
            exec:
              command: 
              - /bin/sh
              - -c
              - nodetool drain
        env:
          - name: MAX_HEAP_SIZE
            value: 512M
          - name: HEAP_NEWSIZE
            value: 100M
          - name: CASSANDRA_SEEDS
            value: "cassandra-0.cassandra.default.svc.cluster.local"
          - name: CASSANDRA_CLUSTER_NAME
            value: "K8Demo"
          - name: CASSANDRA_DC
            value: "DC1-K8Demo"
          - name: CASSANDRA_RACK
            value: "Rack1-K8Demo"
          - name: POD_IP
            valueFrom:
              fieldRef:
                fieldPath: status.podIP
        readinessProbe:
          exec:
            command:
            - /bin/bash
            - -c
            - /ready-probe.sh
          initialDelaySeconds: 15
          timeoutSeconds: 5
        volumeMounts:
        - name: cassandra-data
          mountPath: /cassandra_data
  volumeClaimTemplates:
  - metadata:
      name: cassandra-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: standard
      resources:
        requests:
          storage: 1Gi
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('a47ab844-6c26-5da2-b589-322fd1b5667f', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 1, 'Create the cassandra headless Service and StatefulSet', $md$Apply `statefulset.yaml` (already in your workdir) to create the headless Service and
the StatefulSet, both named **cassandra**, with **2 replicas**.
$md$, $script$#!/bin/bash
kubectl get statefulset cassandra >/dev/null 2>&1 || exit 1
REPLICAS=$(kubectl get statefulset cassandra -o jsonpath='{.spec.replicas}' 2>/dev/null)
test "${REPLICAS:-0}" -eq 2
$script$, 'Use `kubectl apply -f statefulset.yaml`.', '`kubectl apply` creates both objects declared in the multi-document manifest — the
headless Service `cassandra` and the StatefulSet `cassandra` with `replicas: 2`. This
lab''s cluster runs `kube-controller-manager` with a restricted `--controllers` allowlist
that excludes `statefulset` (see the note on the last task below), so this check verifies
the object was accepted and its desired spec is correct rather than that any Pod actually
started — on a real cluster the StatefulSet controller would additionally create Pods one
at a time, in order, waiting for each to become Ready before starting the next.
', 15, false, true),
('b28af346-828d-5594-8772-9358e8ffe977', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 2, 'Confirm the cassandra Service is headless and governs the StatefulSet', $md$Confirm that the **cassandra** Service has `clusterIP: None` (headless), selects Pods
labeled `app=cassandra`, and forwards port `9042`.
$md$, $script$#!/bin/bash
kubectl get svc cassandra -o jsonpath='{.spec.clusterIP}' | grep -qx None || exit 1
kubectl get svc cassandra -o jsonpath='{.spec.selector.app}' | grep -qx cassandra || exit 1
kubectl get svc cassandra -o jsonpath='{.spec.ports[0].port}' | grep -qx 9042
$script$, 'Inspect `kubectl get svc cassandra -o jsonpath=''{.spec.clusterIP}''` — a headless Service
has no cluster-assigned virtual IP.
', 'A headless Service (`clusterIP: None`) skips load-balancing and virtual-IP allocation
entirely — instead it publishes one DNS record per ready backing Pod
(`<pod>.<svc>.<namespace>.svc.cluster.local`). A StatefulSet''s `spec.serviceName` must
point at a headless Service like this one to get per-Pod stable network identities.
', 15, false, false),
('78bad25c-7c03-5be9-a6c1-8959fe2b41a8', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 3, 'Confirm the cassandra container''s ports and security context', $md$Confirm the `cassandra` container in the Pod template declares its four named ports
(`intra-node` 7000, `tls-intra-node` 7001, `jmx` 7199, `cql` 9042) and requests the
`IPC_LOCK` capability (Cassandra uses it to lock memory pages and avoid swapping).
$md$, $script$#!/bin/bash
PORTS=$(kubectl get statefulset cassandra -o jsonpath='{.spec.template.spec.containers[0].ports[*].name}')
for p in intra-node tls-intra-node jmx cql; do
  echo "$PORTS" | grep -qw "$p" || exit 1
done
kubectl get statefulset cassandra -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.add[0]}' | grep -qx IPC_LOCK
$script$, 'Inspect `.spec.template.spec.containers[0].ports` and
`.spec.template.spec.containers[0].securityContext.capabilities.add` on the StatefulSet.
', 'These fields live on the StatefulSet''s own Pod template, so they''re verifiable
immediately after `kubectl apply` — independent of whether any Pod actually got created
from that template (see the note on the last task in this lab).
', 20, false, false),
('fbb19cc9-df75-5309-ba42-fc3f015ec926', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 4, 'Confirm the governing service wiring and predictable per-Pod DNS', $md$Confirm that the StatefulSet's `spec.serviceName` is set to `cassandra` (the headless
Service), and that the container's `CASSANDRA_SEEDS` environment variable is pinned to
the predictable per-Pod DNS name `cassandra-0.cassandra.default.svc.cluster.local` —
proof that StatefulSet Pods get stable, resolvable hostnames that Deployment Pods never
do.
$md$, $script$#!/bin/bash
kubectl get statefulset cassandra -o jsonpath='{.spec.serviceName}' | grep -qx cassandra || exit 1
kubectl get statefulset cassandra -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="CASSANDRA_SEEDS")].value}' | grep -qx cassandra-0.cassandra.default.svc.cluster.local
$script$, 'Check `.spec.serviceName` on the StatefulSet, and `.spec.template.spec.containers[0].env`
for the `CASSANDRA_SEEDS` entry.
', '`spec.serviceName` wires the StatefulSet to its governing headless Service, which is what
makes `<pod>.<serviceName>.<namespace>.svc.cluster.local` resolvable per Pod. This
manifest hardcodes `CASSANDRA_SEEDS` to `cassandra-0.cassandra...` specifically because
`cassandra-0` is guaranteed to exist at a fixed name — every other Cassandra node
bootstraps by gossiping to that one stable address.
', 15, false, false),
('8847b1c3-7f5e-5648-a7d1-ce3357d8d486', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 5, 'Confirm the per-replica volumeClaimTemplates declaration', $md$Confirm that the StatefulSet's `volumeClaimTemplates` declares a `cassandra-data` claim
template with `ReadWriteOnce` access mode, `storageClassName: standard`, and a `1Gi`
storage request — the template Kubernetes uses to provision one separate,
stably-named PersistentVolumeClaim per replica (`cassandra-data-cassandra-0`,
`cassandra-data-cassandra-1`, ...) on a cluster where the StatefulSet controller runs.
$md$, $script$#!/bin/bash
kubectl get statefulset cassandra -o jsonpath='{.spec.volumeClaimTemplates[0].metadata.name}' | grep -qx cassandra-data || exit 1
kubectl get statefulset cassandra -o jsonpath='{.spec.volumeClaimTemplates[0].spec.accessModes[0]}' | grep -qx ReadWriteOnce || exit 1
kubectl get statefulset cassandra -o jsonpath='{.spec.volumeClaimTemplates[0].spec.storageClassName}' | grep -qx standard || exit 1
kubectl get statefulset cassandra -o jsonpath='{.spec.volumeClaimTemplates[0].spec.resources.requests.storage}' | grep -qx 1Gi
$script$, 'Inspect `.spec.volumeClaimTemplates[0]` on the StatefulSet object itself.
', 'A Deployment''s Pods sharing a single `PersistentVolumeClaim` would all mount the *same*
volume — rarely what a stateful workload wants. `volumeClaimTemplates` instead provisions
one PVC per ordinal, and each PVC survives Pod rescheduling because it is bound to the
ordinal, not to any one Pod instance — `cassandra-1` always reattaches to
`cassandra-data-cassandra-1` on a cluster where the controller actually creates them.
', 15, false, false),
('11bb4478-7e9f-56e3-b8c2-0655d3bb26b0', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 6, 'Scale the cassandra StatefulSet''s desired replica count to 3', $md$Scale the **cassandra** StatefulSet's desired replica count up to **3** using
`kubectl scale`.
$md$, $script$#!/bin/bash
DESIRED=$(kubectl get statefulset cassandra -o jsonpath='{.spec.replicas}' 2>/dev/null)
test "${DESIRED:-0}" -eq 3
$script$, 'Use `kubectl scale statefulset cassandra --replicas=3`.', '`kubectl scale` only ever updates `.spec.replicas` — the desired state. On a real cluster
the StatefulSet controller reconciles that desired state by adding the *next* ordinal
(here `cassandra-2`) without renumbering or replacing existing Pods, and provisions a
matching `cassandra-data-cassandra-2` PVC from `volumeClaimTemplates`.
', 15, false, true),
('1b04c301-c4c8-5284-9343-813ef03c1a0c', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 7, 'Understand why no Pods appear for this StatefulSet', $md$Confirm that, despite `.spec.replicas` being set, **no Pods with label `app=cassandra`
exist** in this lab's cluster.
$md$, $script$#!/bin/bash
COUNT=$(kubectl get pods -l app=cassandra --no-headers 2>/dev/null | wc -l)
test "${COUNT:-1}" -eq 0
$script$, 'Run `kubectl get pods -l app=cassandra` and count the results.', 'This lab''s control plane starts `kube-controller-manager` with an explicit
`--controllers` allowlist (deployment, replicaset, namespace, endpoint, endpointslice,
endpointslicemirroring, resourcequota, garbagecollector) that does **not** include
`statefulset` — so nothing ever reconciles a StatefulSet''s desired replica count into
real Pods here, no matter how long you wait. Every task in this lab therefore checks the
StatefulSet/Service''s own declared spec, which the API server accepts and stores
immediately, rather than runtime Pod/PVC state that only a running StatefulSet
controller would produce. On a real cluster (or one with the controller enabled), the
same manifests would produce real, ordered `cassandra-0`/`cassandra-1` Pods with their
own PVCs.
', 10, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('987d401f-cc6f-50ca-a164-a92877c81d76', '7827e8aa-3e5c-54a0-b5b6-c88138a496d6', 1, $json$[{"id":"a47ab844-6c26-5da2-b589-322fd1b5667f","lab_id":"7827e8aa-3e5c-54a0-b5b6-c88138a496d6","position":1,"title":"Create the cassandra headless Service and StatefulSet","description":"Apply `statefulset.yaml` (already in your workdir) to create the headless Service and\nthe StatefulSet, both named **cassandra**, with **2 replicas**.\n","verification_script":"#!/bin/bash\nkubectl get statefulset cassandra \u003e/dev/null 2\u003e\u00261 || exit 1\nREPLICAS=$(kubectl get statefulset cassandra -o jsonpath='{.spec.replicas}' 2\u003e/dev/null)\ntest \"${REPLICAS:-0}\" -eq 2\n","hint_context":"Use `kubectl apply -f statefulset.yaml`.","explanation_context":"`kubectl apply` creates both objects declared in the multi-document manifest — the\nheadless Service `cassandra` and the StatefulSet `cassandra` with `replicas: 2`. This\nlab's cluster runs `kube-controller-manager` with a restricted `--controllers` allowlist\nthat excludes `statefulset` (see the note on the last task below), so this check verifies\nthe object was accepted and its desired spec is correct rather than that any Pod actually\nstarted — on a real cluster the StatefulSet controller would additionally create Pods one\nat a time, in order, waiting for each to become Ready before starting the next.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"b28af346-828d-5594-8772-9358e8ffe977","lab_id":"7827e8aa-3e5c-54a0-b5b6-c88138a496d6","position":2,"title":"Confirm the cassandra Service is headless and governs the StatefulSet","description":"Confirm that the **cassandra** Service has `clusterIP: None` (headless), selects Pods\nlabeled `app=cassandra`, and forwards port `9042`.\n","verification_script":"#!/bin/bash\nkubectl get svc cassandra -o jsonpath='{.spec.clusterIP}' | grep -qx None || exit 1\nkubectl get svc cassandra -o jsonpath='{.spec.selector.app}' | grep -qx cassandra || exit 1\nkubectl get svc cassandra -o jsonpath='{.spec.ports[0].port}' | grep -qx 9042\n","hint_context":"Inspect `kubectl get svc cassandra -o jsonpath='{.spec.clusterIP}'` — a headless Service\nhas no cluster-assigned virtual IP.\n","explanation_context":"A headless Service (`clusterIP: None`) skips load-balancing and virtual-IP allocation\nentirely — instead it publishes one DNS record per ready backing Pod\n(`\u003cpod\u003e.\u003csvc\u003e.\u003cnamespace\u003e.svc.cluster.local`). A StatefulSet's `spec.serviceName` must\npoint at a headless Service like this one to get per-Pod stable network identities.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"78bad25c-7c03-5be9-a6c1-8959fe2b41a8","lab_id":"7827e8aa-3e5c-54a0-b5b6-c88138a496d6","position":3,"title":"Confirm the cassandra container's ports and security context","description":"Confirm the `cassandra` container in the Pod template declares its four named ports\n(`intra-node` 7000, `tls-intra-node` 7001, `jmx` 7199, `cql` 9042) and requests the\n`IPC_LOCK` capability (Cassandra uses it to lock memory pages and avoid swapping).\n","verification_script":"#!/bin/bash\nPORTS=$(kubectl get statefulset cassandra -o jsonpath='{.spec.template.spec.containers[0].ports[*].name}')\nfor p in intra-node tls-intra-node jmx cql; do\n  echo \"$PORTS\" | grep -qw \"$p\" || exit 1\ndone\nkubectl get statefulset cassandra -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.add[0]}' | grep -qx IPC_LOCK\n","hint_context":"Inspect `.spec.template.spec.containers[0].ports` and\n`.spec.template.spec.containers[0].securityContext.capabilities.add` on the StatefulSet.\n","explanation_context":"These fields live on the StatefulSet's own Pod template, so they're verifiable\nimmediately after `kubectl apply` — independent of whether any Pod actually got created\nfrom that template (see the note on the last task in this lab).\n","points":20,"is_optional":false,"is_stateful":false},{"id":"fbb19cc9-df75-5309-ba42-fc3f015ec926","lab_id":"7827e8aa-3e5c-54a0-b5b6-c88138a496d6","position":4,"title":"Confirm the governing service wiring and predictable per-Pod DNS","description":"Confirm that the StatefulSet's `spec.serviceName` is set to `cassandra` (the headless\nService), and that the container's `CASSANDRA_SEEDS` environment variable is pinned to\nthe predictable per-Pod DNS name `cassandra-0.cassandra.default.svc.cluster.local` —\nproof that StatefulSet Pods get stable, resolvable hostnames that Deployment Pods never\ndo.\n","verification_script":"#!/bin/bash\nkubectl get statefulset cassandra -o jsonpath='{.spec.serviceName}' | grep -qx cassandra || exit 1\nkubectl get statefulset cassandra -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name==\"CASSANDRA_SEEDS\")].value}' | grep -qx cassandra-0.cassandra.default.svc.cluster.local\n","hint_context":"Check `.spec.serviceName` on the StatefulSet, and `.spec.template.spec.containers[0].env`\nfor the `CASSANDRA_SEEDS` entry.\n","explanation_context":"`spec.serviceName` wires the StatefulSet to its governing headless Service, which is what\nmakes `\u003cpod\u003e.\u003cserviceName\u003e.\u003cnamespace\u003e.svc.cluster.local` resolvable per Pod. This\nmanifest hardcodes `CASSANDRA_SEEDS` to `cassandra-0.cassandra...` specifically because\n`cassandra-0` is guaranteed to exist at a fixed name — every other Cassandra node\nbootstraps by gossiping to that one stable address.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"8847b1c3-7f5e-5648-a7d1-ce3357d8d486","lab_id":"7827e8aa-3e5c-54a0-b5b6-c88138a496d6","position":5,"title":"Confirm the per-replica volumeClaimTemplates declaration","description":"Confirm that the StatefulSet's `volumeClaimTemplates` declares a `cassandra-data` claim\ntemplate with `ReadWriteOnce` access mode, `storageClassName: standard`, and a `1Gi`\nstorage request — the template Kubernetes uses to provision one separate,\nstably-named PersistentVolumeClaim per replica (`cassandra-data-cassandra-0`,\n`cassandra-data-cassandra-1`, ...) on a cluster where the StatefulSet controller runs.\n","verification_script":"#!/bin/bash\nkubectl get statefulset cassandra -o jsonpath='{.spec.volumeClaimTemplates[0].metadata.name}' | grep -qx cassandra-data || exit 1\nkubectl get statefulset cassandra -o jsonpath='{.spec.volumeClaimTemplates[0].spec.accessModes[0]}' | grep -qx ReadWriteOnce || exit 1\nkubectl get statefulset cassandra -o jsonpath='{.spec.volumeClaimTemplates[0].spec.storageClassName}' | grep -qx standard || exit 1\nkubectl get statefulset cassandra -o jsonpath='{.spec.volumeClaimTemplates[0].spec.resources.requests.storage}' | grep -qx 1Gi\n","hint_context":"Inspect `.spec.volumeClaimTemplates[0]` on the StatefulSet object itself.\n","explanation_context":"A Deployment's Pods sharing a single `PersistentVolumeClaim` would all mount the *same*\nvolume — rarely what a stateful workload wants. `volumeClaimTemplates` instead provisions\none PVC per ordinal, and each PVC survives Pod rescheduling because it is bound to the\nordinal, not to any one Pod instance — `cassandra-1` always reattaches to\n`cassandra-data-cassandra-1` on a cluster where the controller actually creates them.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"11bb4478-7e9f-56e3-b8c2-0655d3bb26b0","lab_id":"7827e8aa-3e5c-54a0-b5b6-c88138a496d6","position":6,"title":"Scale the cassandra StatefulSet's desired replica count to 3","description":"Scale the **cassandra** StatefulSet's desired replica count up to **3** using\n`kubectl scale`.\n","verification_script":"#!/bin/bash\nDESIRED=$(kubectl get statefulset cassandra -o jsonpath='{.spec.replicas}' 2\u003e/dev/null)\ntest \"${DESIRED:-0}\" -eq 3\n","hint_context":"Use `kubectl scale statefulset cassandra --replicas=3`.","explanation_context":"`kubectl scale` only ever updates `.spec.replicas` — the desired state. On a real cluster\nthe StatefulSet controller reconciles that desired state by adding the *next* ordinal\n(here `cassandra-2`) without renumbering or replacing existing Pods, and provisions a\nmatching `cassandra-data-cassandra-2` PVC from `volumeClaimTemplates`.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"1b04c301-c4c8-5284-9343-813ef03c1a0c","lab_id":"7827e8aa-3e5c-54a0-b5b6-c88138a496d6","position":7,"title":"Understand why no Pods appear for this StatefulSet","description":"Confirm that, despite `.spec.replicas` being set, **no Pods with label `app=cassandra`\nexist** in this lab's cluster.\n","verification_script":"#!/bin/bash\nCOUNT=$(kubectl get pods -l app=cassandra --no-headers 2\u003e/dev/null | wc -l)\ntest \"${COUNT:-1}\" -eq 0\n","hint_context":"Run `kubectl get pods -l app=cassandra` and count the results.","explanation_context":"This lab's control plane starts `kube-controller-manager` with an explicit\n`--controllers` allowlist (deployment, replicaset, namespace, endpoint, endpointslice,\nendpointslicemirroring, resourcequota, garbagecollector) that does **not** include\n`statefulset` — so nothing ever reconciles a StatefulSet's desired replica count into\nreal Pods here, no matter how long you wait. Every task in this lab therefore checks the\nStatefulSet/Service's own declared spec, which the API server accepts and stores\nimmediately, rather than runtime Pod/PVC state that only a running StatefulSet\ncontroller would produce. On a real cluster (or one with the controller enabled), the\nsame manifests would produce real, ordered `cassandra-0`/`cassandra-1` Pods with their\nown PVCs.\n","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = '987d401f-cc6f-50ca-a164-a92877c81d76', updated_at = now()
WHERE id = '7827e8aa-3e5c-54a0-b5b6-c88138a496d6' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('1ae9f3c3-5b51-5732-a08b-48e8b115298f', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Lab: Job', 'lab', 4, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('d332d18e-88f9-526f-99bb-c69f6206ab46', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '1ae9f3c3-5b51-5732-a08b-48e8b115298f', 'module', 'Lab: Job', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/job.yaml <<'MFEOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  parallelism: 2
  completions: 10
  backoffLimit: 5
  activeDeadlineSeconds: 100
  template:
    spec:
      containers:
      - name: pi
        image: perl
        command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never #OnFailure 
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('77545f6c-aba1-5807-a651-e54c8853ee41', 'd332d18e-88f9-526f-99bb-c69f6206ab46', 1, 'Create the pi Job', $md$Apply `job.yaml` (already in your workdir) to create a Job named **pi** with
**2** parallel workers (`parallelism: 2`) that must reach **10** successful
completions (`completions: 10`).
$md$, $script$#!/bin/bash
kubectl get job pi >/dev/null 2>&1 || exit 1
COMPLETIONS=$(kubectl get job pi -o jsonpath='{.spec.completions}' 2>/dev/null)
PARALLELISM=$(kubectl get job pi -o jsonpath='{.spec.parallelism}' 2>/dev/null)
test "$COMPLETIONS" = "10" || exit 1
test "$PARALLELISM" = "2"
$script$, 'Use `kubectl apply -f job.yaml`.', '`kubectl apply` creates the Job object with `.spec.completions` and
`.spec.parallelism` set from the manifest. Unlike a Deployment, a Job''s controller
drives Pods to successful completion rather than keeping them running forever.
', 15, false, true),
('f72e47de-4740-50cf-b8e3-cb83164aa613', 'd332d18e-88f9-526f-99bb-c69f6206ab46', 2, 'Confirm the Job''s retry and deadline limits', $md$Confirm that the **pi** Job has `backoffLimit: 5` and
`activeDeadlineSeconds: 100`, as declared in `job.yaml`.
$md$, $script$#!/bin/bash
BACKOFF=$(kubectl get job pi -o jsonpath='{.spec.backoffLimit}' 2>/dev/null)
DEADLINE=$(kubectl get job pi -o jsonpath='{.spec.activeDeadlineSeconds}' 2>/dev/null)
test "$BACKOFF" = "5" || exit 1
test "$DEADLINE" = "100"
$script$, 'Inspect the Job spec with `kubectl get job pi -o yaml` or query
`.spec.backoffLimit` and `.spec.activeDeadlineSeconds` directly with `jsonpath`.
', '`backoffLimit` caps how many times the Job controller retries a failed Pod before
marking the Job itself as failed. `activeDeadlineSeconds` is a hard wall-clock
ceiling on the whole Job — once exceeded, the Job is terminated regardless of
`backoffLimit`, which protects against a retry loop that never gives up on its own.
', 10, false, false),
('8a49b607-46e3-51a6-8455-494113a698e8', 'd332d18e-88f9-526f-99bb-c69f6206ab46', 3, 'Confirm the pi container''s image, command, and restart policy', $md$Confirm that the **pi** Job's Pod template runs container `pi` on image `perl`,
with a command that computes `bpi(2000)`, and `restartPolicy: Never`.
$md$, $script$#!/bin/bash
IMAGE=$(kubectl get job pi -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
test "$IMAGE" = "perl" || exit 1
RESTART=$(kubectl get job pi -o jsonpath='{.spec.template.spec.restartPolicy}' 2>/dev/null)
test "$RESTART" = "Never" || exit 1
CMD=$(kubectl get job pi -o jsonpath='{.spec.template.spec.containers[0].command}' 2>/dev/null)
echo "$CMD" | grep -q 'bpi(2000)'
$script$, 'Inspect `.spec.template.spec.containers[0]` for `image` and `command`, and
`.spec.template.spec.restartPolicy` for the restart policy.
', 'A Job''s Pod template only accepts `restartPolicy: Never` or `OnFailure` — never
`Always` — because a Pod that''s supposed to run to completion and stop can''t use
the same "restart forever" policy a long-running Deployment Pod does. `pi`''s
container runs a one-shot Perl computation of pi to 2000 digits, then exits.
', 15, false, false),
('e3e526aa-2e89-5e2f-99b8-be0324840402', 'd332d18e-88f9-526f-99bb-c69f6206ab46', 4, 'Inspect the Job''s completion-tracking status fields', $md$Kubernetes tracks a Job's progress toward its **10** required completions through
`.status.active` and `.status.succeeded` as the Job controller creates and reaps
Pods. Inspect **pi**'s status block with `kubectl get job pi -o yaml` (or
`-o jsonpath`) and confirm the Job is configured to reach that target.
$md$, $script$#!/bin/bash
kubectl get job pi >/dev/null 2>&1 || exit 1
SUCCEEDED=$(kubectl get job pi -o jsonpath='{.status.succeeded}' 2>/dev/null)
ACTIVE=$(kubectl get job pi -o jsonpath='{.status.active}' 2>/dev/null)
COMPLETIONS=$(kubectl get job pi -o jsonpath='{.spec.completions}' 2>/dev/null)
if [ -n "$SUCCEEDED" ] && [ "$SUCCEEDED" -ge 1 ] 2>/dev/null; then exit 0; fi
if [ -n "$ACTIVE" ] && [ "$ACTIVE" -ge 1 ] 2>/dev/null; then exit 0; fi
test "${COMPLETIONS:-0}" = "10"
$script$, 'Check `.status.succeeded` and `.status.active` first. If neither has populated in
this environment, falling back to confirming `.spec.completions` still proves the
Job object is correctly configured to run to 10 successful completions.
', 'In a full cluster, the Job controller watches `.status.active`, `.status.succeeded`,
and `.status.failed`, creating Pods up to `parallelism` until `completions`
successes are reached. This lab''s control plane does not enable the `job` controller
(see `kube-controller-manager`''s `--controllers=` flag), so `pi` never gets Pods
scheduled for it and its status subresource stays empty here — the same declarative
spec you already verified (`completions: 10`) is exactly what a real cluster''s Job
controller would drive toward.
', 15, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('b3f5113a-31a6-5c85-9cda-1dc46de7f15d', 'd332d18e-88f9-526f-99bb-c69f6206ab46', 1, $json$[{"id":"77545f6c-aba1-5807-a651-e54c8853ee41","lab_id":"d332d18e-88f9-526f-99bb-c69f6206ab46","position":1,"title":"Create the pi Job","description":"Apply `job.yaml` (already in your workdir) to create a Job named **pi** with\n**2** parallel workers (`parallelism: 2`) that must reach **10** successful\ncompletions (`completions: 10`).\n","verification_script":"#!/bin/bash\nkubectl get job pi \u003e/dev/null 2\u003e\u00261 || exit 1\nCOMPLETIONS=$(kubectl get job pi -o jsonpath='{.spec.completions}' 2\u003e/dev/null)\nPARALLELISM=$(kubectl get job pi -o jsonpath='{.spec.parallelism}' 2\u003e/dev/null)\ntest \"$COMPLETIONS\" = \"10\" || exit 1\ntest \"$PARALLELISM\" = \"2\"\n","hint_context":"Use `kubectl apply -f job.yaml`.","explanation_context":"`kubectl apply` creates the Job object with `.spec.completions` and\n`.spec.parallelism` set from the manifest. Unlike a Deployment, a Job's controller\ndrives Pods to successful completion rather than keeping them running forever.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"f72e47de-4740-50cf-b8e3-cb83164aa613","lab_id":"d332d18e-88f9-526f-99bb-c69f6206ab46","position":2,"title":"Confirm the Job's retry and deadline limits","description":"Confirm that the **pi** Job has `backoffLimit: 5` and\n`activeDeadlineSeconds: 100`, as declared in `job.yaml`.\n","verification_script":"#!/bin/bash\nBACKOFF=$(kubectl get job pi -o jsonpath='{.spec.backoffLimit}' 2\u003e/dev/null)\nDEADLINE=$(kubectl get job pi -o jsonpath='{.spec.activeDeadlineSeconds}' 2\u003e/dev/null)\ntest \"$BACKOFF\" = \"5\" || exit 1\ntest \"$DEADLINE\" = \"100\"\n","hint_context":"Inspect the Job spec with `kubectl get job pi -o yaml` or query\n`.spec.backoffLimit` and `.spec.activeDeadlineSeconds` directly with `jsonpath`.\n","explanation_context":"`backoffLimit` caps how many times the Job controller retries a failed Pod before\nmarking the Job itself as failed. `activeDeadlineSeconds` is a hard wall-clock\nceiling on the whole Job — once exceeded, the Job is terminated regardless of\n`backoffLimit`, which protects against a retry loop that never gives up on its own.\n","points":10,"is_optional":false,"is_stateful":false},{"id":"8a49b607-46e3-51a6-8455-494113a698e8","lab_id":"d332d18e-88f9-526f-99bb-c69f6206ab46","position":3,"title":"Confirm the pi container's image, command, and restart policy","description":"Confirm that the **pi** Job's Pod template runs container `pi` on image `perl`,\nwith a command that computes `bpi(2000)`, and `restartPolicy: Never`.\n","verification_script":"#!/bin/bash\nIMAGE=$(kubectl get job pi -o jsonpath='{.spec.template.spec.containers[0].image}' 2\u003e/dev/null)\ntest \"$IMAGE\" = \"perl\" || exit 1\nRESTART=$(kubectl get job pi -o jsonpath='{.spec.template.spec.restartPolicy}' 2\u003e/dev/null)\ntest \"$RESTART\" = \"Never\" || exit 1\nCMD=$(kubectl get job pi -o jsonpath='{.spec.template.spec.containers[0].command}' 2\u003e/dev/null)\necho \"$CMD\" | grep -q 'bpi(2000)'\n","hint_context":"Inspect `.spec.template.spec.containers[0]` for `image` and `command`, and\n`.spec.template.spec.restartPolicy` for the restart policy.\n","explanation_context":"A Job's Pod template only accepts `restartPolicy: Never` or `OnFailure` — never\n`Always` — because a Pod that's supposed to run to completion and stop can't use\nthe same \"restart forever\" policy a long-running Deployment Pod does. `pi`'s\ncontainer runs a one-shot Perl computation of pi to 2000 digits, then exits.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"e3e526aa-2e89-5e2f-99b8-be0324840402","lab_id":"d332d18e-88f9-526f-99bb-c69f6206ab46","position":4,"title":"Inspect the Job's completion-tracking status fields","description":"Kubernetes tracks a Job's progress toward its **10** required completions through\n`.status.active` and `.status.succeeded` as the Job controller creates and reaps\nPods. Inspect **pi**'s status block with `kubectl get job pi -o yaml` (or\n`-o jsonpath`) and confirm the Job is configured to reach that target.\n","verification_script":"#!/bin/bash\nkubectl get job pi \u003e/dev/null 2\u003e\u00261 || exit 1\nSUCCEEDED=$(kubectl get job pi -o jsonpath='{.status.succeeded}' 2\u003e/dev/null)\nACTIVE=$(kubectl get job pi -o jsonpath='{.status.active}' 2\u003e/dev/null)\nCOMPLETIONS=$(kubectl get job pi -o jsonpath='{.spec.completions}' 2\u003e/dev/null)\nif [ -n \"$SUCCEEDED\" ] \u0026\u0026 [ \"$SUCCEEDED\" -ge 1 ] 2\u003e/dev/null; then exit 0; fi\nif [ -n \"$ACTIVE\" ] \u0026\u0026 [ \"$ACTIVE\" -ge 1 ] 2\u003e/dev/null; then exit 0; fi\ntest \"${COMPLETIONS:-0}\" = \"10\"\n","hint_context":"Check `.status.succeeded` and `.status.active` first. If neither has populated in\nthis environment, falling back to confirming `.spec.completions` still proves the\nJob object is correctly configured to run to 10 successful completions.\n","explanation_context":"In a full cluster, the Job controller watches `.status.active`, `.status.succeeded`,\nand `.status.failed`, creating Pods up to `parallelism` until `completions`\nsuccesses are reached. This lab's control plane does not enable the `job` controller\n(see `kube-controller-manager`'s `--controllers=` flag), so `pi` never gets Pods\nscheduled for it and its status subresource stays empty here — the same declarative\nspec you already verified (`completions: 10`) is exactly what a real cluster's Job\ncontroller would drive toward.\n","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'b3f5113a-31a6-5c85-9cda-1dc46de7f15d', updated_at = now()
WHERE id = 'd332d18e-88f9-526f-99bb-c69f6206ab46' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('c71cf669-6e2e-5dc6-b600-981dc4f3f7f0', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Lab: CronJob', 'lab', 5, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('18a5fbe4-abd9-5cff-aea3-8f2c6215da35', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c71cf669-6e2e-5dc6-b600-981dc4f3f7f0', 'module', 'Lab: CronJob', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/cronjob.yaml <<'MFEOF'
# https://crontab.guru/
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            imagePullPolicy: IfNotPresent
            command:
            - /bin/sh
            - -c
            - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('c7f86528-d743-5e81-a9ea-2e1ca7ed5539', '18a5fbe4-abd9-5cff-aea3-8f2c6215da35', 1, 'Create the hello CronJob', $md$Apply `cronjob.yaml` (already in your workdir) to create a CronJob named **hello**
with schedule `*/1 * * * *`, running a `busybox` container.
$md$, $script$#!/bin/bash
kubectl get cronjob hello >/dev/null 2>&1 || exit 1
SCHEDULE=$(kubectl get cronjob hello -o jsonpath='{.spec.schedule}')
test "$SCHEDULE" = "*/1 * * * *" || exit 1
IMAGE=$(kubectl get cronjob hello -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}')
test "$IMAGE" = "busybox"
$script$, 'Use `kubectl apply -f cronjob.yaml`.', 'The CronJob controller creates a new Job from `.spec.jobTemplate` each time
`.spec.schedule` fires — `*/1 * * * *` is standard cron syntax for "every minute".
Because a Job wraps a Pod template, that template sits one level deeper here than on a
bare Pod or Deployment: `.spec.jobTemplate.spec.template.spec`.
', 15, false, true),
('87be12f8-04c8-5763-b30f-f348cfa4ecfb', '18a5fbe4-abd9-5cff-aea3-8f2c6215da35', 2, 'Confirm the container command and restartPolicy', $md$Confirm that `hello`'s Job template runs the command
`/bin/sh -c "date; echo Hello from the Kubernetes cluster"` and that the Pod template's
`restartPolicy` is `OnFailure`, exactly as declared in `cronjob.yaml`.
$md$, $script$#!/bin/bash
POLICY=$(kubectl get cronjob hello -o jsonpath='{.spec.jobTemplate.spec.template.spec.restartPolicy}')
test "$POLICY" = "OnFailure" || exit 1
CMD=$(kubectl get cronjob hello -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].command[2]}')
echo "$CMD" | grep -q "Hello from the Kubernetes cluster"
$script$, 'Inspect `.spec.jobTemplate.spec.template.spec` with `jsonpath` — both `restartPolicy`
and `containers[0].command` live there.
', 'A CronJob''s Pod template must set `restartPolicy` to `OnFailure` or `Never` — never the
`Always` default used by long-running controllers like Deployments, since a Job''s Pod is
expected to run to completion rather than restart forever. The container''s `command`
array here overrides `busybox`''s default entrypoint to run a one-off shell command.
', 10, false, false),
('96366eea-16a9-54ad-ba1a-432005e3d09c', '18a5fbe4-abd9-5cff-aea3-8f2c6215da35', 3, 'Suspend the hello CronJob', $md$Suspend the **hello** CronJob so it stops scheduling new Jobs, without deleting it.
Patch `.spec.suspend` to `true`.
$md$, $script$#!/bin/bash
SUSPEND=$(kubectl get cronjob hello -o jsonpath='{.spec.suspend}')
test "$SUSPEND" = "true"
$script$, 'Use `kubectl patch cronjob hello -p ''{"spec":{"suspend":true}}'' --type merge`, or
`kubectl edit cronjob hello`.
', 'Setting `.spec.suspend: true` tells the CronJob controller to stop creating new Jobs
from this schedule while leaving the CronJob object, and any Jobs it already created,
untouched — the standard way to pause a CronJob temporarily (e.g. during an incident)
without losing its configuration.
', 15, false, true),
('35db9ada-13ad-5692-8ce2-f467ae854da9', '18a5fbe4-abd9-5cff-aea3-8f2c6215da35', 4, 'Configure concurrencyPolicy and job history limits', $md$Patch the **hello** CronJob to set `.spec.concurrencyPolicy` to `Forbid` (skip a run
if the previous Job hasn't finished), `.spec.successfulJobsHistoryLimit` to `2`, and
`.spec.failedJobsHistoryLimit` to `1`.
$md$, $script$#!/bin/bash
CP=$(kubectl get cronjob hello -o jsonpath='{.spec.concurrencyPolicy}')
test "$CP" = "Forbid" || exit 1
SJHL=$(kubectl get cronjob hello -o jsonpath='{.spec.successfulJobsHistoryLimit}')
test "$SJHL" = "2" || exit 1
FJHL=$(kubectl get cronjob hello -o jsonpath='{.spec.failedJobsHistoryLimit}')
test "$FJHL" = "1"
$script$, '`kubectl patch cronjob hello -p
''{"spec":{"concurrencyPolicy":"Forbid","successfulJobsHistoryLimit":2,"failedJobsHistoryLimit":1}}''
--type merge`
', '`concurrencyPolicy: Forbid` skips a new run if the previous Job is still active — the
alternatives are `Allow` (the default, runs overlap freely) and `Replace` (cancels the
running Job and starts the new one). `successfulJobsHistoryLimit` and
`failedJobsHistoryLimit` cap how many completed Job objects the controller retains for
inspection before garbage-collecting the oldest ones.
', 20, false, true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('3546b028-3c3a-521c-899a-588034d65714', '18a5fbe4-abd9-5cff-aea3-8f2c6215da35', 1, $json$[{"id":"c7f86528-d743-5e81-a9ea-2e1ca7ed5539","lab_id":"18a5fbe4-abd9-5cff-aea3-8f2c6215da35","position":1,"title":"Create the hello CronJob","description":"Apply `cronjob.yaml` (already in your workdir) to create a CronJob named **hello**\nwith schedule `*/1 * * * *`, running a `busybox` container.\n","verification_script":"#!/bin/bash\nkubectl get cronjob hello \u003e/dev/null 2\u003e\u00261 || exit 1\nSCHEDULE=$(kubectl get cronjob hello -o jsonpath='{.spec.schedule}')\ntest \"$SCHEDULE\" = \"*/1 * * * *\" || exit 1\nIMAGE=$(kubectl get cronjob hello -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}')\ntest \"$IMAGE\" = \"busybox\"\n","hint_context":"Use `kubectl apply -f cronjob.yaml`.","explanation_context":"The CronJob controller creates a new Job from `.spec.jobTemplate` each time\n`.spec.schedule` fires — `*/1 * * * *` is standard cron syntax for \"every minute\".\nBecause a Job wraps a Pod template, that template sits one level deeper here than on a\nbare Pod or Deployment: `.spec.jobTemplate.spec.template.spec`.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"87be12f8-04c8-5763-b30f-f348cfa4ecfb","lab_id":"18a5fbe4-abd9-5cff-aea3-8f2c6215da35","position":2,"title":"Confirm the container command and restartPolicy","description":"Confirm that `hello`'s Job template runs the command\n`/bin/sh -c \"date; echo Hello from the Kubernetes cluster\"` and that the Pod template's\n`restartPolicy` is `OnFailure`, exactly as declared in `cronjob.yaml`.\n","verification_script":"#!/bin/bash\nPOLICY=$(kubectl get cronjob hello -o jsonpath='{.spec.jobTemplate.spec.template.spec.restartPolicy}')\ntest \"$POLICY\" = \"OnFailure\" || exit 1\nCMD=$(kubectl get cronjob hello -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].command[2]}')\necho \"$CMD\" | grep -q \"Hello from the Kubernetes cluster\"\n","hint_context":"Inspect `.spec.jobTemplate.spec.template.spec` with `jsonpath` — both `restartPolicy`\nand `containers[0].command` live there.\n","explanation_context":"A CronJob's Pod template must set `restartPolicy` to `OnFailure` or `Never` — never the\n`Always` default used by long-running controllers like Deployments, since a Job's Pod is\nexpected to run to completion rather than restart forever. The container's `command`\narray here overrides `busybox`'s default entrypoint to run a one-off shell command.\n","points":10,"is_optional":false,"is_stateful":false},{"id":"96366eea-16a9-54ad-ba1a-432005e3d09c","lab_id":"18a5fbe4-abd9-5cff-aea3-8f2c6215da35","position":3,"title":"Suspend the hello CronJob","description":"Suspend the **hello** CronJob so it stops scheduling new Jobs, without deleting it.\nPatch `.spec.suspend` to `true`.\n","verification_script":"#!/bin/bash\nSUSPEND=$(kubectl get cronjob hello -o jsonpath='{.spec.suspend}')\ntest \"$SUSPEND\" = \"true\"\n","hint_context":"Use `kubectl patch cronjob hello -p '{\"spec\":{\"suspend\":true}}' --type merge`, or\n`kubectl edit cronjob hello`.\n","explanation_context":"Setting `.spec.suspend: true` tells the CronJob controller to stop creating new Jobs\nfrom this schedule while leaving the CronJob object, and any Jobs it already created,\nuntouched — the standard way to pause a CronJob temporarily (e.g. during an incident)\nwithout losing its configuration.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"35db9ada-13ad-5692-8ce2-f467ae854da9","lab_id":"18a5fbe4-abd9-5cff-aea3-8f2c6215da35","position":4,"title":"Configure concurrencyPolicy and job history limits","description":"Patch the **hello** CronJob to set `.spec.concurrencyPolicy` to `Forbid` (skip a run\nif the previous Job hasn't finished), `.spec.successfulJobsHistoryLimit` to `2`, and\n`.spec.failedJobsHistoryLimit` to `1`.\n","verification_script":"#!/bin/bash\nCP=$(kubectl get cronjob hello -o jsonpath='{.spec.concurrencyPolicy}')\ntest \"$CP\" = \"Forbid\" || exit 1\nSJHL=$(kubectl get cronjob hello -o jsonpath='{.spec.successfulJobsHistoryLimit}')\ntest \"$SJHL\" = \"2\" || exit 1\nFJHL=$(kubectl get cronjob hello -o jsonpath='{.spec.failedJobsHistoryLimit}')\ntest \"$FJHL\" = \"1\"\n","hint_context":"`kubectl patch cronjob hello -p\n'{\"spec\":{\"concurrencyPolicy\":\"Forbid\",\"successfulJobsHistoryLimit\":2,\"failedJobsHistoryLimit\":1}}'\n--type merge`\n","explanation_context":"`concurrencyPolicy: Forbid` skips a new run if the previous Job is still active — the\nalternatives are `Allow` (the default, runs overlap freely) and `Replace` (cancels the\nrunning Job and starts the new one). `successfulJobsHistoryLimit` and\n`failedJobsHistoryLimit` cap how many completed Job objects the controller retains for\ninspection before garbage-collecting the oldest ones.\n","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = '3546b028-3c3a-521c-899a-588034d65714', updated_at = now()
WHERE id = '18a5fbe4-abd9-5cff-aea3-8f2c6215da35' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('09be7e35-f8da-59d2-a7f4-24dbdcd43335', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the rolling-deployment.yaml example, a Deployment with 10 replicas sets ro...', 'intermediate', 2, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('eaed8dfc-499f-5871-a5c7-ac01c78fe4ad', '09be7e35-f8da-59d2-a7f4-24dbdcd43335', 1, $json${"prompt":"In the rolling-deployment.yaml example, a Deployment with 10 replicas sets rollingUpdate.maxUnavailable to 2 and rollingUpdate.maxSurge to 2. What do these two fields control?","multiple":false,"options":[{"id":"a","text":"maxUnavailable caps how many of the 10 desired pods can be unavailable at once during the update (minimum 8 running); maxSurge caps how many extra pods above 10 can be created temporarily (maximum 12 running)","is_correct":true},{"id":"b","text":"maxUnavailable sets the minimum number of replicas required for the Deployment to exist; maxSurge sets the maximum container image size allowed","is_correct":false},{"id":"c","text":"They configure a DaemonSet's node toleration and readiness probe timing, not a Deployment's rollout","is_correct":false},{"id":"d","text":"They are only used by the Recreate strategy, not RollingUpdate","is_correct":false}],"explanation":"With the RollingUpdate strategy, Kubernetes updates Pods incrementally instead of\ndeleting them all at once. maxUnavailable bounds how many of the desired replicas can\nbe down during the rollout, and maxSurge bounds how many pods above the desired count\ncan be created temporarily to keep capacity up while old Pods are replaced.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('53a5f4f4-3355-57f1-b1b4-093b3c6eeea6', '00000000-0000-0000-0000-000000000001', 'mcq', 'The lesson''s web StatefulSet sets serviceName to nginx and binds to a headles...', 'intermediate', 3, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('476fa969-ea25-5fac-98a6-63975ea89561', '53a5f4f4-3355-57f1-b1b4-093b3c6eeea6', 1, $json${"prompt":"The lesson's web StatefulSet sets serviceName to nginx and binds to a headless Service with clusterIP set to None. What behavior does this combination provide that a Deployment does not?","multiple":false,"options":[{"id":"a","text":"Pods get stable, ordered names (web-0, web-1, web-2, ...) and can be reached individually via podName.serviceName (e.g. web-0.nginx), each with a PersistentVolumeClaim that stays bound to the same pod across restarts","is_correct":true},{"id":"b","text":"Pods are assigned a new random name on every restart, exactly like a Deployment's ReplicaSet","is_correct":false},{"id":"c","text":"The headless Service load-balances requests only, without exposing any individual pod DNS names","is_correct":false},{"id":"d","text":"StatefulSets cannot use PersistentVolumeClaims; only Deployments can request persistent storage","is_correct":false}],"explanation":"A headless Service (clusterIP: None) paired with a StatefulSet's serviceName gives\neach Pod a predictable DNS name of the form podName.serviceName, and\nvolumeClaimTemplates provisions a dedicated PersistentVolumeClaim per Pod that stays\nbound to the same Pod across restarts and rescheduling, unlike a Deployment's\ninterchangeable, randomly-named Pods.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2893878f-2d3d-564b-ac4b-b57da7b7f42b', '00000000-0000-0000-0000-000000000001', 'coding', 'A Deployment''s rollout history is a list of revisions in the order they were ...', 'intermediate', 5, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c962e5ca-3d77-5bdc-a8e8-fa38a77b2f22', '2893878f-2d3d-564b-ac4b-b57da7b7f42b', 1, $json${"prompt":"A Deployment's rollout history is a list of revisions in the order they were created\n(oldest first), each given as `REVISION IMAGE`. Given the history and a target\nrevision number, print the image used at that revision (simulating `kubectl rollout\nundo --to-revision=N`). If the target revision is not in the list, print `not found`.\n\n**Example:**\n```\n3\n1 nginx:1.18\n2 nginx:1.19\n3 httpd:2.4\n2\n```\nOutput: `nginx:1.19`\n","languages":["python","javascript"],"starter_code":{"javascript":"const lines = require('fs').readFileSync(0, 'utf8').trim().split('\\n');\nconst n = parseInt(lines[0]);\nconst revisions = {};\nfor (let i = 1; i \u003c= n; i++) {\n  const parts = lines[i].trim().split(/\\s+/);\n  revisions[parseInt(parts[0])] = parts[1];\n}\nconst target = parseInt(lines[n + 1]);\nconsole.log(revisions[target] !== undefined ? revisions[target] : 'not found');\n","python":"import sys\nlines = sys.stdin.read().split('\\n')\nn = int(lines[0])\nrevisions = {}\nfor i in range(1, n + 1):\n    parts = lines[i].split()\n    revisions[int(parts[0])] = parts[1]\ntarget = int(lines[n + 1])\nprint(revisions.get(target, 'not found'))\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"3\n1 nginx:1.18\n2 nginx:1.19\n3 httpd:2.4\n2\n","expected":"nginx:1.19","hidden":false,"weight":1},{"id":"t2","stdin":"2\n1 nginx\n2 httpd\n5\n","expected":"not found","hidden":true,"weight":1},{"id":"t3","stdin":"4\n1 nginx:1.16\n2 nginx:1.17\n3 nginx:1.18\n4 nginx:1.19\n4\n","expected":"nginx:1.19","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('e3a128e6-a878-5c99-8f3d-da4b25e982f7', '00000000-0000-0000-0000-000000000001', 'Quiz: Workloads & Controllers', 'k8s-workloads-quiz', 'Quiz covering Workloads & Controllers.', 'mixed', 'published', 'module', 'bbd43c7b-762f-5386-84d8-19e2c51b38e8', 15, 60, 5, 10, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('f3b66a57-0295-508b-9564-825cfe718ab3', 'e3a128e6-a878-5c99-8f3d-da4b25e982f7', '09be7e35-f8da-59d2-a7f4-24dbdcd43335', 'eaed8dfc-499f-5871-a5c7-ac01c78fe4ad', 0, 2),
('f17f6eb4-081c-50dd-a8cc-948f4884658c', 'e3a128e6-a878-5c99-8f3d-da4b25e982f7', '53a5f4f4-3355-57f1-b1b4-093b3c6eeea6', '476fa969-ea25-5fac-98a6-63975ea89561', 1, 3),
('44446bd8-c192-58f6-a54e-bb93a325f4bc', 'e3a128e6-a878-5c99-8f3d-da4b25e982f7', '2893878f-2d3d-564b-ac4b-b57da7b7f42b', 'c962e5ca-3d77-5bdc-a8e8-fa38a77b2f22', 2, 5)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('bbd43c7b-762f-5386-84d8-19e2c51b38e8', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'c70cffde-a094-57b7-b0b9-8bbbaa0578e0', 'Quiz: Workloads & Controllers', 'assessment', 6, 15, 'e3a128e6-a878-5c99-8f3d-da4b25e982f7')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Networking
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('aa6659d6-a9c3-5d97-b61f-bf8f18a918fb', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Networking', 3)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes)
VALUES ('21b32b81-f51b-5566-9ed3-ed9d5bebaefe', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'aa6659d6-a9c3-5d97-b61f-bf8f18a918fb', 'Networking', 'notes', 0, $md$
## K8s Service App

## LAB: K8s Service Implementations (ClusterIp, NodePort and LoadBalancer)

This scenario shows how to create Services (ClusterIp, NodePort and LoadBalancer). It goes following:
- Create Deployments for frontend and backend.
- Create ClusterIP Service to reach backend pods.
- Create NodePort Service to reach frontend pods from Internet.
- Create Loadbalancer Service on the cloud K8s cluster to reach frontend pods from Internet.


![image](https://user-images.githubusercontent.com/10358317/149774101-d4cfa70a-f461-4d9d-b2c4-f29de65e0e8b.png) (Ref: Udemy Course: Kubernetes-Temelleri)

### Steps

- Create 3 x front-end and 3 x back-end Pods with following YAML file run ("kubectl apply -f deploy.yaml").
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/service/deploy.yaml

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    team: development
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    team: development
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: ozgurozturknet/k8s:backend
        ports:
        - containerPort: 5000
```

![image](https://user-images.githubusercontent.com/10358317/154670356-f3bcda44-60d3-4d85-a620-920345c5e026.png)

- Run on the terminal: "kubectl get pods -w" (on Linux/WSL2: "watch kubectl get pods")


![image](https://user-images.githubusercontent.com/10358317/149765878-94ec4173-a6ab-4953-9fb2-c1ffff61e4b2.png)

- Create ClusterIP service that connects to backend (selector: app: backend) (run: "kubectl apply -f backend_clusterip.yaml"). 
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/service/backend_clusterip.yaml

``` 
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
    - protocol: TCP
      port: 5000
      targetPort: 5000
``` 

![image](https://user-images.githubusercontent.com/10358317/154670246-fe3466b9-e0d2-42f2-a6e2-37be9e0410bb.png)


- ClusterIP Service created. If any resource in the cluster sends a request to the ClusterIP and Port 5000, this request will reach to one of the pod behind the ClusterIP Service.
- We can show it from frontend pods. 
- Connect one of the front-end pods (list: "kubectl get pods",  connect: "kubectl exec -it frontend-5966c698b4-b664t -- bash")
- In the K8s, there is DNS server (core dns based) that provide us to query ip/name of service.
- When running nslookup (backend), we can reach the complete name and IP of this service (serviceName.namespace.svc.cluster_domain, e.g. backend.default.svc.cluster.local).
- When running curl to the one of the backend pods with port 5000, service provides us to make connection with one of the backend pods.
    
![image](https://user-images.githubusercontent.com/10358317/149767889-29c64bd6-54bf-42bf-b12b-ed83ffedb0a8.png)

- Create NodePort Service to reach frontend pods from the outside of the cluster (run: "kubectl apply -f backend_nodeport.yaml").
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/service/backend_nodeport.yaml

```
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

![image](https://user-images.githubusercontent.com/10358317/154983087-ed031df1-ed5f-4910-b8bd-3bf7197954b2.png)

- With NodePort Service (you can see the image below), frontend pods can be reachable from the opening port (32098). In other words, someone can reach frontend pods via WorkerNodeIP:32098. NodePort service listens all of the worker nodes' port (in this example: port 32098).     
- While working with minikube, it is only possible with minikube tunnelling. Minikube simulates the reaching of the NodeIP:Port with tunneling feature. 

![image](https://user-images.githubusercontent.com/10358317/149769823-a9e00708-c614-41dc-bb73-321483ccf0f3.png)

- On the other terminal, if we run the curl command, we can reach the frontend pods. 

![image](https://user-images.githubusercontent.com/10358317/149770958-87b0c840-92b3-4f9d-81cc-84e725381bf3.png)

- LoadBalancer Service is only available wih cloud services (because in the local cluster, it can not possible to get external-ip of the load-balancer service). So if you have connection to the one of the cloud service (Azure-AKS, AWS EKS, GCP GKE), please create loadbalance service on it (run: "kubectl apply -f backend_loadbalancer.yaml"). 
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/service/backend_loadbalancer.yaml

```
apiVersion: v1
kind: Service
metadata:
  name: frontendlb
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

![image](https://user-images.githubusercontent.com/10358317/154983532-a14b0046-e3a0-48a2-9784-965b80de4f72.png)

- If you run on the cloud, you'll see the external-ip of the loadbalancer service. 

![image](https://user-images.githubusercontent.com/10358317/149772479-a6262368-ab70-4c79-9897-a8162d5dc767.png)

![image](https://user-images.githubusercontent.com/10358317/149772584-705ab659-4e5e-496e-999c-cabaf3c5a9d2.png)

- In addition, it can be possible service with Imperative way (with command).
- kubectl expose deployment <deploymentName> --type=<typeOfService> --name=<nameOfService>

![image](https://user-images.githubusercontent.com/10358317/149773190-44d11369-ee98-400b-b84a-57527fc1fba7.png)
  
## References  <a name="references"></a>
- [udemy-course:Kubernetes-Temelleri](https://www.udemy.com/course/kubernetes-temelleri/)  


## K8s Ingress

## LAB: K8s Ingress

This scenario shows how K8s ingress works on minikube. When browsing urls, ingress controller (nginx) directs traffic to the related services. 

![image](https://user-images.githubusercontent.com/10358317/152985194-76a3cb57-70c4-438a-a714-eae7ef287d83.png)  (ref: Kubernetes.io)


### Steps

- Run minikube on Windows Hyperv or Virtualbox. In this scenario:

``` 
minikube start --driver=hyperv 
or
minikube start --driver=hyperv --force-systemd
```  

- To install ingress controller on K8s cluster, please visit to learn: https://kubernetes.github.io/ingress-nginx/deploy/

- On Minikube, it is only needed to enable ingress controller.

``` 
minikube addons enable ingress
minikube addons list
``` 

![image](https://user-images.githubusercontent.com/10358317/152980050-9f59638e-22d2-4581-a045-0c4199cb0be1.png)

- Copy and save (below) as file on your PC (appingress.yaml). 
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/ingress/appingress.yaml

```     
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: appingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  rules:
    - host: webapp.com
      http:
        paths:
          - path: /blue
            pathType: Prefix
            backend:
              service:
                name: bluesvc
                port:
                  number: 80
          - path: /green
            pathType: Prefix
            backend:
              service:
                name: greensvc
                port:
                  number: 80
```

![image](https://user-images.githubusercontent.com/10358317/154954648-e730fbcd-4eb0-4a4c-a189-f1e9e118cdd0.png)

- Copy and save (below) as file on your PC (todoingress.yaml). 
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/ingress/todoingress.yaml

```     
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: todoingress
spec:
  rules:
    - host: todoapp.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: todosvc
                port:
                  number: 80
```

![image](https://user-images.githubusercontent.com/10358317/154954757-4e873d67-855b-4123-85ce-48b6acfc839e.png)

- Copy and save (below) as file on your PC (deploy.yaml). 
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/ingress/deploy.yaml

```     
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blueapp
  labels:
    app: blue
spec:
  replicas: 2
  selector:
    matchLabels:
      app: blue
  template:
    metadata:
      labels:
        app: blue
    spec:
      containers:
      - name: blueapp
        image: ozgurozturknet/k8s:blue
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /healthcheck
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: bluesvc
spec:
  selector:
    app: blue
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: greenapp
  labels:
    app: green
spec:
  replicas: 2
  selector:
    matchLabels:
      app: green
  template:
    metadata:
      labels:
        app: green
    spec:
      containers:
      - name: greenapp
        image: ozgurozturknet/k8s:green
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /healthcheck
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: greensvc
spec:
  selector:
    app: green
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todoapp
  labels:
    app: todo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: todo
  template:
    metadata:
      labels:
        app: todo
    spec:
      containers:
      - name: todoapp
        image: ozgurozturknet/samplewebapp:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: todosvc
spec:
  selector:
    app: todo
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

![image](https://user-images.githubusercontent.com/10358317/154954983-850acd87-b475-48d4-8d37-d1fa081b8159.png)

![image](https://user-images.githubusercontent.com/10358317/154955115-0e23d6b7-4aa9-4409-8ec7-b658edfda34c.png)

![image](https://user-images.githubusercontent.com/10358317/154955180-ec54ee41-6b40-4d5d-a4e1-3c6ce885a57b.png)

- Run "deploy.yaml" and "appingress.yaml" to create deployments and services

![image](https://user-images.githubusercontent.com/10358317/152984112-aa3b03db-9e8f-4fb2-acf0-4b1150982f29.png)

- Add url-ip on Windows/System32/Drivers/etc/hosts file: 

![image](https://user-images.githubusercontent.com/10358317/152983054-66993f34-0d4b-4381-8ae6-ec8441cb6366.png)

- When running on browser the url "webapp.com/blue", one of the blue app containers return response.

![image](https://user-images.githubusercontent.com/10358317/152982739-c86fac86-c0d6-465b-bc4e-391d4e56eb9f.png)

- When running on browser the url "webapp.com/green", one of the green app containers return response.

![image](https://user-images.githubusercontent.com/10358317/152983147-057503d0-d2f1-45a2-bc35-0117676a2abb.png)

- When running on browser, "todoapp.com":

![image](https://user-images.githubusercontent.com/10358317/152983854-c35588c1-170a-4d02-9573-0e712876bad2.png)

- Hence, we can open services running on the cluster with one IP to the out of the cluster. 

- Delete all yaml file and minikube.

![image](https://user-images.githubusercontent.com/10358317/152985795-d69c713e-b6ae-417e-bf88-0f397ebdaaee.png)

 
### References

https://github.com/aytitech/k8sfundamentals/tree/main/ingress
$md$, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('5956dcae-8351-5454-be0e-c6d05eb582ca', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'aa6659d6-a9c3-5d97-b61f-bf8f18a918fb', 'Lab: Service', 'lab', 1, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('e40fae27-5833-5694-8cfc-f35a4bd4756b', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '5956dcae-8351-5454-be0e-c6d05eb582ca', 'module', 'Lab: Service', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/backend_clusterip.yaml <<'MFEOF'
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
    - protocol: TCP
      port: 5000
      targetPort: 5000
MFEOF
cat > /home/labuser/work/backend_loadbalancer.yaml <<'MFEOF'
apiVersion: v1
kind: Service
metadata:
  name: frontendlb
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
MFEOF
cat > /home/labuser/work/backend_nodeport.yaml <<'MFEOF'
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
MFEOF
cat > /home/labuser/work/deploy.yaml <<'MFEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    team: development
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    team: development
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: ozgurozturknet/k8s:backend
        ports:
        - containerPort: 5000
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('bb2dc2ec-5657-55b7-8aa8-fedf9f983ec0', 'e40fae27-5833-5694-8cfc-f35a4bd4756b', 1, 'Create the frontend and backend Deployments', $md$Apply `deploy.yaml` to create two Deployments: **frontend** (3 replicas, image
`nginx:latest`, label `app=frontend`) and **backend** (3 replicas, image
`ozgurozturknet/k8s:backend`, label `app=backend`).
$md$, $script$#!/bin/bash
kubectl get deployment frontend >/dev/null 2>&1 || exit 1
kubectl get deployment backend >/dev/null 2>&1 || exit 1
FREADY=$(kubectl get deployment frontend -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
BREADY=$(kubectl get deployment backend -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
test "${FREADY:-0}" -ge 3 && test "${BREADY:-0}" -ge 3
$script$, 'Use `kubectl apply -f deploy.yaml`.', '`deploy.yaml` bundles two Deployments in one manifest separated by `---` — `kubectl apply
-f` creates both with a single command, each producing its own ReplicaSet and Pods
matching its own selector.
', 15, false, true),
('2490aafc-5fbc-572d-bff6-ec47c71e61b6', 'e40fae27-5833-5694-8cfc-f35a4bd4756b', 2, 'Expose backend via a ClusterIP Service', $md$Apply `backend_clusterip.yaml` to create a Service named **backend** of type
**ClusterIP** that selects Pods labeled `app=backend` and forwards port `5000` to
`targetPort 5000`.
$md$, $script$#!/bin/bash
kubectl get svc backend >/dev/null 2>&1 || exit 1
kubectl get svc backend -o jsonpath='{.spec.type}' | grep -qx ClusterIP || exit 1
kubectl get svc backend -o jsonpath='{.spec.selector.app}' | grep -qx backend || exit 1
kubectl get svc backend -o jsonpath='{.spec.ports[0].port}' | grep -qx 5000
$script$, 'Use `kubectl apply -f backend_clusterip.yaml`.', 'ClusterIP is the default Service type — it allocates a stable virtual IP reachable only
inside the cluster, and its `selector` determines which Pods'' endpoints get
load-balanced behind it.
', 15, false, true),
('da10ba07-0219-5360-b471-31dcddf2724b', 'e40fae27-5833-5694-8cfc-f35a4bd4756b', 3, 'Expose frontend via a NodePort Service', $md$Apply `backend_nodeport.yaml` to create a Service named **frontend** of type
**NodePort** that selects Pods labeled `app=frontend` and forwards port `80`.
$md$, $script$#!/bin/bash
kubectl get svc frontend >/dev/null 2>&1 || exit 1
kubectl get svc frontend -o jsonpath='{.spec.type}' | grep -qx NodePort || exit 1
kubectl get svc frontend -o jsonpath='{.spec.selector.app}' | grep -qx frontend || exit 1
kubectl get svc frontend -o jsonpath='{.spec.ports[0].port}' | grep -qx 80
$script$, 'Use `kubectl apply -f backend_nodeport.yaml`.', 'NodePort builds on ClusterIP by additionally opening the same port on every cluster node
(default range 30000-32767), making the Service reachable from outside the cluster
without a cloud load balancer.
', 15, false, true),
('e9b6f49b-134c-56dc-9c20-bf8ad45e6ed4', 'e40fae27-5833-5694-8cfc-f35a4bd4756b', 4, 'Expose frontend via a LoadBalancer Service', $md$Apply `backend_loadbalancer.yaml` to create a Service named **frontendlb** of type
**LoadBalancer** that selects Pods labeled `app=frontend` and forwards port `80`.
$md$, $script$#!/bin/bash
kubectl get svc frontendlb >/dev/null 2>&1 || exit 1
kubectl get svc frontendlb -o jsonpath='{.spec.type}' | grep -qx LoadBalancer || exit 1
kubectl get svc frontendlb -o jsonpath='{.spec.selector.app}' | grep -qx frontend
$script$, 'Use `kubectl apply -f backend_loadbalancer.yaml`.', 'LoadBalancer builds on NodePort and asks the cloud provider''s controller to provision an
external load balancer forwarding to the node ports — on a local cluster the external IP
typically stays `<pending>`, but the Service object and its declared type are what this
check confirms.
', 15, false, true),
('18f040b2-71f5-59ae-bd47-4da59f78dafd', 'e40fae27-5833-5694-8cfc-f35a4bd4756b', 5, 'Confirm the backend Service targets the backend Deployment''s Pods', $md$Confirm that the **backend** Service's selector (`app=backend`) matches the Pod template
labels on the **backend** Deployment, so traffic sent to the Service actually reaches
those Pods.
$md$, $script$#!/bin/bash
SVC_SEL=$(kubectl get svc backend -o jsonpath='{.spec.selector.app}' 2>/dev/null)
DEP_LABEL=$(kubectl get deployment backend -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
test -n "$SVC_SEL" && test "$SVC_SEL" = "$DEP_LABEL"
$script$, 'Compare `kubectl get svc backend -o jsonpath=''{.spec.selector}''` against
`kubectl get deployment backend -o jsonpath=''{.spec.template.metadata.labels}''`.
', 'A Service has no idea what a "Deployment" is — it only watches for Pods whose labels
match its `selector` and adds their IPs to its Endpoints/EndpointSlice. If the selector
and Pod template labels drift apart, the Service silently ends up with zero endpoints.
', 10, false, false),
('940d76d5-b9c5-508d-b330-165a0ee892ff', 'e40fae27-5833-5694-8cfc-f35a4bd4756b', 6, 'Confirm the frontend Service was allocated a valid NodePort', $md$Confirm that the **frontend** NodePort Service was allocated a `nodePort` value in the
default range `30000-32767`.
$md$, $script$#!/bin/bash
NP=$(kubectl get svc frontend -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
test -n "$NP" && test "$NP" -ge 30000 && test "$NP" -le 32767
$script$, 'Use `kubectl get svc frontend -o jsonpath=''{.spec.ports[0].nodePort}''`.', 'When a NodePort Service''s manifest doesn''t pin `nodePort` explicitly, the API server
auto-allocates one from the cluster''s configured range — confirming this shows the
Service is fully provisioned, not just accepted by `kubectl apply`.
', 10, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('1986f45e-68ad-5486-9598-8d45ae2ff815', 'e40fae27-5833-5694-8cfc-f35a4bd4756b', 1, $json$[{"id":"bb2dc2ec-5657-55b7-8aa8-fedf9f983ec0","lab_id":"e40fae27-5833-5694-8cfc-f35a4bd4756b","position":1,"title":"Create the frontend and backend Deployments","description":"Apply `deploy.yaml` to create two Deployments: **frontend** (3 replicas, image\n`nginx:latest`, label `app=frontend`) and **backend** (3 replicas, image\n`ozgurozturknet/k8s:backend`, label `app=backend`).\n","verification_script":"#!/bin/bash\nkubectl get deployment frontend \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get deployment backend \u003e/dev/null 2\u003e\u00261 || exit 1\nFREADY=$(kubectl get deployment frontend -o jsonpath='{.status.readyReplicas}' 2\u003e/dev/null)\nBREADY=$(kubectl get deployment backend -o jsonpath='{.status.readyReplicas}' 2\u003e/dev/null)\ntest \"${FREADY:-0}\" -ge 3 \u0026\u0026 test \"${BREADY:-0}\" -ge 3\n","hint_context":"Use `kubectl apply -f deploy.yaml`.","explanation_context":"`deploy.yaml` bundles two Deployments in one manifest separated by `---` — `kubectl apply\n-f` creates both with a single command, each producing its own ReplicaSet and Pods\nmatching its own selector.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"2490aafc-5fbc-572d-bff6-ec47c71e61b6","lab_id":"e40fae27-5833-5694-8cfc-f35a4bd4756b","position":2,"title":"Expose backend via a ClusterIP Service","description":"Apply `backend_clusterip.yaml` to create a Service named **backend** of type\n**ClusterIP** that selects Pods labeled `app=backend` and forwards port `5000` to\n`targetPort 5000`.\n","verification_script":"#!/bin/bash\nkubectl get svc backend \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get svc backend -o jsonpath='{.spec.type}' | grep -qx ClusterIP || exit 1\nkubectl get svc backend -o jsonpath='{.spec.selector.app}' | grep -qx backend || exit 1\nkubectl get svc backend -o jsonpath='{.spec.ports[0].port}' | grep -qx 5000\n","hint_context":"Use `kubectl apply -f backend_clusterip.yaml`.","explanation_context":"ClusterIP is the default Service type — it allocates a stable virtual IP reachable only\ninside the cluster, and its `selector` determines which Pods' endpoints get\nload-balanced behind it.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"da10ba07-0219-5360-b471-31dcddf2724b","lab_id":"e40fae27-5833-5694-8cfc-f35a4bd4756b","position":3,"title":"Expose frontend via a NodePort Service","description":"Apply `backend_nodeport.yaml` to create a Service named **frontend** of type\n**NodePort** that selects Pods labeled `app=frontend` and forwards port `80`.\n","verification_script":"#!/bin/bash\nkubectl get svc frontend \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get svc frontend -o jsonpath='{.spec.type}' | grep -qx NodePort || exit 1\nkubectl get svc frontend -o jsonpath='{.spec.selector.app}' | grep -qx frontend || exit 1\nkubectl get svc frontend -o jsonpath='{.spec.ports[0].port}' | grep -qx 80\n","hint_context":"Use `kubectl apply -f backend_nodeport.yaml`.","explanation_context":"NodePort builds on ClusterIP by additionally opening the same port on every cluster node\n(default range 30000-32767), making the Service reachable from outside the cluster\nwithout a cloud load balancer.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"e9b6f49b-134c-56dc-9c20-bf8ad45e6ed4","lab_id":"e40fae27-5833-5694-8cfc-f35a4bd4756b","position":4,"title":"Expose frontend via a LoadBalancer Service","description":"Apply `backend_loadbalancer.yaml` to create a Service named **frontendlb** of type\n**LoadBalancer** that selects Pods labeled `app=frontend` and forwards port `80`.\n","verification_script":"#!/bin/bash\nkubectl get svc frontendlb \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get svc frontendlb -o jsonpath='{.spec.type}' | grep -qx LoadBalancer || exit 1\nkubectl get svc frontendlb -o jsonpath='{.spec.selector.app}' | grep -qx frontend\n","hint_context":"Use `kubectl apply -f backend_loadbalancer.yaml`.","explanation_context":"LoadBalancer builds on NodePort and asks the cloud provider's controller to provision an\nexternal load balancer forwarding to the node ports — on a local cluster the external IP\ntypically stays `\u003cpending\u003e`, but the Service object and its declared type are what this\ncheck confirms.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"18f040b2-71f5-59ae-bd47-4da59f78dafd","lab_id":"e40fae27-5833-5694-8cfc-f35a4bd4756b","position":5,"title":"Confirm the backend Service targets the backend Deployment's Pods","description":"Confirm that the **backend** Service's selector (`app=backend`) matches the Pod template\nlabels on the **backend** Deployment, so traffic sent to the Service actually reaches\nthose Pods.\n","verification_script":"#!/bin/bash\nSVC_SEL=$(kubectl get svc backend -o jsonpath='{.spec.selector.app}' 2\u003e/dev/null)\nDEP_LABEL=$(kubectl get deployment backend -o jsonpath='{.spec.template.metadata.labels.app}' 2\u003e/dev/null)\ntest -n \"$SVC_SEL\" \u0026\u0026 test \"$SVC_SEL\" = \"$DEP_LABEL\"\n","hint_context":"Compare `kubectl get svc backend -o jsonpath='{.spec.selector}'` against\n`kubectl get deployment backend -o jsonpath='{.spec.template.metadata.labels}'`.\n","explanation_context":"A Service has no idea what a \"Deployment\" is — it only watches for Pods whose labels\nmatch its `selector` and adds their IPs to its Endpoints/EndpointSlice. If the selector\nand Pod template labels drift apart, the Service silently ends up with zero endpoints.\n","points":10,"is_optional":false,"is_stateful":false},{"id":"940d76d5-b9c5-508d-b330-165a0ee892ff","lab_id":"e40fae27-5833-5694-8cfc-f35a4bd4756b","position":6,"title":"Confirm the frontend Service was allocated a valid NodePort","description":"Confirm that the **frontend** NodePort Service was allocated a `nodePort` value in the\ndefault range `30000-32767`.\n","verification_script":"#!/bin/bash\nNP=$(kubectl get svc frontend -o jsonpath='{.spec.ports[0].nodePort}' 2\u003e/dev/null)\ntest -n \"$NP\" \u0026\u0026 test \"$NP\" -ge 30000 \u0026\u0026 test \"$NP\" -le 32767\n","hint_context":"Use `kubectl get svc frontend -o jsonpath='{.spec.ports[0].nodePort}'`.","explanation_context":"When a NodePort Service's manifest doesn't pin `nodePort` explicitly, the API server\nauto-allocates one from the cluster's configured range — confirming this shows the\nService is fully provisioned, not just accepted by `kubectl apply`.\n","points":10,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = '1986f45e-68ad-5486-9598-8d45ae2ff815', updated_at = now()
WHERE id = 'e40fae27-5833-5694-8cfc-f35a4bd4756b' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('a3455546-475e-53a2-9b66-2f2582784d4f', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'aa6659d6-a9c3-5d97-b61f-bf8f18a918fb', 'Lab: Ingress', 'lab', 2, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('515305f6-49ab-5164-9365-5d57c0e9654b', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'a3455546-475e-53a2-9b66-2f2582784d4f', 'module', 'Lab: Ingress', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/appingress.yaml <<'MFEOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: appingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  rules:
    - host: webapp.com
      http:
        paths:
          - path: /blue
            pathType: Prefix
            backend:
              service:
                name: bluesvc
                port:
                  number: 80
          - path: /green
            pathType: Prefix
            backend:
              service:
                name: greensvc
                port:
                  number: 80
MFEOF
cat > /home/labuser/work/deploy.yaml <<'MFEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blueapp
  labels:
    app: blue
spec:
  replicas: 2
  selector:
    matchLabels:
      app: blue
  template:
    metadata:
      labels:
        app: blue
    spec:
      containers:
      - name: blueapp
        image: ozgurozturknet/k8s:blue
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /healthcheck
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: bluesvc
spec:
  selector:
    app: blue
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: greenapp
  labels:
    app: green
spec:
  replicas: 2
  selector:
    matchLabels:
      app: green
  template:
    metadata:
      labels:
        app: green
    spec:
      containers:
      - name: greenapp
        image: ozgurozturknet/k8s:green
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /healthcheck
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: greensvc
spec:
  selector:
    app: green
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todoapp
  labels:
    app: todo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: todo
  template:
    metadata:
      labels:
        app: todo
    spec:
      containers:
      - name: todoapp
        image: ozgurozturknet/samplewebapp:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: todosvc
spec:
  selector:
    app: todo
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
MFEOF
cat > /home/labuser/work/todoingress.yaml <<'MFEOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: todoingress
spec:
  rules:
    - host: todoapp.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: todosvc
                port:
                  number: 80
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('64e46815-1542-5f21-af10-884a3ca9e389', '515305f6-49ab-5164-9365-5d57c0e9654b', 1, 'Create the blue, green, and todo Deployments and Services', $md$Apply `deploy.yaml` to create three Deployment+Service pairs: **blueapp**/**bluesvc**
(2 replicas, image `ozgurozturknet/k8s:blue`, label `app=blue`),
**greenapp**/**greensvc** (2 replicas, image `ozgurozturknet/k8s:green`, label
`app=green`), and **todoapp**/**todosvc** (1 replica, image
`ozgurozturknet/samplewebapp:latest`, label `app=todo`).
$md$, $script$#!/bin/bash
kubectl get deployment blueapp >/dev/null 2>&1 || exit 1
kubectl get deployment greenapp >/dev/null 2>&1 || exit 1
kubectl get deployment todoapp >/dev/null 2>&1 || exit 1
BREADY=$(kubectl get deployment blueapp -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
GREADY=$(kubectl get deployment greenapp -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
TREADY=$(kubectl get deployment todoapp -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
test "${BREADY:-0}" -ge 2 || exit 1
test "${GREADY:-0}" -ge 2 || exit 1
test "${TREADY:-0}" -ge 1 || exit 1
kubectl get svc bluesvc >/dev/null 2>&1 || exit 1
kubectl get svc greensvc >/dev/null 2>&1 || exit 1
kubectl get svc todosvc >/dev/null 2>&1
$script$, 'Use `kubectl apply -f deploy.yaml`.', '`deploy.yaml` bundles three Deployment/Service pairs in one manifest separated by `---`
— `kubectl apply -f` creates all six objects with a single command, giving the Ingress
resources you create next real backends to route to.
', 20, false, true),
('d02ec2c0-0258-5931-966a-638269d6cdd6', '515305f6-49ab-5164-9365-5d57c0e9654b', 2, 'Create the appingress Ingress for the blue/green apps', $md$Apply `appingress.yaml` to create an Ingress named **appingress** carrying the
`nginx.ingress.kubernetes.io/rewrite-target` annotation, routing host `webapp.com`'s
`/blue` path to **bluesvc**:80 and `/green` path to **greensvc**:80.
$md$, $script$#!/bin/bash
kubectl get ingress appingress >/dev/null 2>&1 || exit 1
kubectl get ingress appingress -o jsonpath='{.spec.rules[0].host}' | grep -qx webapp.com || exit 1
kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' | grep -qx bluesvc || exit 1
kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[1].backend.service.name}' | grep -qx greensvc
$script$, 'Use `kubectl apply -f appingress.yaml`.', 'An Ingress declares HTTP routing rules that an Ingress controller (not the API server)
implements — here a single host `webapp.com` fans out to two independent backend
Services based on URL path prefix, letting one entrypoint front both Deployments.
', 15, false, true),
('7080bede-64d6-505c-9606-137b29af9c93', '515305f6-49ab-5164-9365-5d57c0e9654b', 3, 'Create the todoingress Ingress for the todo app', $md$Apply `todoingress.yaml` to create an Ingress named **todoingress** routing host
`todoapp.com`'s `/` path to **todosvc**:80.
$md$, $script$#!/bin/bash
kubectl get ingress todoingress >/dev/null 2>&1 || exit 1
kubectl get ingress todoingress -o jsonpath='{.spec.rules[0].host}' | grep -qx todoapp.com || exit 1
kubectl get ingress todoingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' | grep -qx todosvc || exit 1
kubectl get ingress todoingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' | grep -qx 80
$script$, 'Use `kubectl apply -f todoingress.yaml`.', 'Unlike `appingress`, `todoingress` carries no `rewrite-target` annotation — its single
`/` path maps directly to the backend with no prefix to strip, so no rewrite is needed.
', 15, false, true),
('c268f59d-acb1-5782-935e-91c114913999', '515305f6-49ab-5164-9365-5d57c0e9654b', 4, 'Confirm both appingress path rules are wired correctly', $md$Confirm both path rules on **appingress** are configured correctly — `/blue` routes to
**bluesvc** on port `80` with `pathType: Prefix`, and `/green` routes to **greensvc** on
port `80` with `pathType: Prefix`.
$md$, $script$#!/bin/bash
kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[0].path}' | grep -qx /blue || exit 1
kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[0].pathType}' | grep -qx Prefix || exit 1
kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' | grep -qx 80 || exit 1
kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[1].path}' | grep -qx /green || exit 1
kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[1].pathType}' | grep -qx Prefix || exit 1
kubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[1].backend.service.port.number}' | grep -qx 80
$script$, 'Inspect `.spec.rules[0].http.paths` with `kubectl get ingress appingress -o yaml`.
', '`pathType: Prefix` means the path segment must match as a full URL element (or a prefix
of it) rather than an exact string or unconstrained regex — this is what lets `/blue`
also match `/blue/anything` without spilling into `/green`''s traffic.
', 15, false, false),
('756cc57d-d9a4-5f3f-b34e-3f5c245b3933', '515305f6-49ab-5164-9365-5d57c0e9654b', 5, 'Confirm the rewrite-target annotation on appingress', $md$Confirm **appingress** carries the annotation
`nginx.ingress.kubernetes.io/rewrite-target` set to `/$1`, which rewrites the matched
path before forwarding to the backend.
$md$, $script$#!/bin/bash
VAL=$(kubectl get ingress appingress -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/rewrite-target}' 2>/dev/null)
test "$VAL" = '/$1'
$script$, 'Use `kubectl get ingress appingress -o jsonpath=''{.metadata.annotations}''`.
', 'The `rewrite-target` annotation is an nginx-ingress-controller-specific extension (not
part of the core Ingress API) — combined with the path match, `/$1` strips the `/blue`
or `/green` prefix before proxying, so the backend app sees requests at its own root
path instead of under `/blue` or `/green`.
', 10, false, false),
('b5899886-d38f-5796-8bce-a32d7a2cb35c', '515305f6-49ab-5164-9365-5d57c0e9654b', 6, 'Confirm each Ingress backend Service targets the right Deployment''s Pods', $md$Confirm **bluesvc**, **greensvc**, and **todosvc** each select Pods by the same label
their corresponding Deployment's Pod template sets — `bluesvc` → `app=blue`
(`blueapp`), `greensvc` → `app=green` (`greenapp`), and `todosvc` → `app=todo`
(`todoapp`).
$md$, $script$#!/bin/bash
BSEL=$(kubectl get svc bluesvc -o jsonpath='{.spec.selector.app}' 2>/dev/null)
BLBL=$(kubectl get deployment blueapp -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
test -n "$BSEL" && test "$BSEL" = "$BLBL" || exit 1
GSEL=$(kubectl get svc greensvc -o jsonpath='{.spec.selector.app}' 2>/dev/null)
GLBL=$(kubectl get deployment greenapp -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
test -n "$GSEL" && test "$GSEL" = "$GLBL" || exit 1
TSEL=$(kubectl get svc todosvc -o jsonpath='{.spec.selector.app}' 2>/dev/null)
TLBL=$(kubectl get deployment todoapp -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
test -n "$TSEL" && test "$TSEL" = "$TLBL"
$script$, 'Compare each Service''s `.spec.selector` against its Deployment''s
`.spec.template.metadata.labels`.
', 'An Ingress only ever forwards to a Service by name — it has no visibility into whether
that Service actually has healthy endpoints. If a Service''s `selector` drifted from its
backing Deployment''s Pod template labels, the Ingress and Service would both look
"created" while traffic silently hit zero endpoints.
', 15, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('2b872fd0-5356-53b5-b6d5-5f5b1a03ce39', '515305f6-49ab-5164-9365-5d57c0e9654b', 1, $json$[{"id":"64e46815-1542-5f21-af10-884a3ca9e389","lab_id":"515305f6-49ab-5164-9365-5d57c0e9654b","position":1,"title":"Create the blue, green, and todo Deployments and Services","description":"Apply `deploy.yaml` to create three Deployment+Service pairs: **blueapp**/**bluesvc**\n(2 replicas, image `ozgurozturknet/k8s:blue`, label `app=blue`),\n**greenapp**/**greensvc** (2 replicas, image `ozgurozturknet/k8s:green`, label\n`app=green`), and **todoapp**/**todosvc** (1 replica, image\n`ozgurozturknet/samplewebapp:latest`, label `app=todo`).\n","verification_script":"#!/bin/bash\nkubectl get deployment blueapp \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get deployment greenapp \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get deployment todoapp \u003e/dev/null 2\u003e\u00261 || exit 1\nBREADY=$(kubectl get deployment blueapp -o jsonpath='{.status.readyReplicas}' 2\u003e/dev/null)\nGREADY=$(kubectl get deployment greenapp -o jsonpath='{.status.readyReplicas}' 2\u003e/dev/null)\nTREADY=$(kubectl get deployment todoapp -o jsonpath='{.status.readyReplicas}' 2\u003e/dev/null)\ntest \"${BREADY:-0}\" -ge 2 || exit 1\ntest \"${GREADY:-0}\" -ge 2 || exit 1\ntest \"${TREADY:-0}\" -ge 1 || exit 1\nkubectl get svc bluesvc \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get svc greensvc \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get svc todosvc \u003e/dev/null 2\u003e\u00261\n","hint_context":"Use `kubectl apply -f deploy.yaml`.","explanation_context":"`deploy.yaml` bundles three Deployment/Service pairs in one manifest separated by `---`\n— `kubectl apply -f` creates all six objects with a single command, giving the Ingress\nresources you create next real backends to route to.\n","points":20,"is_optional":false,"is_stateful":true},{"id":"d02ec2c0-0258-5931-966a-638269d6cdd6","lab_id":"515305f6-49ab-5164-9365-5d57c0e9654b","position":2,"title":"Create the appingress Ingress for the blue/green apps","description":"Apply `appingress.yaml` to create an Ingress named **appingress** carrying the\n`nginx.ingress.kubernetes.io/rewrite-target` annotation, routing host `webapp.com`'s\n`/blue` path to **bluesvc**:80 and `/green` path to **greensvc**:80.\n","verification_script":"#!/bin/bash\nkubectl get ingress appingress \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get ingress appingress -o jsonpath='{.spec.rules[0].host}' | grep -qx webapp.com || exit 1\nkubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' | grep -qx bluesvc || exit 1\nkubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[1].backend.service.name}' | grep -qx greensvc\n","hint_context":"Use `kubectl apply -f appingress.yaml`.","explanation_context":"An Ingress declares HTTP routing rules that an Ingress controller (not the API server)\nimplements — here a single host `webapp.com` fans out to two independent backend\nServices based on URL path prefix, letting one entrypoint front both Deployments.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"7080bede-64d6-505c-9606-137b29af9c93","lab_id":"515305f6-49ab-5164-9365-5d57c0e9654b","position":3,"title":"Create the todoingress Ingress for the todo app","description":"Apply `todoingress.yaml` to create an Ingress named **todoingress** routing host\n`todoapp.com`'s `/` path to **todosvc**:80.\n","verification_script":"#!/bin/bash\nkubectl get ingress todoingress \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get ingress todoingress -o jsonpath='{.spec.rules[0].host}' | grep -qx todoapp.com || exit 1\nkubectl get ingress todoingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' | grep -qx todosvc || exit 1\nkubectl get ingress todoingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' | grep -qx 80\n","hint_context":"Use `kubectl apply -f todoingress.yaml`.","explanation_context":"Unlike `appingress`, `todoingress` carries no `rewrite-target` annotation — its single\n`/` path maps directly to the backend with no prefix to strip, so no rewrite is needed.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"c268f59d-acb1-5782-935e-91c114913999","lab_id":"515305f6-49ab-5164-9365-5d57c0e9654b","position":4,"title":"Confirm both appingress path rules are wired correctly","description":"Confirm both path rules on **appingress** are configured correctly — `/blue` routes to\n**bluesvc** on port `80` with `pathType: Prefix`, and `/green` routes to **greensvc** on\nport `80` with `pathType: Prefix`.\n","verification_script":"#!/bin/bash\nkubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[0].path}' | grep -qx /blue || exit 1\nkubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[0].pathType}' | grep -qx Prefix || exit 1\nkubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' | grep -qx 80 || exit 1\nkubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[1].path}' | grep -qx /green || exit 1\nkubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[1].pathType}' | grep -qx Prefix || exit 1\nkubectl get ingress appingress -o jsonpath='{.spec.rules[0].http.paths[1].backend.service.port.number}' | grep -qx 80\n","hint_context":"Inspect `.spec.rules[0].http.paths` with `kubectl get ingress appingress -o yaml`.\n","explanation_context":"`pathType: Prefix` means the path segment must match as a full URL element (or a prefix\nof it) rather than an exact string or unconstrained regex — this is what lets `/blue`\nalso match `/blue/anything` without spilling into `/green`'s traffic.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"756cc57d-d9a4-5f3f-b34e-3f5c245b3933","lab_id":"515305f6-49ab-5164-9365-5d57c0e9654b","position":5,"title":"Confirm the rewrite-target annotation on appingress","description":"Confirm **appingress** carries the annotation\n`nginx.ingress.kubernetes.io/rewrite-target` set to `/$1`, which rewrites the matched\npath before forwarding to the backend.\n","verification_script":"#!/bin/bash\nVAL=$(kubectl get ingress appingress -o jsonpath='{.metadata.annotations.nginx\\.ingress\\.kubernetes\\.io/rewrite-target}' 2\u003e/dev/null)\ntest \"$VAL\" = '/$1'\n","hint_context":"Use `kubectl get ingress appingress -o jsonpath='{.metadata.annotations}'`.\n","explanation_context":"The `rewrite-target` annotation is an nginx-ingress-controller-specific extension (not\npart of the core Ingress API) — combined with the path match, `/$1` strips the `/blue`\nor `/green` prefix before proxying, so the backend app sees requests at its own root\npath instead of under `/blue` or `/green`.\n","points":10,"is_optional":false,"is_stateful":false},{"id":"b5899886-d38f-5796-8bce-a32d7a2cb35c","lab_id":"515305f6-49ab-5164-9365-5d57c0e9654b","position":6,"title":"Confirm each Ingress backend Service targets the right Deployment's Pods","description":"Confirm **bluesvc**, **greensvc**, and **todosvc** each select Pods by the same label\ntheir corresponding Deployment's Pod template sets — `bluesvc` → `app=blue`\n(`blueapp`), `greensvc` → `app=green` (`greenapp`), and `todosvc` → `app=todo`\n(`todoapp`).\n","verification_script":"#!/bin/bash\nBSEL=$(kubectl get svc bluesvc -o jsonpath='{.spec.selector.app}' 2\u003e/dev/null)\nBLBL=$(kubectl get deployment blueapp -o jsonpath='{.spec.template.metadata.labels.app}' 2\u003e/dev/null)\ntest -n \"$BSEL\" \u0026\u0026 test \"$BSEL\" = \"$BLBL\" || exit 1\nGSEL=$(kubectl get svc greensvc -o jsonpath='{.spec.selector.app}' 2\u003e/dev/null)\nGLBL=$(kubectl get deployment greenapp -o jsonpath='{.spec.template.metadata.labels.app}' 2\u003e/dev/null)\ntest -n \"$GSEL\" \u0026\u0026 test \"$GSEL\" = \"$GLBL\" || exit 1\nTSEL=$(kubectl get svc todosvc -o jsonpath='{.spec.selector.app}' 2\u003e/dev/null)\nTLBL=$(kubectl get deployment todoapp -o jsonpath='{.spec.template.metadata.labels.app}' 2\u003e/dev/null)\ntest -n \"$TSEL\" \u0026\u0026 test \"$TSEL\" = \"$TLBL\"\n","hint_context":"Compare each Service's `.spec.selector` against its Deployment's\n`.spec.template.metadata.labels`.\n","explanation_context":"An Ingress only ever forwards to a Service by name — it has no visibility into whether\nthat Service actually has healthy endpoints. If a Service's `selector` drifted from its\nbacking Deployment's Pod template labels, the Ingress and Service would both look\n\"created\" while traffic silently hit zero endpoints.\n","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = '2b872fd0-5356-53b5-b6d5-5f5b1a03ce39', updated_at = now()
WHERE id = '515305f6-49ab-5164-9365-5d57c0e9654b' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('86dec0bf-a9ce-507f-8319-df849b4f01d6', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is the default Service type in Kubernetes, and what is its reachability ...', 'beginner', 2, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a3e36abf-bc69-581d-b10b-52565db1e066', '86dec0bf-a9ce-507f-8319-df849b4f01d6', 1, $json${"prompt":"What is the default Service type in Kubernetes, and what is its reachability scope?","multiple":false,"options":[{"id":"a","text":"ClusterIP is the default type; it is only reachable from within the cluster via a stable internal IP","is_correct":true},{"id":"b","text":"NodePort is the default type; it is reachable from outside the cluster via any node's IP","is_correct":false},{"id":"c","text":"LoadBalancer is the default type; it automatically provisions a cloud load balancer","is_correct":false},{"id":"d","text":"ExternalName is the default type; it maps a Service to a DNS name outside the cluster","is_correct":false}],"explanation":"ClusterIP is the default Service type. It exposes the Service on an internal IP that is\nonly reachable from within the cluster, as shown with the backend Service in the\nlesson, reached from a frontend Pod via nslookup and curl, never from outside the\ncluster. NodePort and LoadBalancer extend reachability outward; ClusterIP does not.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d7012580-149a-58f3-bd4d-8e982b3b5c72', '00000000-0000-0000-0000-000000000001', 'mcq', 'According to the lesson, why can a LoadBalancer Service only get a real exter...', 'intermediate', 3, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5f54da96-9c5b-53bc-aa95-ec867fd8743a', 'd7012580-149a-58f3-bd4d-8e982b3b5c72', 1, $json${"prompt":"According to the lesson, why can a LoadBalancer Service only get a real external IP when running on a cloud-managed cluster such as AKS, EKS, or GKE, and not on a local minikube cluster?","multiple":false,"options":[{"id":"a","text":"Provisioning an external IP requires integration with a cloud provider's load balancer, which a local cluster like minikube does not have","is_correct":true},{"id":"b","text":"LoadBalancer Services require an Ingress controller to be installed first","is_correct":false},{"id":"c","text":"minikube does not support Services of any type","is_correct":false},{"id":"d","text":"LoadBalancer type requires a StatefulSet as the backend workload","is_correct":false}],"explanation":"The lesson notes that a LoadBalancer Service can only be tested with a real\nexternal-ip on a cloud Kubernetes service (Azure AKS, AWS EKS, GCP GKE), because a\nlocal cluster has no cloud load balancer to provision one from. NodePort together with\nminikube's tunneling feature is the workaround used locally.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2d38036d-37e1-569a-9720-81444f8d4bf3', '00000000-0000-0000-0000-000000000001', 'coding', 'You are given a list of Ingress path rules, one per line as `PATH SERVICE`, l...', 'intermediate', 5, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9369c413-692c-5868-8189-f3e0e1fa455b', '2d38036d-37e1-569a-9720-81444f8d4bf3', 1, $json${"prompt":"You are given a list of Ingress path rules, one per line as `PATH SERVICE`, listed in\npriority order, followed by a single request path. A rule matches a request if the\nrequest path starts with the rule's PATH (Prefix matching, like Kubernetes Ingress\n`pathType: Prefix`). Using the first matching rule in the list, print the Service that\nhandles the request. If no rule matches, print `default`.\n\n**Example:**\n```\n2\n/blue bluesvc\n/green greensvc\n/blue/health\n```\nOutput: `bluesvc`\n","languages":["python","javascript"],"starter_code":{"javascript":"const lines = require('fs').readFileSync(0, 'utf8').trim().split('\\n');\nconst n = parseInt(lines[0]);\nconst rules = [];\nfor (let i = 1; i \u003c= n; i++) {\n  const parts = lines[i].trim().split(/\\s+/);\n  rules.push([parts[0], parts[1]]);\n}\nconst request = lines[n + 1].trim();\nlet result = 'default';\nfor (const [path, service] of rules) {\n  if (request.startsWith(path)) {\n    result = service;\n    break;\n  }\n}\nconsole.log(result);\n","python":"import sys\nlines = sys.stdin.read().split('\\n')\nn = int(lines[0])\nrules = []\nfor i in range(1, n + 1):\n    parts = lines[i].split()\n    rules.append((parts[0], parts[1]))\nrequest = lines[n + 1].strip()\nresult = 'default'\nfor path, service in rules:\n    if request.startswith(path):\n        result = service\n        break\nprint(result)\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"2\n/blue bluesvc\n/green greensvc\n/blue/health\n","expected":"bluesvc","hidden":false,"weight":1},{"id":"t2","stdin":"2\n/blue bluesvc\n/green greensvc\n/green\n","expected":"greensvc","hidden":true,"weight":1},{"id":"t3","stdin":"2\n/blue bluesvc\n/green greensvc\n/red\n","expected":"default","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('466e4c8d-1056-5385-bf0c-f1f7cabfdae9', '00000000-0000-0000-0000-000000000001', 'Quiz: Networking', 'k8s-networking-quiz', 'Quiz covering Networking.', 'mixed', 'published', 'module', '7386fddf-29fb-53da-be8b-aa6c29ccd4a3', 15, 60, 5, 10, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('7dcb58be-cef3-54fe-9ed3-8668705c4274', '466e4c8d-1056-5385-bf0c-f1f7cabfdae9', '86dec0bf-a9ce-507f-8319-df849b4f01d6', 'a3e36abf-bc69-581d-b10b-52565db1e066', 0, 2),
('d0a35a28-a6e7-50e9-8635-c4ad37c18daf', '466e4c8d-1056-5385-bf0c-f1f7cabfdae9', 'd7012580-149a-58f3-bd4d-8e982b3b5c72', '5f54da96-9c5b-53bc-aa95-ec867fd8743a', 1, 3),
('b1fb5cec-c572-50b5-8db6-3b00e3dd08f5', '466e4c8d-1056-5385-bf0c-f1f7cabfdae9', '2d38036d-37e1-569a-9720-81444f8d4bf3', '9369c413-692c-5868-8189-f3e0e1fa455b', 2, 5)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('7386fddf-29fb-53da-be8b-aa6c29ccd4a3', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'aa6659d6-a9c3-5d97-b61f-bf8f18a918fb', 'Quiz: Networking', 'assessment', 3, 15, '466e4c8d-1056-5385-bf0c-f1f7cabfdae9')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Configuration & Secrets
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('1c403d8b-6f9e-5fe3-9443-b75a9f3759b4', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Configuration & Secrets', 4)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes)
VALUES ('146803ef-fe94-5911-83c6-a3d8d609fe6a', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '1c403d8b-6f9e-5fe3-9443-b75a9f3759b4', 'Configuration & Secrets', 'notes', 0, $md$
## K8s Configmap

## LAB: K8s Configmap

This scenario shows:
- how to create config map (declerative way),
- how to use configmap: volume and environment variable,
- how to create configmap with command (imperative way),
- how to get/delete configmap


### Steps

- Run minikube  (in this scenario, K8s runs on WSL2- Ubuntu 20.04) ("minikube start")

![image](https://user-images.githubusercontent.com/10358317/153183333-371fe598-d5a4-4b86-9b5d-9e33f35063cc.png)

- Create Yaml file (config.yaml) in your directory and copy the below definition into the file.
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/configmap/configmap.yaml

``` 
apiVersion: v1
kind: ConfigMap
metadata:
  name: myconfigmap               
data:
  db_server: "db.example.com"        # configmap key-value parameters
  database: "mydatabase"
  site.settings: |
    color=blue
    padding:25px
---
apiVersion: v1
kind: Pod
metadata:
  name: configmappod
spec:
  containers:
  - name: configmapcontainer
    image: nginx
    env:                             # configmap using environment variable
      - name: DB_SERVER
        valueFrom:
          configMapKeyRef:           
            name: myconfigmap        # configmap name, from "myconfigmap" 
            key: db_server
      - name: DATABASE
        valueFrom:
          configMapKeyRef:
            name: myconfigmap
            key: database
    volumeMounts:
      - name: config-vol
        mountPath: "/config"
        readOnly: true
  volumes:
    - name: config-vol               # transfer configmap parameters using volume
      configMap:
        name: myconfigmap
```

![image](https://user-images.githubusercontent.com/10358317/154719668-bcd3bdb2-c102-489e-8049-747fd97126f3.png)

- Create configmap and the pod:

![image](https://user-images.githubusercontent.com/10358317/153645965-84f8fe93-e73e-4468-bce4-4d2c3f49546f.png)

- Run bash in the pod:

![image](https://user-images.githubusercontent.com/10358317/153647020-54a0cf44-582f-4aab-8375-18c9d82ca494.png)

- Define configmap with imperative way (--from-file and --from-literal) (create a file and put into "theme=dark")
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/configmap/theme.txt

```
kubectl create configmap myconfigmap2 --from-literal=background=red --from-file=theme.txt
```

![image](https://user-images.githubusercontent.com/10358317/153647730-cf7e1545-ffbf-4fe8-b87e-6f1b59ef71df.png)

- Delete configmap:

![image](https://user-images.githubusercontent.com/10358317/153647842-87c9b154-fb1e-40a4-893a-700a80c94161.png)


## K8s Secret

## LAB: K8s Secret

This scenario shows:
- how to create secrets with file,
- how to use secrets: volume and environment variable,
- how to create secrets with command,
- how to get/delete secrets


### Steps

- Run minikube  (in this scenario, K8s runs on WSL2- Ubuntu 20.04) ("minikube start")

![image](https://user-images.githubusercontent.com/10358317/153183333-371fe598-d5a4-4b86-9b5d-9e33f35063cc.png)

- Create Yaml file (secret.yaml) in your directory and copy the below definition into the file.
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/secret/secret.yaml

``` 
# Secret Object Creation  
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  db_server: db.example.com
  db_username: admin
  db_password: P@ssw0rd!
```

![image](https://user-images.githubusercontent.com/10358317/154717259-629e529e-4178-489e-8d20-bad22faeb782.png)

- Create Yaml file (secret-pods.yaml) in your directory and copy the below definition into the file.
- 3 Pods:
  - secret binding using volume
  - secret binding environment variable: 1. explicitly, 2. implicitly
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/secret/secret-pods.yaml
  
```
apiVersion: v1
kind: Pod
metadata:
  name: secretvolumepod
spec:
  containers:
  - name: secretcontainer
    image: nginx
    volumeMounts:
    - name: secret-vol
      mountPath: /secret
  volumes:
  - name: secret-vol
    secret:
      secretName: mysecret
---
apiVersion: v1
kind: Pod
metadata:
  name: secretenvpod
spec:
  containers:
  - name: secretcontainer
    image: nginx
    env:
      - name: username
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: db_username
      - name: password
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: db_password
      - name: server
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: db_server
---
apiVersion: v1
kind: Pod
metadata:
  name: secretenvallpod
spec:
  containers:
  - name: secretcontainer
    image: nginx
    envFrom:
    - secretRef:
        name: mysecret
```

![image](https://user-images.githubusercontent.com/10358317/154717520-554ae3b6-cb55-4ad6-a2f3-7669c0788f77.png)

![image](https://user-images.githubusercontent.com/10358317/154717625-d688251f-8bb6-44b4-843e-eca7b6496b29.png)

![image](https://user-images.githubusercontent.com/10358317/154717703-49d3e207-15c7-4f3e-afb6-ba712c4dea67.png)

- Create secret object:

![image](https://user-images.githubusercontent.com/10358317/153636591-40f14380-02f2-4bc4-98f9-5f9c6eb7b9a6.png)

- Create pods:

![image](https://user-images.githubusercontent.com/10358317/153636772-246179b9-01b9-4032-8b3c-bd16331f537f.png)

- Describe secret to see details:

![image](https://user-images.githubusercontent.com/10358317/153638070-edba4d19-8ece-4f93-9579-fa9546c4a15d.png)

- Run bash in the secretvolumepod (1st pod):

![image](https://user-images.githubusercontent.com/10358317/153637318-e42326e9-4dc3-490d-a787-b0f1251a1808.png)

- Run "printenv" command in the secretenvpod (2nd pod):

![image](https://user-images.githubusercontent.com/10358317/153637549-9a1ceb13-d2dd-49ce-931b-ccfefbb75595.png)

- Run "printenv" command in the secretenvallpod (3rd pod):

![image](https://user-images.githubusercontent.com/10358317/153637762-d6dff332-3d80-4558-80b5-2ae86f4d0c92.png)

- Create new secret with imperative way:

``` 
kubectl create secret generic mysecret2 --from-literal=db_server=db.example.com --from-literal=db_username=admin --from-literal=db_password=P@ssw0rd!
```   

![image](https://user-images.githubusercontent.com/10358317/153638556-50874231-7be3-4801-90d0-ae84f66c28e9.png)

- Create new secret using files (avoid to see in the history command list).
- Create file on the same directory before to run command (e.g. "touch server.txt"): 
  - server.txt    => put into "db.example.com" with "cat" command
  - password.txt  => put into "password" with "cat" command
  - username.txt  => put into "admin" with "cat" command
- Files: 
  - https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/secret/server.txt
  - https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/secret/password.txt
  - https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/secret/username.txt

```     
kubectl create secret generic mysecret3 --from-file=db_server=server.txt --from-file=db_username=username.txt --from-file=db_password=password.txt
``` 

![image](https://user-images.githubusercontent.com/10358317/153639595-4f8e5c95-151c-4990-93ac-6e8b98776fbd.png)

- Create json file (config.json) and put following content.
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/secret/config.json

```
{
    "apiKey": "7ac4108d4b2212f2c30c71dfa279e1f77dd12356",
}
```

``` 
kubectl create secret generic mysecret4 --from-file=config.json
``` 

![image](https://user-images.githubusercontent.com/10358317/153640684-cb16dac0-cddd-40b0-a90f-9f42b28e3373.png)

- Delete mysecret4:

![image](https://user-images.githubusercontent.com/10358317/153640797-617ddd36-cbb6-4a73-8955-f4482e521dde.png)
$md$, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('f97ad7c6-5f3b-5436-a684-62af7d559bf1', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '1c403d8b-6f9e-5fe3-9443-b75a9f3759b4', 'Lab: ConfigMap', 'lab', 1, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('bb31fffe-f318-5c57-9ae9-962aacef59ab', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'f97ad7c6-5f3b-5436-a684-62af7d559bf1', 'module', 'Lab: ConfigMap', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/configmap.yaml <<'MFEOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: myconfigmap
data:
  db_server: "db.example.com"
  database: "mydatabase"
  site.settings: |
    color=blue
    padding:25px
---
apiVersion: v1
kind: Pod
metadata:
  name: configmappod
spec:
  containers:
  - name: configmapcontainer
    image: nginx
    env:
      - name: DB_SERVER
        valueFrom:
          configMapKeyRef:
            name: myconfigmap
            key: db_server
      - name: DATABASE
        valueFrom:
          configMapKeyRef:
            name: myconfigmap
            key: database
    volumeMounts:
      - name: config-vol
        mountPath: "/config"
        readOnly: true
  volumes:
    - name: config-vol
      configMap:
        name: myconfigmap
MFEOF
cat > /home/labuser/work/theme.txt <<'MFEOF'
theme=dark
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('0eb1ad30-8728-5aab-9592-f27032374744', 'bb31fffe-f318-5c57-9ae9-962aacef59ab', 1, 'Create the myconfigmap ConfigMap and configmappod Pod', $md$Apply `configmap.yaml` (already in your workdir) to create a ConfigMap named
**myconfigmap** and a Pod named **configmappod** that consumes it.
$md$, $script$#!/bin/bash
kubectl get configmap myconfigmap >/dev/null 2>&1 || exit 1
kubectl get pod configmappod --no-headers 2>/dev/null | grep -q Running
$script$, 'Use `kubectl apply -f configmap.yaml`.', '`configmap.yaml` bundles a ConfigMap and a Pod in one manifest separated by `---` —
`kubectl apply -f` creates both with a single command. The Pod references the
ConfigMap by name, but Kubernetes does not validate that reference until the kubelet
actually starts the container.
', 15, false, true),
('977c5da0-dd8f-57c9-92c8-eafd1aacbca0', 'bb31fffe-f318-5c57-9ae9-962aacef59ab', 2, 'Confirm the myconfigmap data keys and values', $md$Confirm that **myconfigmap** holds the data keys declared in `configmap.yaml`:
`db_server` = `db.example.com`, `database` = `mydatabase`, and a multi-line
`site.settings` key containing `color=blue` and `padding:25px`.
$md$, $script$#!/bin/bash
DBSERVER=$(kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}' 2>/dev/null)
test "$DBSERVER" = "db.example.com" || exit 1
DATABASE=$(kubectl get configmap myconfigmap -o jsonpath='{.data.database}' 2>/dev/null)
test "$DATABASE" = "mydatabase" || exit 1
SETTINGS=$(kubectl get configmap myconfigmap -o jsonpath="{.data['site\.settings']}" 2>/dev/null)
echo "$SETTINGS" | grep -q "color=blue" || exit 1
echo "$SETTINGS" | grep -q "padding:25px"
$script$, 'Use `kubectl get configmap myconfigmap -o jsonpath=''{.data.db_server}''` and the
equivalent for `database` and `site.settings` — bracket notation
(`{.data[''site\.settings'']}`) is required for a key that itself contains a dot.
', 'A ConfigMap''s `data` field is a flat map of string keys to string values. Keys with
dots (like `site.settings`, used here to mimic a filename) still parse fine, but
jsonpath needs bracket-escaped notation to disambiguate the dot in the key from the
path separator.
', 15, false, false),
('feb3b719-1415-51a3-981c-6831b2c82057', 'bb31fffe-f318-5c57-9ae9-962aacef59ab', 3, 'Confirm configmappod''s env vars reference myconfigmap', $md$Confirm that `configmapcontainer` in **configmappod** defines environment variables
`DB_SERVER` and `DATABASE`, each sourced via `configMapKeyRef` from **myconfigmap**'s
`db_server` and `database` keys respectively.
$md$, $script$#!/bin/bash
kubectl get pod configmappod -o jsonpath='{.spec.containers[0].env[?(@.name=="DB_SERVER")].valueFrom.configMapKeyRef.name}' | grep -qx myconfigmap || exit 1
kubectl get pod configmappod -o jsonpath='{.spec.containers[0].env[?(@.name=="DB_SERVER")].valueFrom.configMapKeyRef.key}' | grep -qx db_server || exit 1
kubectl get pod configmappod -o jsonpath='{.spec.containers[0].env[?(@.name=="DATABASE")].valueFrom.configMapKeyRef.name}' | grep -qx myconfigmap || exit 1
kubectl get pod configmappod -o jsonpath='{.spec.containers[0].env[?(@.name=="DATABASE")].valueFrom.configMapKeyRef.key}' | grep -qx database
$script$, 'Inspect `.spec.containers[0].env` with a jsonpath filter on `@.name` and look at each
entry''s `valueFrom.configMapKeyRef`.
', '`configMapKeyRef` injects a single ConfigMap key as one environment variable at
container start — unlike mounting the whole ConfigMap as a volume, this pattern lets
each env var pull from a different key (or even a different ConfigMap) independently.
', 15, false, false),
('8dcfcefc-2a6f-5cb4-85f1-959f855c3273', 'bb31fffe-f318-5c57-9ae9-962aacef59ab', 4, 'Confirm configmappod mounts myconfigmap as a read-only volume', $md$Confirm that **configmappod** defines a volume named `config-vol` backed by
**myconfigmap**, and that `configmapcontainer` mounts it read-only at `/config`.
$md$, $script$#!/bin/bash
kubectl get pod configmappod -o jsonpath='{.spec.volumes[?(@.name=="config-vol")].configMap.name}' | grep -qx myconfigmap || exit 1
kubectl get pod configmappod -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name=="config-vol")].mountPath}' | grep -qx /config || exit 1
kubectl get pod configmappod -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name=="config-vol")].readOnly}' | grep -qx true
$script$, 'Check `.spec.volumes` for a `configMap` volume source named `config-vol`, then check
`.spec.containers[0].volumeMounts` for a matching entry with `mountPath: /config` and
`readOnly: true`.
', 'Mounting a ConfigMap as a volume exposes every key as a file inside the mount path
(here, `/config/db_server`, `/config/database`, `/config/site.settings`) rather than a
single env var — useful for config files an app reads from disk. `readOnly: true`
prevents the container from ever writing back into the projected ConfigMap volume.
', 15, false, false),
('33e01790-be8e-5278-a7fe-acae16ceb140', 'bb31fffe-f318-5c57-9ae9-962aacef59ab', 5, 'Create a ConfigMap from the theme.txt file', $md$Using `theme.txt` (already in your workdir, containing `theme=dark`), create a new
ConfigMap named **themeconfig** with `kubectl create configmap --from-file`, so the
ConfigMap ends up with a data key named `theme.txt` holding the file's contents.
$md$, $script$#!/bin/bash
kubectl get configmap themeconfig >/dev/null 2>&1 || exit 1
kubectl get configmap themeconfig -o jsonpath="{.data['theme\.txt']}" | grep -q "theme=dark"
$script$, 'Use `kubectl create configmap themeconfig --from-file=theme.txt`.', '`--from-file=theme.txt` (with no `key=` prefix) uses the base filename as the data key
and the file''s full contents as the value — the resulting ConfigMap is functionally
equivalent to hand-writing a `data` block in YAML, but generated straight from a file
already on disk.
', 20, false, true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('fd4caf13-2929-514d-8218-f5e95e207bfc', 'bb31fffe-f318-5c57-9ae9-962aacef59ab', 1, $json$[{"id":"0eb1ad30-8728-5aab-9592-f27032374744","lab_id":"bb31fffe-f318-5c57-9ae9-962aacef59ab","position":1,"title":"Create the myconfigmap ConfigMap and configmappod Pod","description":"Apply `configmap.yaml` (already in your workdir) to create a ConfigMap named\n**myconfigmap** and a Pod named **configmappod** that consumes it.\n","verification_script":"#!/bin/bash\nkubectl get configmap myconfigmap \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get pod configmappod --no-headers 2\u003e/dev/null | grep -q Running\n","hint_context":"Use `kubectl apply -f configmap.yaml`.","explanation_context":"`configmap.yaml` bundles a ConfigMap and a Pod in one manifest separated by `---` —\n`kubectl apply -f` creates both with a single command. The Pod references the\nConfigMap by name, but Kubernetes does not validate that reference until the kubelet\nactually starts the container.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"977c5da0-dd8f-57c9-92c8-eafd1aacbca0","lab_id":"bb31fffe-f318-5c57-9ae9-962aacef59ab","position":2,"title":"Confirm the myconfigmap data keys and values","description":"Confirm that **myconfigmap** holds the data keys declared in `configmap.yaml`:\n`db_server` = `db.example.com`, `database` = `mydatabase`, and a multi-line\n`site.settings` key containing `color=blue` and `padding:25px`.\n","verification_script":"#!/bin/bash\nDBSERVER=$(kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}' 2\u003e/dev/null)\ntest \"$DBSERVER\" = \"db.example.com\" || exit 1\nDATABASE=$(kubectl get configmap myconfigmap -o jsonpath='{.data.database}' 2\u003e/dev/null)\ntest \"$DATABASE\" = \"mydatabase\" || exit 1\nSETTINGS=$(kubectl get configmap myconfigmap -o jsonpath=\"{.data['site\\.settings']}\" 2\u003e/dev/null)\necho \"$SETTINGS\" | grep -q \"color=blue\" || exit 1\necho \"$SETTINGS\" | grep -q \"padding:25px\"\n","hint_context":"Use `kubectl get configmap myconfigmap -o jsonpath='{.data.db_server}'` and the\nequivalent for `database` and `site.settings` — bracket notation\n(`{.data['site\\.settings']}`) is required for a key that itself contains a dot.\n","explanation_context":"A ConfigMap's `data` field is a flat map of string keys to string values. Keys with\ndots (like `site.settings`, used here to mimic a filename) still parse fine, but\njsonpath needs bracket-escaped notation to disambiguate the dot in the key from the\npath separator.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"feb3b719-1415-51a3-981c-6831b2c82057","lab_id":"bb31fffe-f318-5c57-9ae9-962aacef59ab","position":3,"title":"Confirm configmappod's env vars reference myconfigmap","description":"Confirm that `configmapcontainer` in **configmappod** defines environment variables\n`DB_SERVER` and `DATABASE`, each sourced via `configMapKeyRef` from **myconfigmap**'s\n`db_server` and `database` keys respectively.\n","verification_script":"#!/bin/bash\nkubectl get pod configmappod -o jsonpath='{.spec.containers[0].env[?(@.name==\"DB_SERVER\")].valueFrom.configMapKeyRef.name}' | grep -qx myconfigmap || exit 1\nkubectl get pod configmappod -o jsonpath='{.spec.containers[0].env[?(@.name==\"DB_SERVER\")].valueFrom.configMapKeyRef.key}' | grep -qx db_server || exit 1\nkubectl get pod configmappod -o jsonpath='{.spec.containers[0].env[?(@.name==\"DATABASE\")].valueFrom.configMapKeyRef.name}' | grep -qx myconfigmap || exit 1\nkubectl get pod configmappod -o jsonpath='{.spec.containers[0].env[?(@.name==\"DATABASE\")].valueFrom.configMapKeyRef.key}' | grep -qx database\n","hint_context":"Inspect `.spec.containers[0].env` with a jsonpath filter on `@.name` and look at each\nentry's `valueFrom.configMapKeyRef`.\n","explanation_context":"`configMapKeyRef` injects a single ConfigMap key as one environment variable at\ncontainer start — unlike mounting the whole ConfigMap as a volume, this pattern lets\neach env var pull from a different key (or even a different ConfigMap) independently.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"8dcfcefc-2a6f-5cb4-85f1-959f855c3273","lab_id":"bb31fffe-f318-5c57-9ae9-962aacef59ab","position":4,"title":"Confirm configmappod mounts myconfigmap as a read-only volume","description":"Confirm that **configmappod** defines a volume named `config-vol` backed by\n**myconfigmap**, and that `configmapcontainer` mounts it read-only at `/config`.\n","verification_script":"#!/bin/bash\nkubectl get pod configmappod -o jsonpath='{.spec.volumes[?(@.name==\"config-vol\")].configMap.name}' | grep -qx myconfigmap || exit 1\nkubectl get pod configmappod -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name==\"config-vol\")].mountPath}' | grep -qx /config || exit 1\nkubectl get pod configmappod -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name==\"config-vol\")].readOnly}' | grep -qx true\n","hint_context":"Check `.spec.volumes` for a `configMap` volume source named `config-vol`, then check\n`.spec.containers[0].volumeMounts` for a matching entry with `mountPath: /config` and\n`readOnly: true`.\n","explanation_context":"Mounting a ConfigMap as a volume exposes every key as a file inside the mount path\n(here, `/config/db_server`, `/config/database`, `/config/site.settings`) rather than a\nsingle env var — useful for config files an app reads from disk. `readOnly: true`\nprevents the container from ever writing back into the projected ConfigMap volume.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"33e01790-be8e-5278-a7fe-acae16ceb140","lab_id":"bb31fffe-f318-5c57-9ae9-962aacef59ab","position":5,"title":"Create a ConfigMap from the theme.txt file","description":"Using `theme.txt` (already in your workdir, containing `theme=dark`), create a new\nConfigMap named **themeconfig** with `kubectl create configmap --from-file`, so the\nConfigMap ends up with a data key named `theme.txt` holding the file's contents.\n","verification_script":"#!/bin/bash\nkubectl get configmap themeconfig \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get configmap themeconfig -o jsonpath=\"{.data['theme\\.txt']}\" | grep -q \"theme=dark\"\n","hint_context":"Use `kubectl create configmap themeconfig --from-file=theme.txt`.","explanation_context":"`--from-file=theme.txt` (with no `key=` prefix) uses the base filename as the data key\nand the file's full contents as the value — the resulting ConfigMap is functionally\nequivalent to hand-writing a `data` block in YAML, but generated straight from a file\nalready on disk.\n","points":20,"is_optional":false,"is_stateful":true}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'fd4caf13-2929-514d-8218-f5e95e207bfc', updated_at = now()
WHERE id = 'bb31fffe-f318-5c57-9ae9-962aacef59ab' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('f5cb494b-5f41-5bc2-8998-b2f459c08c19', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '1c403d8b-6f9e-5fe3-9443-b75a9f3759b4', 'Lab: Secret', 'lab', 2, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('c33cca04-5574-5f1d-91e9-6a696002a5a1', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'f5cb494b-5f41-5bc2-8998-b2f459c08c19', 'module', 'Lab: Secret', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/config.json <<'MFEOF'
{
    "apiKey": "6bba108d4b2212f2c30c71dfa279e1f77cc5c3b2",
}
MFEOF
cat > /home/labuser/work/password.txt <<'MFEOF'
P@ssw0rd!
MFEOF
cat > /home/labuser/work/secret-pods.yaml <<'MFEOF'
apiVersion: v1
kind: Pod
metadata:
  name: secretvolumepod
spec:
  containers:
  - name: secretcontainer
    image: nginx
    volumeMounts:
    - name: secret-vol
      mountPath: /secret
  volumes:
  - name: secret-vol
    secret:
      secretName: mysecret
---
apiVersion: v1
kind: Pod
metadata:
  name: secretenvpod
spec:
  containers:
  - name: secretcontainer
    image: nginx
    env:
      - name: username
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: db_username
      - name: password
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: db_password
      - name: server
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: db_server
---
apiVersion: v1
kind: Pod
metadata:
  name: secretenvallpod
spec:
  containers:
  - name: secretcontainer
    image: nginx
    envFrom:
    - secretRef:
        name: mysecret
MFEOF
cat > /home/labuser/work/secret.yaml <<'MFEOF'
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  db_server: db.example.com
  db_username: admin
  db_password: P@ssw0rd!
MFEOF
cat > /home/labuser/work/server.txt <<'MFEOF'
db.example.com
MFEOF
cat > /home/labuser/work/username.txt <<'MFEOF'
admin
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('ae1d9792-c7c2-5918-87b0-63d5a6d4cc90', 'c33cca04-5574-5f1d-91e9-6a696002a5a1', 1, 'Create the mysecret Secret declaratively', $md$Apply `secret.yaml` (already in your workdir) to create a Secret named **mysecret** of
type **Opaque** with keys `db_server`, `db_username`, and `db_password` matching the
values declared under `stringData`.
$md$, $script$#!/bin/bash
kubectl get secret mysecret >/dev/null 2>&1 || exit 1
kubectl get secret mysecret -o jsonpath='{.type}' | grep -qx Opaque || exit 1
kubectl get secret mysecret -o jsonpath='{.data.db_server}' | base64 -d | grep -qx db.example.com || exit 1
kubectl get secret mysecret -o jsonpath='{.data.db_username}' | base64 -d | grep -qx admin || exit 1
kubectl get secret mysecret -o jsonpath='{.data.db_password}' | base64 -d | grep -qx 'P@ssw0rd!'
$script$, 'Use `kubectl apply -f secret.yaml`.', '`stringData` is a write-only convenience field — the API server base64-encodes each
entry into `.data` on creation and never stores `stringData` itself. Every subsequent
read (`kubectl get secret -o yaml`, jsonpath, etc.) only ever sees the encoded `.data`
map, which is why verification must decode before comparing.
', 15, false, true),
('586aab0b-02b3-5dce-92c6-aaf2840ea3d5', 'c33cca04-5574-5f1d-91e9-6a696002a5a1', 2, 'Create the filecreds Secret imperatively from literal files', $md$Create a Secret named **filecreds** imperatively from `username.txt` and `password.txt`
using `kubectl create secret generic`, mapping them to the keys `username` and
`password` respectively (`--from-file=username=username.txt --from-file=password=password.txt`).
$md$, $script$#!/bin/bash
kubectl get secret filecreds >/dev/null 2>&1 || exit 1
kubectl get secret filecreds -o jsonpath='{.data.username}' | base64 -d | grep -qx admin || exit 1
kubectl get secret filecreds -o jsonpath='{.data.password}' | base64 -d | grep -qx 'P@ssw0rd!'
$script$, 'Use `kubectl create secret generic filecreds --from-file=username=username.txt
--from-file=password=password.txt`.
', '`--from-file=key=path` reads the file''s raw bytes and stores them under the given key —
unlike `--from-file=path` alone, which would use the file''s basename (`username.txt`) as
the key instead. This is the imperative equivalent of hand-writing a Secret manifest.
', 15, false, true),
('2750893c-19ed-5123-a581-7e09c5cd1f56', 'c33cca04-5574-5f1d-91e9-6a696002a5a1', 3, 'Create the three Secret-consuming Pods', $md$Apply `secret-pods.yaml` to create three Pods that each consume **mysecret** a
different way: `secretvolumepod` (volume mount), `secretenvpod` (per-key env vars via
`secretKeyRef`), and `secretenvallpod` (all keys via `envFrom.secretRef`).
$md$, $script$#!/bin/bash
for p in secretvolumepod secretenvpod secretenvallpod; do
  kubectl get pod "$p" --no-headers 2>/dev/null | grep -q Running || exit 1
done
$script$, 'Use `kubectl apply -f secret-pods.yaml`. mysecret must already exist.', 'All three Pods declare `mysecret` as a dependency, either via `volumes[].secret.secretName`
or `secretKeyRef`/`secretRef`. If the Secret doesn''t exist yet, kubelet blocks the volume
mount and env injection until it appears — so `mysecret` must be created before this step.
', 15, false, true),
('cca397d8-6f98-5bc6-a375-bcc5dbf07e73', 'c33cca04-5574-5f1d-91e9-6a696002a5a1', 4, 'Confirm secretvolumepod mounts mysecret at /secret', $md$Confirm that `secretvolumepod`'s `secret-vol` volume is backed by the **mysecret**
Secret and mounted into `secretcontainer` at path `/secret`.
$md$, $script$#!/bin/bash
kubectl get pod secretvolumepod -o jsonpath='{.spec.volumes[?(@.name=="secret-vol")].secret.secretName}' | grep -qx mysecret || exit 1
kubectl get pod secretvolumepod -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name=="secret-vol")].mountPath}' | grep -qx /secret
$script$, 'Inspect `.spec.volumes` for the `secret.secretName` field and
`.spec.containers[0].volumeMounts` for a matching `name: secret-vol` entry.
', 'A `secret`-type volume tells kubelet to project every key in the referenced Secret as a
file inside the mount path — `db_server`, `db_username`, and `db_password` each become
a file named after the key, containing the decoded value, under `/secret`.
', 15, false, false),
('29d50e1f-5265-56ea-9f9c-17e6a52cb782', 'c33cca04-5574-5f1d-91e9-6a696002a5a1', 5, 'Confirm secretenvpod and secretenvallpod reference mysecret correctly', $md$Confirm that `secretenvpod`'s `username`, `password`, and `server` environment variables
resolve via `secretKeyRef` to `mysecret`'s `db_username`, `db_password`, and `db_server`
keys, and that `secretenvallpod` imports every key from `mysecret` via `envFrom.secretRef`.
$md$, $script$#!/bin/bash
kubectl get pod secretenvpod -o jsonpath='{.spec.containers[0].env[?(@.name=="username")].valueFrom.secretKeyRef.key}' | grep -qx db_username || exit 1
kubectl get pod secretenvpod -o jsonpath='{.spec.containers[0].env[?(@.name=="password")].valueFrom.secretKeyRef.key}' | grep -qx db_password || exit 1
kubectl get pod secretenvpod -o jsonpath='{.spec.containers[0].env[?(@.name=="server")].valueFrom.secretKeyRef.key}' | grep -qx db_server || exit 1
kubectl get pod secretenvallpod -o jsonpath='{.spec.containers[0].envFrom[0].secretRef.name}' | grep -qx mysecret
$script$, 'Inspect `.spec.containers[0].env[].valueFrom.secretKeyRef` on `secretenvpod` and
`.spec.containers[0].envFrom[].secretRef` on `secretenvallpod`.
', '`secretKeyRef` injects one Secret key as one env var, letting you rename it freely (here
`db_username` becomes `$username`); `envFrom.secretRef` instead injects every key in the
Secret as an env var using the key name verbatim, trading control for brevity.
', 20, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('fe60a567-cf3d-50b9-b98a-b4c9033ad0a8', 'c33cca04-5574-5f1d-91e9-6a696002a5a1', 1, $json$[{"id":"ae1d9792-c7c2-5918-87b0-63d5a6d4cc90","lab_id":"c33cca04-5574-5f1d-91e9-6a696002a5a1","position":1,"title":"Create the mysecret Secret declaratively","description":"Apply `secret.yaml` (already in your workdir) to create a Secret named **mysecret** of\ntype **Opaque** with keys `db_server`, `db_username`, and `db_password` matching the\nvalues declared under `stringData`.\n","verification_script":"#!/bin/bash\nkubectl get secret mysecret \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get secret mysecret -o jsonpath='{.type}' | grep -qx Opaque || exit 1\nkubectl get secret mysecret -o jsonpath='{.data.db_server}' | base64 -d | grep -qx db.example.com || exit 1\nkubectl get secret mysecret -o jsonpath='{.data.db_username}' | base64 -d | grep -qx admin || exit 1\nkubectl get secret mysecret -o jsonpath='{.data.db_password}' | base64 -d | grep -qx 'P@ssw0rd!'\n","hint_context":"Use `kubectl apply -f secret.yaml`.","explanation_context":"`stringData` is a write-only convenience field — the API server base64-encodes each\nentry into `.data` on creation and never stores `stringData` itself. Every subsequent\nread (`kubectl get secret -o yaml`, jsonpath, etc.) only ever sees the encoded `.data`\nmap, which is why verification must decode before comparing.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"586aab0b-02b3-5dce-92c6-aaf2840ea3d5","lab_id":"c33cca04-5574-5f1d-91e9-6a696002a5a1","position":2,"title":"Create the filecreds Secret imperatively from literal files","description":"Create a Secret named **filecreds** imperatively from `username.txt` and `password.txt`\nusing `kubectl create secret generic`, mapping them to the keys `username` and\n`password` respectively (`--from-file=username=username.txt --from-file=password=password.txt`).\n","verification_script":"#!/bin/bash\nkubectl get secret filecreds \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get secret filecreds -o jsonpath='{.data.username}' | base64 -d | grep -qx admin || exit 1\nkubectl get secret filecreds -o jsonpath='{.data.password}' | base64 -d | grep -qx 'P@ssw0rd!'\n","hint_context":"Use `kubectl create secret generic filecreds --from-file=username=username.txt\n--from-file=password=password.txt`.\n","explanation_context":"`--from-file=key=path` reads the file's raw bytes and stores them under the given key —\nunlike `--from-file=path` alone, which would use the file's basename (`username.txt`) as\nthe key instead. This is the imperative equivalent of hand-writing a Secret manifest.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"2750893c-19ed-5123-a581-7e09c5cd1f56","lab_id":"c33cca04-5574-5f1d-91e9-6a696002a5a1","position":3,"title":"Create the three Secret-consuming Pods","description":"Apply `secret-pods.yaml` to create three Pods that each consume **mysecret** a\ndifferent way: `secretvolumepod` (volume mount), `secretenvpod` (per-key env vars via\n`secretKeyRef`), and `secretenvallpod` (all keys via `envFrom.secretRef`).\n","verification_script":"#!/bin/bash\nfor p in secretvolumepod secretenvpod secretenvallpod; do\n  kubectl get pod \"$p\" --no-headers 2\u003e/dev/null | grep -q Running || exit 1\ndone\n","hint_context":"Use `kubectl apply -f secret-pods.yaml`. mysecret must already exist.","explanation_context":"All three Pods declare `mysecret` as a dependency, either via `volumes[].secret.secretName`\nor `secretKeyRef`/`secretRef`. If the Secret doesn't exist yet, kubelet blocks the volume\nmount and env injection until it appears — so `mysecret` must be created before this step.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"cca397d8-6f98-5bc6-a375-bcc5dbf07e73","lab_id":"c33cca04-5574-5f1d-91e9-6a696002a5a1","position":4,"title":"Confirm secretvolumepod mounts mysecret at /secret","description":"Confirm that `secretvolumepod`'s `secret-vol` volume is backed by the **mysecret**\nSecret and mounted into `secretcontainer` at path `/secret`.\n","verification_script":"#!/bin/bash\nkubectl get pod secretvolumepod -o jsonpath='{.spec.volumes[?(@.name==\"secret-vol\")].secret.secretName}' | grep -qx mysecret || exit 1\nkubectl get pod secretvolumepod -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name==\"secret-vol\")].mountPath}' | grep -qx /secret\n","hint_context":"Inspect `.spec.volumes` for the `secret.secretName` field and\n`.spec.containers[0].volumeMounts` for a matching `name: secret-vol` entry.\n","explanation_context":"A `secret`-type volume tells kubelet to project every key in the referenced Secret as a\nfile inside the mount path — `db_server`, `db_username`, and `db_password` each become\na file named after the key, containing the decoded value, under `/secret`.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"29d50e1f-5265-56ea-9f9c-17e6a52cb782","lab_id":"c33cca04-5574-5f1d-91e9-6a696002a5a1","position":5,"title":"Confirm secretenvpod and secretenvallpod reference mysecret correctly","description":"Confirm that `secretenvpod`'s `username`, `password`, and `server` environment variables\nresolve via `secretKeyRef` to `mysecret`'s `db_username`, `db_password`, and `db_server`\nkeys, and that `secretenvallpod` imports every key from `mysecret` via `envFrom.secretRef`.\n","verification_script":"#!/bin/bash\nkubectl get pod secretenvpod -o jsonpath='{.spec.containers[0].env[?(@.name==\"username\")].valueFrom.secretKeyRef.key}' | grep -qx db_username || exit 1\nkubectl get pod secretenvpod -o jsonpath='{.spec.containers[0].env[?(@.name==\"password\")].valueFrom.secretKeyRef.key}' | grep -qx db_password || exit 1\nkubectl get pod secretenvpod -o jsonpath='{.spec.containers[0].env[?(@.name==\"server\")].valueFrom.secretKeyRef.key}' | grep -qx db_server || exit 1\nkubectl get pod secretenvallpod -o jsonpath='{.spec.containers[0].envFrom[0].secretRef.name}' | grep -qx mysecret\n","hint_context":"Inspect `.spec.containers[0].env[].valueFrom.secretKeyRef` on `secretenvpod` and\n`.spec.containers[0].envFrom[].secretRef` on `secretenvallpod`.\n","explanation_context":"`secretKeyRef` injects one Secret key as one env var, letting you rename it freely (here\n`db_username` becomes `$username`); `envFrom.secretRef` instead injects every key in the\nSecret as an env var using the key name verbatim, trading control for brevity.\n","points":20,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = 'fe60a567-cf3d-50b9-b98a-b4c9033ad0a8', updated_at = now()
WHERE id = 'c33cca04-5574-5f1d-91e9-6a696002a5a1' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b98911f2-3918-5112-a7a1-d4b569468700', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which two mechanisms can a Pod use to consume data from a ConfigMap, based on...', 'beginner', 2, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9e851561-b24f-51fd-8b67-07327b340f06', 'b98911f2-3918-5112-a7a1-d4b569468700', 1, $json${"prompt":"Which two mechanisms can a Pod use to consume data from a ConfigMap, based on the myconfigmap example in the lesson?","multiple":false,"options":[{"id":"a","text":"As environment variables via configMapKeyRef (one key at a time) and as mounted files through a configMap volume","is_correct":true},{"id":"b","text":"Only as environment variables; ConfigMaps cannot be mounted as volumes","is_correct":false},{"id":"c","text":"Only as mounted volumes; ConfigMaps cannot be exposed as environment variables","is_correct":false},{"id":"d","text":"Only through the Kubernetes Dashboard UI, not through Pod spec fields","is_correct":false}],"explanation":"The configmappod example wires myconfigmap two ways: db_server and database are\ninjected as environment variables through configMapKeyRef, while the same ConfigMap\nis also mounted at /config through a configMap volume, giving the container both an\nenv-var view and a file view of the same data.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('bcd94f8c-fe61-591e-a445-b02c500762bb', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the mysecret example, which statement correctly describes the Opaque type ...', 'intermediate', 3, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('db69d9bb-e1b7-52fa-9419-d5e0cfd67ae1', 'bcd94f8c-fe61-591e-a445-b02c500762bb', 1, $json${"prompt":"In the mysecret example, which statement correctly describes the Opaque type and the stringData field together?","multiple":false,"options":[{"id":"a","text":"Opaque is the default, generic Secret type, and stringData lets you write plain-text values that Kubernetes automatically base64-encodes when it stores the Secret","is_correct":true},{"id":"b","text":"stringData values must be pre-encoded in base64 by the user before being added to the YAML","is_correct":false},{"id":"c","text":"The Opaque type means the Secret's values are encrypted client-side before being sent to the API server","is_correct":false},{"id":"d","text":"Secrets can only be consumed as environment variables, never mounted as a volume","is_correct":false}],"explanation":"mysecret is declared with type Opaque, Kubernetes' default generic Secret type, and\nits db_server, db_username, and db_password values are written under stringData as\nplain text for convenience, with Kubernetes storing them base64-encoded internally.\nThe lesson also shows Secrets consumed both as a mounted volume (secretvolumepod) and\nas environment variables via secretKeyRef and envFrom (secretenvpod, secretenvallpod).\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e50c0c8b-84f4-5238-b9e6-cc75f834780b', '00000000-0000-0000-0000-000000000001', 'coding', 'You receive a list of `key=value` pairs, one per line, representing `--from-l...', 'intermediate', 5, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('bf5e41cc-9875-5160-8b2e-b2c626bcd1ae', 'e50c0c8b-84f4-5238-b9e6-cc75f834780b', 1, $json${"prompt":"You receive a list of `key=value` pairs, one per line, representing `--from-literal`\narguments passed to `kubectl create secret generic`. For each pair, print `KEY: VALUE`,\nbut if the key contains the substring `password` (case-insensitive), mask the value by\nreplacing every character with an asterisk instead of printing it in plain text.\n\n**Example:**\n```\n3\ndb_server=db.example.com\ndb_username=admin\ndb_password=P@ssw0rd!\n```\nOutput:\n```\ndb_server: db.example.com\ndb_username: admin\ndb_password: *********\n```\n","languages":["python","javascript"],"starter_code":{"javascript":"const lines = require('fs').readFileSync(0, 'utf8').trim().split('\\n');\nconst n = parseInt(lines[0]);\nfor (let i = 1; i \u003c= n; i++) {\n  const idx = lines[i].indexOf('=');\n  const key = lines[i].slice(0, idx);\n  const value = lines[i].slice(idx + 1);\n  if (key.toLowerCase().includes('password')) {\n    console.log(`${key}: ${'*'.repeat(value.length)}`);\n  } else {\n    console.log(`${key}: ${value}`);\n  }\n}\n","python":"import sys\nlines = sys.stdin.read().split('\\n')\nn = int(lines[0])\nfor i in range(1, n + 1):\n    key, value = lines[i].split('=', 1)\n    if 'password' in key.lower():\n        print(f\"{key}: {'*' * len(value)}\")\n    else:\n        print(f\"{key}: {value}\")\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"3\ndb_server=db.example.com\ndb_username=admin\ndb_password=P@ssw0rd!\n","expected":"db_server: db.example.com\ndb_username: admin\ndb_password: *********\n","hidden":false,"weight":1},{"id":"t2","stdin":"2\napi_key=abc123\nAPI_PASSWORD=hunter2\n","expected":"api_key: abc123\nAPI_PASSWORD: *******\n","hidden":true,"weight":1},{"id":"t3","stdin":"1\ntheme=dark\n","expected":"theme: dark\n","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('fe1bed1e-2b1d-539a-a462-4086d2e16717', '00000000-0000-0000-0000-000000000001', 'Quiz: Configuration & Secrets', 'k8s-config-secrets-quiz', 'Quiz covering Configuration & Secrets.', 'mixed', 'published', 'module', '3dc9739f-6e70-5ded-b51f-d43242453e28', 15, 60, 5, 10, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('3c009860-1a7e-5946-82c9-1cbf5dc0218a', 'fe1bed1e-2b1d-539a-a462-4086d2e16717', 'b98911f2-3918-5112-a7a1-d4b569468700', '9e851561-b24f-51fd-8b67-07327b340f06', 0, 2),
('237b8a02-a28c-5879-8cf7-ad0f9071b1d4', 'fe1bed1e-2b1d-539a-a462-4086d2e16717', 'bcd94f8c-fe61-591e-a445-b02c500762bb', 'db69d9bb-e1b7-52fa-9419-d5e0cfd67ae1', 1, 3),
('7e72ef39-7bbc-5eca-82ca-de157d9fc59b', 'fe1bed1e-2b1d-539a-a462-4086d2e16717', 'e50c0c8b-84f4-5238-b9e6-cc75f834780b', 'bf5e41cc-9875-5160-8b2e-b2c626bcd1ae', 2, 5)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('3dc9739f-6e70-5ded-b51f-d43242453e28', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '1c403d8b-6f9e-5fe3-9443-b75a9f3759b4', 'Quiz: Configuration & Secrets', 'assessment', 3, 15, 'fe1bed1e-2b1d-539a-a462-4086d2e16717')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Storage
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('45cb3c88-5b2a-5385-98b6-2763f2717d95', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Storage', 5)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes)
VALUES ('dbe8d427-ccc5-5398-b1f8-26ead5653c4f', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '45cb3c88-5b2a-5385-98b6-2763f2717d95', 'Storage', 'notes', 0, $md$## LAB: K8s Persistent Volumes and Persistent Volume Claims

This scenario shows how K8s PVC and PV work on minikube

### Steps

- On Minikube, we do not have to reach NFS Server. So we simulate NFS Server with Docker Container.

``` 
docker volume create nfsvol
docker network create --driver=bridge --subnet=10.255.255.0/24 --ip-range=10.255.255.0/24 --gateway=10.255.255.10 nfsnet
docker run -dit --privileged --restart unless-stopped -e SHARED_DIRECTORY=/data -v nfsvol:/data --network nfsnet -p 2049:2049 --name nfssrv ozgurozturknet/nfs:latest
``` 

![image](https://user-images.githubusercontent.com/10358317/152173180-47015aa9-a8b8-4a41-a49e-9154a4eb26e2.png)

- Now our simulated server enabled.
- Copy and save (below) as file on your PC (pv.yaml). 
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/persistentvolume/pv.yaml

```     
apiVersion: v1                               
kind: PersistentVolume
metadata:
   name: mysqlpv
   labels:
     app: mysql                                # labelled PV with "mysql"
spec:
  capacity:
    storage: 5Gi                               # 5Gibibyte = power of 2; 5GB= power of 10
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain      
  nfs:
    path: /                                    # binds the path on the NFS Server
    server: 10.255.255.10                      # IP of NFS Server
```

![image](https://user-images.githubusercontent.com/10358317/154735518-3bde3e54-518b-4fba-bdf5-bd57eabd2546.png)

- Create PV object on our cluster:

![image](https://user-images.githubusercontent.com/10358317/152173879-837bb03a-fd9f-44ba-becc-fa3ab7ae748f.png)

- Copy and save (below) as file on your PC (pvc.yaml). 
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/persistentvolume/pvc.yaml

```     
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysqlclaim
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem          
  resources:
    requests:
      storage: 5Gi
  storageClassName: ""
  selector:
    matchLabels:
      app: mysql                     # chose/select "mysql" PV that is defined above.
```

![image](https://user-images.githubusercontent.com/10358317/154735540-3026d9de-92bd-4e9d-a00a-3f0cf597db34.png)

- Create PVC object on our cluster. After creation, PVC's status shows to bind to PV ("Bound"):

![image](https://user-images.githubusercontent.com/10358317/152174156-9d20270f-3be7-46b1-ac07-2c32c56036c4.png)

- Copy and save (below) as file on your PC (deploy.yaml).
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/persistentvolume/deploy.yaml 

```     
apiVersion: v1                                     # Create Secret object for password
kind: Secret
metadata:
  name: mysqlsecret
type: Opaque
stringData:
  password: P@ssw0rd!
---
apiVersion: apps/v1
kind: Deployment                                  # Deployment
metadata:
  name: mysqldeployment
  labels:
    app: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql                                   # select deployment container (template > metadata > labels)
  strategy:
    type: Recreate
  template:
    metadata:
      labels:  
        app: mysql
    spec:
      containers:
        - name: mysql
          image: mysql
          ports:
            - containerPort: 3306
          volumeMounts:                             # VolumeMounts on path and volume name
            - mountPath: "/var/lib/mysql"
              name: mysqlvolume                     # which volume to select (volumes > name)
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:                            # get mysql password from secrets
                secretKeyRef:
                  name: mysqlsecret
                  key: password
      volumes:
        - name: mysqlvolume                         # name of Volume
          persistentVolumeClaim:
            claimName: mysqlclaim                   # chose/select "mysqlclaim" PVC that is defined above.
```

![image](https://user-images.githubusercontent.com/10358317/154735894-bb807908-5378-487c-bb67-8e68ab26cc00.png)

- Run deployment on our cluster:

![image](https://user-images.githubusercontent.com/10358317/152175581-ccaafe14-e41d-4a14-8e4f-cde96e9bf31b.png)

- Watching deployment status:
 
 ![image](https://user-images.githubusercontent.com/10358317/152175839-0b3c4cbd-210a-46ff-80ac-8dbd723c6a62.png)

- See the details of pod (mounts and volumes):

![image](https://user-images.githubusercontent.com/10358317/152176550-73e8c06c-0f5a-42ed-ab06-171e545ee078.png)

- Enter into the pod and see the path that the volume is mounted ("kubectl exec -it <PodName> -- bash"):

![image](https://user-images.githubusercontent.com/10358317/152181824-96dfbc72-ee0f-45c0-b896-b6fea7b9f7a5.png)

- If the new node is added into the cluster and this running pod is stopped running on the main minikube node, the pod will start on the another node.
- With this scenario, we can see the followings:
   - Deployment always run pod on the cluster.
   - The pod which is created on the new node still connects the persistent volume (there is not any loss for volume)
   - How assigning taint on the node (key:=value:NoExecute, if NoExecute is not tolerated by pod, pod is deleted on the node)

![image](https://user-images.githubusercontent.com/10358317/152178562-388f60db-977e-4247-8b0f-2ff9e0df602e.png)

- New pod is created on the new node (2nd node)

![image](https://user-images.githubusercontent.com/10358317/152178713-ca502e6c-140e-4471-aa37-dc4a8c5c6785.png)

- Second pod also is connected to the same volume again.

![image](https://user-images.githubusercontent.com/10358317/152179192-d6030535-8a54-451a-b97a-319ba2549870.png)
   
- Enter into the 2nd pod and see the path that the volume is mounted ("kubectl exec -it <PodName> -- bash"). When you see the files at the same path on the 2nd pod, volume files are same:
   
![image](https://user-images.githubusercontent.com/10358317/152182472-e67f7162-a4cf-4034-aa98-375860fbd38d.png)
  
- Delete minikube, docker container, volume, network:

![image](https://user-images.githubusercontent.com/10358317/152180006-911adcbc-0d5a-4d6d-9364-eb7fe1bca0d2.png)

### References
- https://github.com/aytitech/k8sfundamentals/tree/main/pvpvc
$md$, 20)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('2c9b8b98-04e3-5f3b-9ad0-d613679763a1', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '45cb3c88-5b2a-5385-98b6-2763f2717d95', 'Lab: Persistent Volume', 'lab', 1, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('200053ab-0b4e-5000-8c2b-101de471d95c', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '2c9b8b98-04e3-5f3b-9ad0-d613679763a1', 'module', 'Lab: Persistent Volume', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/deploy.yaml <<'MFEOF'
apiVersion: v1
kind: Secret
metadata:
  name: mysqlsecret
type: Opaque
stringData:
  password: P@ssw0rd!
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysqldeployment
  labels:
    app: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - name: mysql
          image: mysql
          ports:
            - containerPort: 3306
          volumeMounts:
            - mountPath: "/var/lib/mysql"
              name: mysqlvolume
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysqlsecret
                  key: password
      volumes:
        - name: mysqlvolume
          persistentVolumeClaim:
            claimName: mysqlclaim
MFEOF
cat > /home/labuser/work/pv.yaml <<'MFEOF'
apiVersion: v1
kind: PersistentVolume
metadata:
   name: mysqlpv
   labels:
     app: mysql
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  nfs:
    path: /
    server: 10.255.255.10
MFEOF
cat > /home/labuser/work/pvc.yaml <<'MFEOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysqlclaim
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem          
  resources:
    requests:
      storage: 5Gi
  storageClassName: ""
  selector:
    matchLabels:
      app: mysql
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('a2340712-c62d-5c23-b549-6f901d2f9eba', '200053ab-0b4e-5000-8c2b-101de471d95c', 1, 'Create the mysqlpv PersistentVolume', $md$Apply `pv.yaml` (already in your workdir) to create a PersistentVolume named
**mysqlpv** with **5Gi** capacity, access mode `ReadWriteOnce`, reclaim policy
`Recycle`, and an NFS backend (`server: 10.255.255.10`, `path: /`).
$md$, $script$#!/bin/bash
kubectl get pv mysqlpv >/dev/null 2>&1 || exit 1
kubectl get pv mysqlpv -o jsonpath='{.spec.capacity.storage}' | grep -qx 5Gi || exit 1
kubectl get pv mysqlpv -o jsonpath='{.spec.accessModes[0]}' | grep -qx ReadWriteOnce || exit 1
kubectl get pv mysqlpv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' | grep -qx Recycle || exit 1
kubectl get pv mysqlpv -o jsonpath='{.spec.nfs.server}' | grep -qx 10.255.255.10
$script$, 'Use `kubectl apply -f pv.yaml`.', 'A PersistentVolume is a cluster-scoped storage resource provisioned ahead of demand
(static provisioning) — its `capacity`, `accessModes`, and `persistentVolumeReclaimPolicy`
describe what it offers, and its `nfs` block (or another volume source) describes where
the bytes actually live. No Pod references a PV directly; a PersistentVolumeClaim does.
', 15, false, true),
('5fa4bd61-13c7-51cd-a0f6-39c79a84ccc2', '200053ab-0b4e-5000-8c2b-101de471d95c', 2, 'Create the mysqlclaim PersistentVolumeClaim', $md$Apply `pvc.yaml` to create a PersistentVolumeClaim named **mysqlclaim** requesting
**5Gi** of `ReadWriteOnce` storage, with `storageClassName: ""` (static provisioning,
no dynamic provisioner) and a `selector` matching label `app=mysql`.
$md$, $script$#!/bin/bash
kubectl get pvc mysqlclaim >/dev/null 2>&1 || exit 1
kubectl get pvc mysqlclaim -o jsonpath='{.spec.accessModes[0]}' | grep -qx ReadWriteOnce || exit 1
kubectl get pvc mysqlclaim -o jsonpath='{.spec.resources.requests.storage}' | grep -qx 5Gi || exit 1
kubectl get pvc mysqlclaim -o jsonpath='{.spec.selector.matchLabels.app}' | grep -qx mysql
$script$, 'Use `kubectl apply -f pvc.yaml`.', 'A PersistentVolumeClaim is a namespaced request for storage — a Pod mounts a PVC, never
a PV directly. Leaving `storageClassName` empty (rather than omitting it) opts the claim
out of dynamic provisioning entirely, so it can only bind to a pre-existing PV whose
capacity, access modes, and (if set) `selector` match.
', 15, false, true),
('020f76ef-be17-55a0-9250-da843c8622ec', '200053ab-0b4e-5000-8c2b-101de471d95c', 3, 'Confirm mysqlpv and mysqlclaim are compatible for binding', $md$Confirm that **mysqlpv** and **mysqlclaim** are wired to bind to each other: the PV's
`app` label matches the PVC's `selector.matchLabels.app`, and their capacity and access
mode agree.

This lab's control plane does not run the `persistentvolume-binder` controller, so
`status.phase` never transitions to `Bound` here — this check instead confirms the
spec-level fields that a running binder controller would use to make that decision.
$md$, $script$#!/bin/bash
PV_LABEL=$(kubectl get pv mysqlpv -o jsonpath='{.metadata.labels.app}' 2>/dev/null)
PVC_SEL=$(kubectl get pvc mysqlclaim -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
test -n "$PV_LABEL" && test "$PV_LABEL" = "$PVC_SEL" || exit 1
PV_CAP=$(kubectl get pv mysqlpv -o jsonpath='{.spec.capacity.storage}' 2>/dev/null)
PVC_REQ=$(kubectl get pvc mysqlclaim -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
test -n "$PV_CAP" && test "$PV_CAP" = "$PVC_REQ" || exit 1
PV_MODE=$(kubectl get pv mysqlpv -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null)
PVC_MODE=$(kubectl get pvc mysqlclaim -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null)
test -n "$PV_MODE" && test "$PV_MODE" = "$PVC_MODE"
$script$, 'Compare `kubectl get pv mysqlpv -o jsonpath=''{.metadata.labels}''` against
`kubectl get pvc mysqlclaim -o jsonpath=''{.spec.selector}''`, and compare
`.spec.capacity.storage` / `.spec.resources.requests.storage` on each.
', 'The PersistentVolumeController binds a PVC to the first PV whose `capacity` is
sufficient, whose `accessModes` are a superset of the claim''s, and whose labels satisfy
the claim''s `selector` (if any) — matching `storageClassName` too. Get any of those wrong
and a claim sits `Pending` forever even with a PV that looks superficially available.
', 15, false, false),
('b1624494-6267-5d22-8cc6-2c6e96d87e47', '200053ab-0b4e-5000-8c2b-101de471d95c', 4, 'Create the mysqldeployment Deployment', $md$Apply `deploy.yaml` to create the **mysqlsecret** Secret and the **mysqldeployment**
Deployment (`strategy.type: Recreate`, image `mysql`) in one shot.
$md$, $script$#!/bin/bash
kubectl get secret mysqlsecret >/dev/null 2>&1 || exit 1
kubectl get deployment mysqldeployment >/dev/null 2>&1 || exit 1
kubectl get deployment mysqldeployment -o jsonpath='{.spec.strategy.type}' | grep -qx Recreate || exit 1
IMAGE=$(kubectl get deployment mysqldeployment -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
echo "$IMAGE" | grep -q '^mysql' || exit 1
READY=$(kubectl get deployment mysqldeployment -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
test "${READY:-0}" -ge 1
$script$, 'Use `kubectl apply -f deploy.yaml`.', '`deploy.yaml` bundles a Secret and a Deployment separated by `---` — `kubectl apply -f`
creates both together. The `Recreate` strategy matters for anything backed by a
`ReadWriteOnce` volume: the old Pod is fully terminated (releasing the volume) before a
replacement is created, avoiding two Pods fighting over the same non-shareable mount.
', 20, false, true),
('5b6345d4-ae82-5723-8185-d237c200e5bf', '200053ab-0b4e-5000-8c2b-101de471d95c', 5, 'Confirm mysqldeployment correctly mounts mysqlclaim', $md$Confirm that **mysqldeployment**'s Pod template mounts a volume named `mysqlvolume`
backed by claim `mysqlclaim` at path `/var/lib/mysql`, and that its
`MYSQL_ROOT_PASSWORD` environment variable is sourced from the `mysqlsecret` Secret.
$md$, $script$#!/bin/bash
CLAIM=$(kubectl get deployment mysqldeployment -o jsonpath='{.spec.template.spec.volumes[?(@.name=="mysqlvolume")].persistentVolumeClaim.claimName}' 2>/dev/null)
test "$CLAIM" = "mysqlclaim" || exit 1
MOUNT=$(kubectl get deployment mysqldeployment -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.name=="mysqlvolume")].mountPath}' 2>/dev/null)
test "$MOUNT" = "/var/lib/mysql" || exit 1
SECRETREF=$(kubectl get deployment mysqldeployment -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="MYSQL_ROOT_PASSWORD")].valueFrom.secretKeyRef.name}' 2>/dev/null)
test "$SECRETREF" = "mysqlsecret"
$script$, 'Inspect `.spec.template.spec.volumes` for the `persistentVolumeClaim.claimName`, and each
container''s `.volumeMounts` and `.env` for the matching entries.
', 'A Pod claims storage by name: `volumes[].persistentVolumeClaim.claimName` points at a
PVC in the same namespace, and `containers[].volumeMounts[].name` links a container''s
mount path back to that volume entry. A typo in either name silently drops the mount
instead of failing loudly, which is why this wiring is worth checking explicitly.
', 15, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('582e46bf-67ec-589b-aed3-09966b1e8e3a', '200053ab-0b4e-5000-8c2b-101de471d95c', 1, $json$[{"id":"a2340712-c62d-5c23-b549-6f901d2f9eba","lab_id":"200053ab-0b4e-5000-8c2b-101de471d95c","position":1,"title":"Create the mysqlpv PersistentVolume","description":"Apply `pv.yaml` (already in your workdir) to create a PersistentVolume named\n**mysqlpv** with **5Gi** capacity, access mode `ReadWriteOnce`, reclaim policy\n`Recycle`, and an NFS backend (`server: 10.255.255.10`, `path: /`).\n","verification_script":"#!/bin/bash\nkubectl get pv mysqlpv \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get pv mysqlpv -o jsonpath='{.spec.capacity.storage}' | grep -qx 5Gi || exit 1\nkubectl get pv mysqlpv -o jsonpath='{.spec.accessModes[0]}' | grep -qx ReadWriteOnce || exit 1\nkubectl get pv mysqlpv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' | grep -qx Recycle || exit 1\nkubectl get pv mysqlpv -o jsonpath='{.spec.nfs.server}' | grep -qx 10.255.255.10\n","hint_context":"Use `kubectl apply -f pv.yaml`.","explanation_context":"A PersistentVolume is a cluster-scoped storage resource provisioned ahead of demand\n(static provisioning) — its `capacity`, `accessModes`, and `persistentVolumeReclaimPolicy`\ndescribe what it offers, and its `nfs` block (or another volume source) describes where\nthe bytes actually live. No Pod references a PV directly; a PersistentVolumeClaim does.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"5fa4bd61-13c7-51cd-a0f6-39c79a84ccc2","lab_id":"200053ab-0b4e-5000-8c2b-101de471d95c","position":2,"title":"Create the mysqlclaim PersistentVolumeClaim","description":"Apply `pvc.yaml` to create a PersistentVolumeClaim named **mysqlclaim** requesting\n**5Gi** of `ReadWriteOnce` storage, with `storageClassName: \"\"` (static provisioning,\nno dynamic provisioner) and a `selector` matching label `app=mysql`.\n","verification_script":"#!/bin/bash\nkubectl get pvc mysqlclaim \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get pvc mysqlclaim -o jsonpath='{.spec.accessModes[0]}' | grep -qx ReadWriteOnce || exit 1\nkubectl get pvc mysqlclaim -o jsonpath='{.spec.resources.requests.storage}' | grep -qx 5Gi || exit 1\nkubectl get pvc mysqlclaim -o jsonpath='{.spec.selector.matchLabels.app}' | grep -qx mysql\n","hint_context":"Use `kubectl apply -f pvc.yaml`.","explanation_context":"A PersistentVolumeClaim is a namespaced request for storage — a Pod mounts a PVC, never\na PV directly. Leaving `storageClassName` empty (rather than omitting it) opts the claim\nout of dynamic provisioning entirely, so it can only bind to a pre-existing PV whose\ncapacity, access modes, and (if set) `selector` match.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"020f76ef-be17-55a0-9250-da843c8622ec","lab_id":"200053ab-0b4e-5000-8c2b-101de471d95c","position":3,"title":"Confirm mysqlpv and mysqlclaim are compatible for binding","description":"Confirm that **mysqlpv** and **mysqlclaim** are wired to bind to each other: the PV's\n`app` label matches the PVC's `selector.matchLabels.app`, and their capacity and access\nmode agree.\n\nThis lab's control plane does not run the `persistentvolume-binder` controller, so\n`status.phase` never transitions to `Bound` here — this check instead confirms the\nspec-level fields that a running binder controller would use to make that decision.\n","verification_script":"#!/bin/bash\nPV_LABEL=$(kubectl get pv mysqlpv -o jsonpath='{.metadata.labels.app}' 2\u003e/dev/null)\nPVC_SEL=$(kubectl get pvc mysqlclaim -o jsonpath='{.spec.selector.matchLabels.app}' 2\u003e/dev/null)\ntest -n \"$PV_LABEL\" \u0026\u0026 test \"$PV_LABEL\" = \"$PVC_SEL\" || exit 1\nPV_CAP=$(kubectl get pv mysqlpv -o jsonpath='{.spec.capacity.storage}' 2\u003e/dev/null)\nPVC_REQ=$(kubectl get pvc mysqlclaim -o jsonpath='{.spec.resources.requests.storage}' 2\u003e/dev/null)\ntest -n \"$PV_CAP\" \u0026\u0026 test \"$PV_CAP\" = \"$PVC_REQ\" || exit 1\nPV_MODE=$(kubectl get pv mysqlpv -o jsonpath='{.spec.accessModes[0]}' 2\u003e/dev/null)\nPVC_MODE=$(kubectl get pvc mysqlclaim -o jsonpath='{.spec.accessModes[0]}' 2\u003e/dev/null)\ntest -n \"$PV_MODE\" \u0026\u0026 test \"$PV_MODE\" = \"$PVC_MODE\"\n","hint_context":"Compare `kubectl get pv mysqlpv -o jsonpath='{.metadata.labels}'` against\n`kubectl get pvc mysqlclaim -o jsonpath='{.spec.selector}'`, and compare\n`.spec.capacity.storage` / `.spec.resources.requests.storage` on each.\n","explanation_context":"The PersistentVolumeController binds a PVC to the first PV whose `capacity` is\nsufficient, whose `accessModes` are a superset of the claim's, and whose labels satisfy\nthe claim's `selector` (if any) — matching `storageClassName` too. Get any of those wrong\nand a claim sits `Pending` forever even with a PV that looks superficially available.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"b1624494-6267-5d22-8cc6-2c6e96d87e47","lab_id":"200053ab-0b4e-5000-8c2b-101de471d95c","position":4,"title":"Create the mysqldeployment Deployment","description":"Apply `deploy.yaml` to create the **mysqlsecret** Secret and the **mysqldeployment**\nDeployment (`strategy.type: Recreate`, image `mysql`) in one shot.\n","verification_script":"#!/bin/bash\nkubectl get secret mysqlsecret \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get deployment mysqldeployment \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get deployment mysqldeployment -o jsonpath='{.spec.strategy.type}' | grep -qx Recreate || exit 1\nIMAGE=$(kubectl get deployment mysqldeployment -o jsonpath='{.spec.template.spec.containers[0].image}' 2\u003e/dev/null)\necho \"$IMAGE\" | grep -q '^mysql' || exit 1\nREADY=$(kubectl get deployment mysqldeployment -o jsonpath='{.status.readyReplicas}' 2\u003e/dev/null)\ntest \"${READY:-0}\" -ge 1\n","hint_context":"Use `kubectl apply -f deploy.yaml`.","explanation_context":"`deploy.yaml` bundles a Secret and a Deployment separated by `---` — `kubectl apply -f`\ncreates both together. The `Recreate` strategy matters for anything backed by a\n`ReadWriteOnce` volume: the old Pod is fully terminated (releasing the volume) before a\nreplacement is created, avoiding two Pods fighting over the same non-shareable mount.\n","points":20,"is_optional":false,"is_stateful":true},{"id":"5b6345d4-ae82-5723-8185-d237c200e5bf","lab_id":"200053ab-0b4e-5000-8c2b-101de471d95c","position":5,"title":"Confirm mysqldeployment correctly mounts mysqlclaim","description":"Confirm that **mysqldeployment**'s Pod template mounts a volume named `mysqlvolume`\nbacked by claim `mysqlclaim` at path `/var/lib/mysql`, and that its\n`MYSQL_ROOT_PASSWORD` environment variable is sourced from the `mysqlsecret` Secret.\n","verification_script":"#!/bin/bash\nCLAIM=$(kubectl get deployment mysqldeployment -o jsonpath='{.spec.template.spec.volumes[?(@.name==\"mysqlvolume\")].persistentVolumeClaim.claimName}' 2\u003e/dev/null)\ntest \"$CLAIM\" = \"mysqlclaim\" || exit 1\nMOUNT=$(kubectl get deployment mysqldeployment -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.name==\"mysqlvolume\")].mountPath}' 2\u003e/dev/null)\ntest \"$MOUNT\" = \"/var/lib/mysql\" || exit 1\nSECRETREF=$(kubectl get deployment mysqldeployment -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name==\"MYSQL_ROOT_PASSWORD\")].valueFrom.secretKeyRef.name}' 2\u003e/dev/null)\ntest \"$SECRETREF\" = \"mysqlsecret\"\n","hint_context":"Inspect `.spec.template.spec.volumes` for the `persistentVolumeClaim.claimName`, and each\ncontainer's `.volumeMounts` and `.env` for the matching entries.\n","explanation_context":"A Pod claims storage by name: `volumes[].persistentVolumeClaim.claimName` points at a\nPVC in the same namespace, and `containers[].volumeMounts[].name` links a container's\nmount path back to that volume entry. A typo in either name silently drops the mount\ninstead of failing loudly, which is why this wiring is worth checking explicitly.\n","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = '582e46bf-67ec-589b-aed3-09966b1e8e3a', updated_at = now()
WHERE id = '200053ab-0b4e-5000-8c2b-101de471d95c' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('06227c73-9418-59e7-8361-7ee37e05c62a', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the lesson''s PV/PVC lab, the mysqlpv PersistentVolume is created with
`per...', 'intermediate', 2, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b7d6d2d4-6a9f-5109-8003-f05f0f969d5c', '06227c73-9418-59e7-8361-7ee37e05c62a', 1, $json${"prompt":"In the lesson's PV/PVC lab, the mysqlpv PersistentVolume is created with\n`persistentVolumeReclaimPolicy: Retain`. What happens to the underlying storage\nwhen the bound PersistentVolumeClaim (mysqlclaim) is deleted?\n","multiple":false,"options":[{"id":"a","text":"The PV is automatically deleted along with its data","is_correct":false},{"id":"b","text":"The PV is not deleted; it enters a Released state and the data is preserved for manual reclamation by an administrator","is_correct":true},{"id":"c","text":"The PV is automatically recycled and immediately rebound to a new PVC","is_correct":false},{"id":"d","text":"Deleting the PVC has no effect on the PV's lifecycle at all","is_correct":false}],"explanation":"With persistentVolumeReclaimPolicy set to Retain, deleting the PVC does not delete\nthe PV or its underlying NFS-backed data. The PV transitions to a Released state and\nmust be manually reclaimed (or deleted) by a cluster administrator — this differs from\nthe Delete policy, which removes the underlying storage automatically.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('bfb4ca2f-579f-54ff-bf4b-fb7ae9d08efa', '00000000-0000-0000-0000-000000000001', 'mcq', 'The lesson''s pv.yaml defines `accessModes: - ReadWriteOnce` for the mysqlpv
P...', 'intermediate', 2, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1d69e022-4e5b-51f8-87e4-cb5fed1acb13', 'bfb4ca2f-579f-54ff-bf4b-fb7ae9d08efa', 1, $json${"prompt":"The lesson's pv.yaml defines `accessModes: - ReadWriteOnce` for the mysqlpv\nPersistentVolume. What does the ReadWriteOnce access mode mean?\n","multiple":false,"options":[{"id":"a","text":"The volume can be mounted as read-write by many nodes simultaneously","is_correct":false},{"id":"b","text":"The volume can be mounted as read-write by a single node at a time","is_correct":true},{"id":"c","text":"The volume can only ever be mounted read-only, by any number of nodes","is_correct":false},{"id":"d","text":"The volume can be mounted read-write by one Pod but read-only by all other Pods at the same time","is_correct":false}],"explanation":"ReadWriteOnce (RWO) means the volume can be mounted read-write by a single node at a\ntime (multiple Pods on that same node can still share it). The other standard access\nmodes are ReadOnlyMany (ROX), for read-only mounts across many nodes, and\nReadWriteMany (RWX), for read-write mounts across many nodes simultaneously.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b180b6b4-ded9-5236-98d6-7d0d2824bcf5', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the lesson, the PersistentVolumeClaim (mysqlclaim) uses a label selector
m...', 'intermediate', 3, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('440877c9-d08c-5990-b21c-c2e925bb1c00', 'b180b6b4-ded9-5236-98d6-7d0d2824bcf5', 1, $json${"prompt":"In the lesson, the PersistentVolumeClaim (mysqlclaim) uses a label selector\nmatching `app: mysql` to bind to a specific PersistentVolume. What determines\nthat the PVC binds specifically to mysqlpv rather than some other PV in the cluster?\n","multiple":false,"options":[{"id":"a","text":"PVCs always bind to the first available PV in creation order; labels are ignored","is_correct":false},{"id":"b","text":"The PVC's selector matches the app=mysql label on the PV, and the PV's capacity and access modes satisfy the PVC's request","is_correct":true},{"id":"c","text":"Binding requires the PV and PVC to share the exact same metadata.name value","is_correct":false},{"id":"d","text":"Binding is decided randomly by the scheduler among all PVs with sufficient capacity","is_correct":false}],"explanation":"A PVC with a label selector only binds to a PV whose labels satisfy that selector\n(here app=mysql) and whose capacity, access modes, and storage class also satisfy the\nPVC's request. This is why mysqlclaim binds specifically to mysqlpv instead of any\nother PersistentVolume that might exist in the cluster."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('3c9d30f7-da68-5b39-b515-dcb22b6001a8', '00000000-0000-0000-0000-000000000001', 'Quiz: Storage', 'k8s-storage-quiz', 'Quiz covering Storage.', 'mcq', 'published', 'module', '84d409b8-6874-55e2-baad-70c3d9ca0b97', 15, 60, 5, 7, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('d52130d0-e7ac-5c75-8fbf-5237e7ab0c6c', '3c9d30f7-da68-5b39-b515-dcb22b6001a8', '06227c73-9418-59e7-8361-7ee37e05c62a', 'b7d6d2d4-6a9f-5109-8003-f05f0f969d5c', 0, 2),
('ca2ba92b-a7b6-5f0e-8158-9670951897cd', '3c9d30f7-da68-5b39-b515-dcb22b6001a8', 'bfb4ca2f-579f-54ff-bf4b-fb7ae9d08efa', '1d69e022-4e5b-51f8-87e4-cb5fed1acb13', 1, 2),
('648e4a7a-38be-50d6-a639-78049f6950b7', '3c9d30f7-da68-5b39-b515-dcb22b6001a8', 'b180b6b4-ded9-5236-98d6-7d0d2824bcf5', '440877c9-d08c-5990-b21c-c2e925bb1c00', 2, 3)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('84d409b8-6874-55e2-baad-70c3d9ca0b97', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '45cb3c88-5b2a-5385-98b6-2763f2717d95', 'Quiz: Storage', 'assessment', 2, 15, '3c9d30f7-da68-5b39-b515-dcb22b6001a8')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Health & Scheduling
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('52756a52-681c-5932-95e7-9e7f879beff3', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Health & Scheduling', 6)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes)
VALUES ('f4456cb5-eba5-5925-9b53-bb8b6b2f4ded', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '52756a52-681c-5932-95e7-9e7f879beff3', 'Health & Scheduling', 'notes', 0, $md$
## K8s Liveness App

## LAB: K8s Liveness Probe

This scenario shows how the liveness probe works.

### Steps

- Create 3 Pods with following YAML file (liveness.yaml):
  - In the first pod (e.g. web app), it sends HTTP Get Request to "http://localhost/healthz:8080" (port 8080)
    - If returns 400 > HTTP Code > 200, this Pod works correctly.
    - If returns HTTP Code > = 400, this Pod does not work properly.
    - initialDelaySeconds:3 => after 3 seconds, start liveness probe. 
    - periodSecond: 3 => Wait 3 seconds between each request.
  - In the second pod (e.g. console app), it controls whether a file ("healty") exists or not under specific directory ("/tmp/") with "cat" app. 
    - If returns 0 code, this Pod works correctly.
    - If returns different code except for 0 code, this Pod does not work properly.
    - initialDelaySeconds: 5 => after 5 seconds, start liveness probe. 
    - periodSecond: 5 => Wait 5 seconds between each request.
  - In the third pod (e.g. database app: mysql), it sends request over TCP Socket. 
    - If returns positive response, this Pod works correctly.
    - If returns negative response (e.g. connection refuse), this Pod does not work properly.
    - initialDelaySeconds: 15 => after 15 seconds, start liveness probe. 
    - periodSecond: 20 => Wait 20 seconds between each request.
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/liveness/liveness.yaml

```
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-http
spec:
  containers:
  - name: liveness
    image: k8s.gcr.io/liveness
    args:
    - /server
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
        httpHeaders:
        - name: Custom-Header
          value: Awesome
      initialDelaySeconds: 3
      periodSeconds: 3
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-exec
spec:
  containers:
  - name: liveness
    image: k8s.gcr.io/busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
---
apiVersion: v1
kind: Pod
metadata:
  name: goproxy
  labels:
    app: goproxy
spec:
  containers:
  - name: goproxy
    image: k8s.gcr.io/goproxy:0.1
    ports:
    - containerPort: 8080
    livenessProbe:
      tcpSocket:
        port: 8080
      initialDelaySeconds: 15
      periodSeconds: 20
 ```
 
![image](https://user-images.githubusercontent.com/10358317/154686744-fa7bd4bd-6cf4-460f-bbe8-93f827eeb1de.png)

![image](https://user-images.githubusercontent.com/10358317/154686826-0828adb8-7581-4d56-987f-7858bd0711b4.png)

![image](https://user-images.githubusercontent.com/10358317/154686913-4d5cc891-b3cc-497d-b8be-568faccf4bc0.png)

- Run on terminal: kubectl apply -f liveness.yaml
- Run on another terminal: kubectl get pods -o wide --all-namespaces

 ![image](https://user-images.githubusercontent.com/10358317/150846081-7e9142d1-b833-431f-82bc-a7385c73a875.png)
 
- Run to see details of liveness-http pod: kubectl describe pod liveness-http

![image](https://user-images.githubusercontent.com/10358317/150846456-5273b1f8-7043-4fa1-804c-77da74aca8de.png)


## K8s Node Affinity

## LAB: K8s Node Affinity

This scenario shows:
- how to label the node,
- when node is not labelled and pods' nodeAffinity are defined, pods always wait pending 


### Steps

- Run minikube  (in this scenario, K8s runs on WSL2- Ubuntu 20.04) ("minikube start")

![image](https://user-images.githubusercontent.com/10358317/153183333-371fe598-d5a4-4b86-9b5d-9e33f35063cc.png)

- Create Yaml file (podnodeaffinity.yaml) in your directory and copy the below definition into the file.
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/affinity/podnodeaffinity.yaml

``` 
apiVersion: v1
kind: Pod
metadata:
  name: nodeaffinitypod1
spec:
  containers:
  - name: nodeaffinity1
    image: nginx:latest                                     # "requiredDuringSchedulingIgnoredDuringExecution" means
  affinity:                                                 # Find a node during scheduling according to "matchExpression" and run pod on that node. 
    nodeAffinity:                                           # If it is not found, do not run this pod until finding specific node "matchExpression".
      requiredDuringSchedulingIgnoredDuringExecution:       # "...IgnoredDuringExecution" means  
        nodeSelectorTerms:                                  # after scheduling, if the node label is removed/deleted from node, ignore it while executing. 
        - matchExpressions:
          - key: app
            operator: In                                    # In, NotIn, Exists, DoesNotExist
            values:                                         # In => key=value,    NotIn => key!=value
            - production                                    # Exists => only key   
---
apiVersion: v1
kind: Pod
metadata:
  name: nodeaffinitypod2
spec:
  containers:
  - name: nodeaffinity2
    image: nginx:latest
  affinity:                                                 # "preferredDuringSchedulingIgnoredDuringExecution" means
    nodeAffinity:                                           # Find a node during scheduling according to "matchExpression" and run pod on that node. 
      preferredDuringSchedulingIgnoredDuringExecution:      # If it is not found, run this pod wherever it finds.
      - weight: 1                                           # if there is a pod with "app=production", run on that pod
        preference:                                         # if there is NOT a pod with "app=production" and there is NOT any other preference, 
          matchExpressions:                                 # run this pod wherever scheduler finds a node. 
          - key: app
            operator: In
            values:
            - production
      - weight: 2                                           # this is highest prior, weight:2 > weight:1
        preference:                                         # if there is a pod with "app=test", run on that pod
          matchExpressions:                                 # if there is NOT a pod with "app=test", goto weight:1 preference
          - key: app
            operator: In
            values:
            - test
---
apiVersion: v1
kind: Pod
metadata:
  name: nodeaffinitypod3
spec:
  containers:
  - name: nodeaffinity3
    image: nginx:latest
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: app
            operator: Exists                                # In, NotIn, Exists, DoesNotExist
```

![image](https://user-images.githubusercontent.com/10358317/154728538-90ae7179-1fcb-4e96-9376-b089cffc5adf.png)

![image](https://user-images.githubusercontent.com/10358317/154728650-3f622711-dc2b-4e2c-8fce-966c8e892824.png)

![image](https://user-images.githubusercontent.com/10358317/154728769-784f3fb5-59b5-48bb-adc5-8bce0bf57acc.png)

- Create pods:
  - 1st pod waits pending: Because it controls labelled "app:production" node, but it does not find, so it waits until finding labelled "app:production" node.
  - 2nd pod started: Because it controls the labels first, but "preferredDuringScheduling", even if it does not find, run anywhere.
  - 3rd pod waits pending: Because it controls labelled "app" node, but it does not find, so it waits until finding labelled "app" node.
  
![image](https://user-images.githubusercontent.com/10358317/153663079-4ce6a3cd-68a5-4df7-af2b-8c7a9bb3ea67.png)

- After labelling node with label "app:production", 1st and 3rd nodes also run on the same node. Because they find the required label. 

```
kubectl label node minikube app=production
```
![image](https://user-images.githubusercontent.com/10358317/153664135-9752ca3b-6154-41bd-a026-7bb063bdbf23.png)

- After unlabelling the node, all pods still run due to "IgnoredDuringExecution". Node ignores the label controlling after execution.

```
kubectl label node minikube app-
```

![image](https://user-images.githubusercontent.com/10358317/153664599-b6426c70-93c3-45a7-95bf-721cded025e7.png)

- Delete pods:

![image](https://user-images.githubusercontent.com/10358317/153665104-11406023-86c5-456b-89a8-7ba486f2c560.png)




## K8s Taint Toleration

## LAB: K8s Taint Toleration

This scenario shows:
- how to taint/untaint the node,
- how to see the node details,
- the pod that does not tolerate the taint is not running the node.


### Steps

- Run minikube  (in this scenario, K8s runs on WSL2- Ubuntu 20.04) ("minikube start")

![image](https://user-images.githubusercontent.com/10358317/153183333-371fe598-d5a4-4b86-9b5d-9e33f35063cc.png)

- Create Yaml file (podtoleration.yaml) in your directory and copy the below definition into the file.
- File: https://github.com/omerbsezer/Fast-Kubernetes/blob/main/labs/tainttoleration/podtoleration.yaml

``` 
apiVersion: v1
kind: Pod
metadata:
  name: toleratedpod1
  labels:
    env: test
spec:
  containers:
  - name: toleratedcontainer1
    image: nginx:latest
  tolerations:                    # pod tolerates "app=production:NoSchedule"
  - key: "app"
    operator: "Equal"
    value: "production"
    effect: "NoSchedule"
---
apiVersion: v1
kind: Pod
metadata:
  name: toleratedpod2
  labels:
    env: test
spec:
  containers:
  - name: toleratedcontainer2
    image: nginx:latest
  tolerations:
  - key: "app"                     # pod tolerates "app:NoSchedule", value is not important in this pod
    operator: "Exists"             # pod can run on the nodes which has "app=test:NoSchedule" or "app=production:NoSchedule"
    effect: "NoSchedule" 
```

![image](https://user-images.githubusercontent.com/10358317/154731410-8f2da14f-b98f-4958-8335-6488cb00e89f.png)

![image](https://user-images.githubusercontent.com/10358317/154731465-9d15d24d-089a-4f93-8b3d-0a9f637c0b1f.png)

- When we look at the node details, there is not any taint on the node (minikube):
```
kubectl describe node minikube
```
![image](https://user-images.githubusercontent.com/10358317/153669930-0ef1e295-f11d-49a3-9df0-4caae0a43349.png)

- Add taint to the node (minikube):
```
kubectl taint node minikube platform=production:NoSchedule
```
![image](https://user-images.githubusercontent.com/10358317/153670171-a5c3366b-c996-4d45-acd3-33dada7222b8.png)

- Create pod that does not tolerate the taint:
```
kubectl run test --image=nginx --restart=Never
```
![image](https://user-images.githubusercontent.com/10358317/153670451-f7a2657b-9c34-413e-8a00-b4c5f645e088.png)

- This pod always waits as pending, because it is not tolerated the taints:

![image](https://user-images.githubusercontent.com/10358317/153670590-3477dd11-d328-4291-96fa-8b811a301037.png)

![image](https://user-images.githubusercontent.com/10358317/153670825-0c2e7736-0d1c-4b97-be57-0fbae607ccc6.png)


- In the yaml file above (podtoleration.yaml), we have 2 pods that tolerates this taint => "app=production:NoSchedule"
- Create these 2 pods:

![image](https://user-images.githubusercontent.com/10358317/153671055-2bf48e13-abbe-46dd-8dd6-14274109a503.png)

- These pods tolerate the taint and they are running on the node, but "test" does not tolerate the taint, it still waits:

![image](https://user-images.githubusercontent.com/10358317/153671160-c96e5084-4314-486b-9d57-850acf63e973.png)

- But if we define another taint with "NoExecute", running pods are terminated:
```
kubectl taint node minikube version=new:NoExecute
```
![image](https://user-images.githubusercontent.com/10358317/153671667-f5901893-9a9b-4f59-b482-30639432c0af.png)

![image](https://user-images.githubusercontent.com/10358317/153672106-436e0268-82e1-40da-990f-9d98fbfd44ca.png)

- Delete taint from the node:
```
kubectl taint node minikube version-
```
![image](https://user-images.githubusercontent.com/10358317/153672236-97528ceb-aedd-4bb4-b8b1-172215027237.png)

- Delete minikube:

![image](https://user-images.githubusercontent.com/10358317/153672400-2d2b7843-5acb-4e8a-8a3b-5aef04dc2a80.png)
$md$, 45)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('3f32decd-a21f-5364-9ff2-51fb58bd6ade', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '52756a52-681c-5932-95e7-9e7f879beff3', 'Lab: Liveness Probe', 'lab', 1, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('7c9b2dc7-980f-5474-b333-061e60f64c3c', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '3f32decd-a21f-5364-9ff2-51fb58bd6ade', 'module', 'Lab: Liveness Probe', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/liveness.yaml <<'MFEOF'
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-http
spec:
  containers:
  - name: liveness
    image: k8s.gcr.io/liveness
    args:
    - /server
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
        httpHeaders:
        - name: Custom-Header
          value: Awesome
      initialDelaySeconds: 3
      periodSeconds: 3
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-exec
spec:
  containers:
  - name: liveness
    image: k8s.gcr.io/busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
---
apiVersion: v1
kind: Pod
metadata:
  name: goproxy
  labels:
    app: goproxy
spec:
  containers:
  - name: goproxy
    image: k8s.gcr.io/goproxy:0.1
    ports:
    - containerPort: 8080
    livenessProbe:
      tcpSocket:
        port: 8080
      initialDelaySeconds: 15
      periodSeconds: 20
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('64992d5d-2db1-516d-a141-99139ea7a8f3', '7c9b2dc7-980f-5474-b333-061e60f64c3c', 1, 'Create the liveness-http, liveness-exec, and goproxy Pods', $md$Apply `liveness.yaml` (already in your workdir) to create three Pods, each declaring a
different liveness probe mechanism: **liveness-http** (`httpGet`), **liveness-exec**
(`exec`), and **goproxy** (`tcpSocket`).
$md$, $script$#!/bin/bash
for p in liveness-http liveness-exec goproxy; do
  kubectl get pod "$p" --no-headers 2>/dev/null | grep -q Running || exit 1
done
$script$, 'Use `kubectl apply -f liveness.yaml`.', '`liveness.yaml` bundles three Pod manifests separated by `---`, each demonstrating one of
the three liveness probe types Kubernetes supports: an HTTP GET request, an exec command
inside the container, and a raw TCP socket connect. `kubectl apply -f` creates all three
with a single command.
', 15, false, true),
('d27f26ae-f52b-5f31-8ccc-aa487cee7016', '7c9b2dc7-980f-5474-b333-061e60f64c3c', 2, 'Confirm the liveness-http Pod''s httpGet probe configuration', $md$Confirm that the **liveness-http** Pod's container declares an `httpGet` liveness probe
targeting path **`/healthz`** on port **`8080`**, with `initialDelaySeconds: 3` and
`periodSeconds: 3`.
$md$, $script$#!/bin/bash
P='{.spec.containers[0].livenessProbe'
kubectl get pod liveness-http -o jsonpath="${P}.httpGet.path}" | grep -qx /healthz || exit 1
kubectl get pod liveness-http -o jsonpath="${P}.httpGet.port}" | grep -qx 8080 || exit 1
kubectl get pod liveness-http -o jsonpath="${P}.initialDelaySeconds}" | grep -qx 3 || exit 1
kubectl get pod liveness-http -o jsonpath="${P}.periodSeconds}" | grep -qx 3
$script$, 'Inspect `kubectl get pod liveness-http -o yaml` or query
`.spec.containers[0].livenessProbe` with `jsonpath`.
', '`httpGet` probes ask the kubelet to send a GET request to the container''s IP at the given
path and port on every `periodSeconds` interval, starting `initialDelaySeconds` after the
container starts. A non-2xx/3xx response (or connection failure) counts as a probe
failure — after enough consecutive failures (`failureThreshold`, defaulting to 3), the
kubelet restarts the container.
', 20, false, false),
('5f8069fc-b19f-5814-b1b5-0049d9fc5594', '7c9b2dc7-980f-5474-b333-061e60f64c3c', 3, 'Confirm the liveness-exec Pod''s exec probe configuration', $md$Confirm that the **liveness-exec** Pod's container declares an `exec` liveness probe
running the command **`cat /tmp/healthy`**, with `initialDelaySeconds: 5` and
`periodSeconds: 5`.
$md$, $script$#!/bin/bash
P='{.spec.containers[0].livenessProbe'
kubectl get pod liveness-exec -o jsonpath="${P}.exec.command[0]}" | grep -qx cat || exit 1
kubectl get pod liveness-exec -o jsonpath="${P}.exec.command[1]}" | grep -qx /tmp/healthy || exit 1
kubectl get pod liveness-exec -o jsonpath="${P}.initialDelaySeconds}" | grep -qx 5 || exit 1
kubectl get pod liveness-exec -o jsonpath="${P}.periodSeconds}" | grep -qx 5
$script$, 'Inspect `kubectl get pod liveness-exec -o yaml` or query
`.spec.containers[0].livenessProbe.exec` with `jsonpath`.
', 'This Pod''s container runs `touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600` —
on a real kubelet, the `cat /tmp/healthy` exec probe would succeed (exit 0) for the first
30 seconds, then fail continuously once the file is removed, eventually triggering a
restart. This lab''s cluster is **kwok-simulated**: there is no real container process for
kwok''s fake kubelet to exec into, so it never actually runs the probe command or restarts
anything — `.status.containerStatuses[].restartCount` will not reflect real probe
behavior here. That''s why this task (and its siblings) verify the **declared probe spec**
on `.spec.containers[0].livenessProbe` rather than any observed runtime outcome.
', 20, false, false),
('d5aa4d85-8bb9-5a75-a522-61bc3faa21e0', '7c9b2dc7-980f-5474-b333-061e60f64c3c', 4, 'Confirm the goproxy Pod''s tcpSocket probe configuration', $md$Confirm that the **goproxy** Pod's container declares a `tcpSocket` liveness probe
targeting port **`8080`**, with `initialDelaySeconds: 15` and `periodSeconds: 20`.
$md$, $script$#!/bin/bash
P='{.spec.containers[0].livenessProbe'
kubectl get pod goproxy -o jsonpath="${P}.tcpSocket.port}" | grep -qx 8080 || exit 1
kubectl get pod goproxy -o jsonpath="${P}.initialDelaySeconds}" | grep -qx 15 || exit 1
kubectl get pod goproxy -o jsonpath="${P}.periodSeconds}" | grep -qx 20
$script$, 'Inspect `kubectl get pod goproxy -o yaml` or query
`.spec.containers[0].livenessProbe.tcpSocket` with `jsonpath`.
', '`tcpSocket` probes are the cheapest liveness check: the kubelet just attempts a TCP
connection to the given port and considers it a success if the connection opens. It''s
useful for protocols that don''t speak HTTP but does not verify that the application is
actually functioning correctly — only that something is listening on the port.
', 15, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('0eaedfda-dd2b-59b1-a546-6e2e3c5ac7a2', '7c9b2dc7-980f-5474-b333-061e60f64c3c', 1, $json$[{"id":"64992d5d-2db1-516d-a141-99139ea7a8f3","lab_id":"7c9b2dc7-980f-5474-b333-061e60f64c3c","position":1,"title":"Create the liveness-http, liveness-exec, and goproxy Pods","description":"Apply `liveness.yaml` (already in your workdir) to create three Pods, each declaring a\ndifferent liveness probe mechanism: **liveness-http** (`httpGet`), **liveness-exec**\n(`exec`), and **goproxy** (`tcpSocket`).\n","verification_script":"#!/bin/bash\nfor p in liveness-http liveness-exec goproxy; do\n  kubectl get pod \"$p\" --no-headers 2\u003e/dev/null | grep -q Running || exit 1\ndone\n","hint_context":"Use `kubectl apply -f liveness.yaml`.","explanation_context":"`liveness.yaml` bundles three Pod manifests separated by `---`, each demonstrating one of\nthe three liveness probe types Kubernetes supports: an HTTP GET request, an exec command\ninside the container, and a raw TCP socket connect. `kubectl apply -f` creates all three\nwith a single command.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"d27f26ae-f52b-5f31-8ccc-aa487cee7016","lab_id":"7c9b2dc7-980f-5474-b333-061e60f64c3c","position":2,"title":"Confirm the liveness-http Pod's httpGet probe configuration","description":"Confirm that the **liveness-http** Pod's container declares an `httpGet` liveness probe\ntargeting path **`/healthz`** on port **`8080`**, with `initialDelaySeconds: 3` and\n`periodSeconds: 3`.\n","verification_script":"#!/bin/bash\nP='{.spec.containers[0].livenessProbe'\nkubectl get pod liveness-http -o jsonpath=\"${P}.httpGet.path}\" | grep -qx /healthz || exit 1\nkubectl get pod liveness-http -o jsonpath=\"${P}.httpGet.port}\" | grep -qx 8080 || exit 1\nkubectl get pod liveness-http -o jsonpath=\"${P}.initialDelaySeconds}\" | grep -qx 3 || exit 1\nkubectl get pod liveness-http -o jsonpath=\"${P}.periodSeconds}\" | grep -qx 3\n","hint_context":"Inspect `kubectl get pod liveness-http -o yaml` or query\n`.spec.containers[0].livenessProbe` with `jsonpath`.\n","explanation_context":"`httpGet` probes ask the kubelet to send a GET request to the container's IP at the given\npath and port on every `periodSeconds` interval, starting `initialDelaySeconds` after the\ncontainer starts. A non-2xx/3xx response (or connection failure) counts as a probe\nfailure — after enough consecutive failures (`failureThreshold`, defaulting to 3), the\nkubelet restarts the container.\n","points":20,"is_optional":false,"is_stateful":false},{"id":"5f8069fc-b19f-5814-b1b5-0049d9fc5594","lab_id":"7c9b2dc7-980f-5474-b333-061e60f64c3c","position":3,"title":"Confirm the liveness-exec Pod's exec probe configuration","description":"Confirm that the **liveness-exec** Pod's container declares an `exec` liveness probe\nrunning the command **`cat /tmp/healthy`**, with `initialDelaySeconds: 5` and\n`periodSeconds: 5`.\n","verification_script":"#!/bin/bash\nP='{.spec.containers[0].livenessProbe'\nkubectl get pod liveness-exec -o jsonpath=\"${P}.exec.command[0]}\" | grep -qx cat || exit 1\nkubectl get pod liveness-exec -o jsonpath=\"${P}.exec.command[1]}\" | grep -qx /tmp/healthy || exit 1\nkubectl get pod liveness-exec -o jsonpath=\"${P}.initialDelaySeconds}\" | grep -qx 5 || exit 1\nkubectl get pod liveness-exec -o jsonpath=\"${P}.periodSeconds}\" | grep -qx 5\n","hint_context":"Inspect `kubectl get pod liveness-exec -o yaml` or query\n`.spec.containers[0].livenessProbe.exec` with `jsonpath`.\n","explanation_context":"This Pod's container runs `touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600` —\non a real kubelet, the `cat /tmp/healthy` exec probe would succeed (exit 0) for the first\n30 seconds, then fail continuously once the file is removed, eventually triggering a\nrestart. This lab's cluster is **kwok-simulated**: there is no real container process for\nkwok's fake kubelet to exec into, so it never actually runs the probe command or restarts\nanything — `.status.containerStatuses[].restartCount` will not reflect real probe\nbehavior here. That's why this task (and its siblings) verify the **declared probe spec**\non `.spec.containers[0].livenessProbe` rather than any observed runtime outcome.\n","points":20,"is_optional":false,"is_stateful":false},{"id":"d5aa4d85-8bb9-5a75-a522-61bc3faa21e0","lab_id":"7c9b2dc7-980f-5474-b333-061e60f64c3c","position":4,"title":"Confirm the goproxy Pod's tcpSocket probe configuration","description":"Confirm that the **goproxy** Pod's container declares a `tcpSocket` liveness probe\ntargeting port **`8080`**, with `initialDelaySeconds: 15` and `periodSeconds: 20`.\n","verification_script":"#!/bin/bash\nP='{.spec.containers[0].livenessProbe'\nkubectl get pod goproxy -o jsonpath=\"${P}.tcpSocket.port}\" | grep -qx 8080 || exit 1\nkubectl get pod goproxy -o jsonpath=\"${P}.initialDelaySeconds}\" | grep -qx 15 || exit 1\nkubectl get pod goproxy -o jsonpath=\"${P}.periodSeconds}\" | grep -qx 20\n","hint_context":"Inspect `kubectl get pod goproxy -o yaml` or query\n`.spec.containers[0].livenessProbe.tcpSocket` with `jsonpath`.\n","explanation_context":"`tcpSocket` probes are the cheapest liveness check: the kubelet just attempts a TCP\nconnection to the given port and considers it a success if the connection opens. It's\nuseful for protocols that don't speak HTTP but does not verify that the application is\nactually functioning correctly — only that something is listening on the port.\n","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = '0eaedfda-dd2b-59b1-a546-6e2e3c5ac7a2', updated_at = now()
WHERE id = '7c9b2dc7-980f-5474-b333-061e60f64c3c' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('3a44e100-25c4-5b5c-bff7-79071fdc86ae', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '52756a52-681c-5932-95e7-9e7f879beff3', 'Lab: Node Affinity', 'lab', 2, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('618e6f99-3c6f-59bb-8306-a2af680012b8', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '3a44e100-25c4-5b5c-bff7-79071fdc86ae', 'module', 'Lab: Node Affinity', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/podnodeaffinity.yaml <<'MFEOF'
apiVersion: v1
kind: Pod
metadata:
  name: nodeaffinitypod1
spec:
  containers:
  - name: nodeaffinity1
    image: nginx:latest
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: app
            operator: In #In, NotIn, Exists, DoesNotExist
            values:
            - production
---
apiVersion: v1
kind: Pod
metadata:
  name: nodeaffinitypod2
spec:
  containers:
  - name: nodeaffinity2
    image: nginx:latest
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: app
            operator: In
            values:
            - production
      - weight: 2
        preference:
          matchExpressions:
          - key: app
            operator: In
            values:
            - test
---
apiVersion: v1
kind: Pod
metadata:
  name: nodeaffinitypod3
spec:
  containers:
  - name: nodeaffinity3
    image: nginx:latest
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: app
            operator: Exists #In, NotIn, Exists, DoesNotExist
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('bc72c391-7f55-5bd9-9b45-ec86fc8366c5', '618e6f99-3c6f-59bb-8306-a2af680012b8', 1, 'Create the three node affinity Pods', $md$Apply `podnodeaffinity.yaml` (already in your workdir) to create three Pods —
**nodeaffinitypod1**, **nodeaffinitypod2**, and **nodeaffinitypod3** — each declaring a
different `nodeAffinity` rule shape.
$md$, $script$#!/bin/bash
kubectl get pod nodeaffinitypod1 >/dev/null 2>&1 || exit 1
kubectl get pod nodeaffinitypod2 >/dev/null 2>&1 || exit 1
kubectl get pod nodeaffinitypod3 >/dev/null 2>&1 || exit 1
$script$, 'Use `kubectl apply -f podnodeaffinity.yaml`.', 'The manifest bundles three Pod definitions separated by `---`; `kubectl apply -f`
creates all three with a single command. Each Pod exercises a different nodeAffinity
rule: a hard `required` rule with `In`, a soft `preferred` rule with two weighted terms,
and a hard `required` rule with `Exists`.
', 15, false, true),
('061c72a1-5bf6-529b-b767-fd4b57cf3503', '618e6f99-3c6f-59bb-8306-a2af680012b8', 2, 'Confirm nodeaffinitypod1''s required affinity rule', $md$Confirm that **nodeaffinitypod1** declares a `required` nodeAffinity rule under
`.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution` matching
key `app`, operator `In`, values `[production]`.
$md$, $script$#!/bin/bash
BASE='{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0]'
KEY=$(kubectl get pod nodeaffinitypod1 -o jsonpath="${BASE}.key}")
OP=$(kubectl get pod nodeaffinitypod1 -o jsonpath="${BASE}.operator}")
VAL=$(kubectl get pod nodeaffinitypod1 -o jsonpath="${BASE}.values[0]}")
echo "$KEY" | grep -qx app || exit 1
echo "$OP" | grep -qx In || exit 1
echo "$VAL" | grep -qx production
$script$, 'Inspect `.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution` with
`kubectl get pod nodeaffinitypod1 -o yaml`.
', '`requiredDuringSchedulingIgnoredDuringExecution` is a hard constraint — the scheduler
will not bind this Pod to any node whose labels don''t satisfy every `matchExpressions`
entry inside at least one `nodeSelectorTerms` block. "IgnoredDuringExecution" means a
Pod already running is not evicted later if the node''s labels change.
', 15, false, false),
('7e9eac5b-de11-5111-97ab-dd17b16d0358', '618e6f99-3c6f-59bb-8306-a2af680012b8', 3, 'Confirm nodeaffinitypod2''s preferred affinity terms', $md$Confirm that **nodeaffinitypod2** declares two `preferred` nodeAffinity terms under
`.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution` — weight
`1` preferring `app In [production]`, and weight `2` preferring `app In [test]`.
$md$, $script$#!/bin/bash
BASE='{.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution'
W0=$(kubectl get pod nodeaffinitypod2 -o jsonpath="${BASE}[0].weight}")
V0=$(kubectl get pod nodeaffinitypod2 -o jsonpath="${BASE}[0].preference.matchExpressions[0].values[0]}")
W1=$(kubectl get pod nodeaffinitypod2 -o jsonpath="${BASE}[1].weight}")
V1=$(kubectl get pod nodeaffinitypod2 -o jsonpath="${BASE}[1].preference.matchExpressions[0].values[0]}")
echo "$W0" | grep -qx 1 || exit 1
echo "$V0" | grep -qx production || exit 1
echo "$W1" | grep -qx 2 || exit 1
echo "$V1" | grep -qx test
$script$, 'Use `kubectl get pod nodeaffinitypod2 -o jsonpath=''{.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution}''`.
', '`preferredDuringSchedulingIgnoredDuringExecution` is a soft constraint — the scheduler
scores nodes that satisfy each term by its `weight` and favors higher-scoring nodes, but
will still schedule the Pod on a node that satisfies neither term if nothing else fits.
Since this Pod has no `required` rule, it is never blocked by the absence of an `app`
label anywhere in the cluster.
', 15, false, false),
('688c2790-92f7-5900-805c-a3de3b6270b5', '618e6f99-3c6f-59bb-8306-a2af680012b8', 4, 'Confirm nodeaffinitypod3''s Exists operator rule', $md$Confirm that **nodeaffinitypod3** declares a `required` nodeAffinity rule using operator
`Exists` on key `app` — `Exists` takes no `values` list; it only checks that the label
key is present on the node, regardless of its value.
$md$, $script$#!/bin/bash
BASE='{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0]'
KEY=$(kubectl get pod nodeaffinitypod3 -o jsonpath="${BASE}.key}")
OP=$(kubectl get pod nodeaffinitypod3 -o jsonpath="${BASE}.operator}")
echo "$KEY" | grep -qx app || exit 1
echo "$OP" | grep -qx Exists
$script$, 'Use `kubectl get pod nodeaffinitypod3 -o jsonpath=''{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0]}''`.
', '`Exists` (like `DoesNotExist`) is a key-only operator — it never takes a `values` list.
It matches any node carrying the label key `app` regardless of what it''s set to, unlike
`In`/`NotIn`, which also compare the value.
', 15, false, false),
('fdbf9e54-459a-50bb-8353-19e824c8f550', '618e6f99-3c6f-59bb-8306-a2af680012b8', 5, 'Confirm the actual scheduling outcome on the fake node', $md$This lab's cluster has a single fake (kwok) node whose labels are only
`kubernetes.io/*`, `beta.kubernetes.io/*`, `node-role.kubernetes.io/agent`, and
`type=kwok` — it carries **no `app` label at all**. Confirm the scheduling outcome this
produces: **nodeaffinitypod2** (soft preference only) reaches `Running`, while
**nodeaffinitypod1** and **nodeaffinitypod3** (hard `required` rules keyed on the
missing `app` label) remain `Pending` because no node in the cluster satisfies their
`nodeSelectorTerms`.
$md$, $script$#!/bin/bash
PHASE2=$(kubectl get pod nodeaffinitypod2 -o jsonpath='{.status.phase}')
echo "$PHASE2" | grep -qx Running || exit 1
PHASE1=$(kubectl get pod nodeaffinitypod1 -o jsonpath='{.status.phase}')
echo "$PHASE1" | grep -qx Pending || exit 1
PHASE3=$(kubectl get pod nodeaffinitypod3 -o jsonpath='{.status.phase}')
echo "$PHASE3" | grep -qx Pending
$script$, 'Compare `kubectl get pods -o wide` for all three Pods against the node''s real labels via
`kubectl get nodes --show-labels` — none of them start with `app`.
', 'A `required` nodeAffinity rule is enforced at scheduling time: if no node''s labels
satisfy it, the scheduler leaves the Pod unbound (`Pending`) indefinitely rather than
falling back to a mismatched node. Both `nodeaffinitypod1` (`In [production]`) and
`nodeaffinitypod3` (`Exists`) key on `app`, a label the single fake node never carries,
so neither can ever be scheduled here. `nodeaffinitypod2` has no `required` rule — only
two `preferred` terms — so the scheduler simply ranks the one available node (which
matches neither preference, scoring 0) and schedules the Pod anyway, reaching `Running`.
', 20, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('1d2949c0-a5df-546e-9d12-fa20bb497bf6', '618e6f99-3c6f-59bb-8306-a2af680012b8', 1, $json$[{"id":"bc72c391-7f55-5bd9-9b45-ec86fc8366c5","lab_id":"618e6f99-3c6f-59bb-8306-a2af680012b8","position":1,"title":"Create the three node affinity Pods","description":"Apply `podnodeaffinity.yaml` (already in your workdir) to create three Pods —\n**nodeaffinitypod1**, **nodeaffinitypod2**, and **nodeaffinitypod3** — each declaring a\ndifferent `nodeAffinity` rule shape.\n","verification_script":"#!/bin/bash\nkubectl get pod nodeaffinitypod1 \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get pod nodeaffinitypod2 \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get pod nodeaffinitypod3 \u003e/dev/null 2\u003e\u00261 || exit 1\n","hint_context":"Use `kubectl apply -f podnodeaffinity.yaml`.","explanation_context":"The manifest bundles three Pod definitions separated by `---`; `kubectl apply -f`\ncreates all three with a single command. Each Pod exercises a different nodeAffinity\nrule: a hard `required` rule with `In`, a soft `preferred` rule with two weighted terms,\nand a hard `required` rule with `Exists`.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"061c72a1-5bf6-529b-b767-fd4b57cf3503","lab_id":"618e6f99-3c6f-59bb-8306-a2af680012b8","position":2,"title":"Confirm nodeaffinitypod1's required affinity rule","description":"Confirm that **nodeaffinitypod1** declares a `required` nodeAffinity rule under\n`.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution` matching\nkey `app`, operator `In`, values `[production]`.\n","verification_script":"#!/bin/bash\nBASE='{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0]'\nKEY=$(kubectl get pod nodeaffinitypod1 -o jsonpath=\"${BASE}.key}\")\nOP=$(kubectl get pod nodeaffinitypod1 -o jsonpath=\"${BASE}.operator}\")\nVAL=$(kubectl get pod nodeaffinitypod1 -o jsonpath=\"${BASE}.values[0]}\")\necho \"$KEY\" | grep -qx app || exit 1\necho \"$OP\" | grep -qx In || exit 1\necho \"$VAL\" | grep -qx production\n","hint_context":"Inspect `.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution` with\n`kubectl get pod nodeaffinitypod1 -o yaml`.\n","explanation_context":"`requiredDuringSchedulingIgnoredDuringExecution` is a hard constraint — the scheduler\nwill not bind this Pod to any node whose labels don't satisfy every `matchExpressions`\nentry inside at least one `nodeSelectorTerms` block. \"IgnoredDuringExecution\" means a\nPod already running is not evicted later if the node's labels change.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"7e9eac5b-de11-5111-97ab-dd17b16d0358","lab_id":"618e6f99-3c6f-59bb-8306-a2af680012b8","position":3,"title":"Confirm nodeaffinitypod2's preferred affinity terms","description":"Confirm that **nodeaffinitypod2** declares two `preferred` nodeAffinity terms under\n`.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution` — weight\n`1` preferring `app In [production]`, and weight `2` preferring `app In [test]`.\n","verification_script":"#!/bin/bash\nBASE='{.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution'\nW0=$(kubectl get pod nodeaffinitypod2 -o jsonpath=\"${BASE}[0].weight}\")\nV0=$(kubectl get pod nodeaffinitypod2 -o jsonpath=\"${BASE}[0].preference.matchExpressions[0].values[0]}\")\nW1=$(kubectl get pod nodeaffinitypod2 -o jsonpath=\"${BASE}[1].weight}\")\nV1=$(kubectl get pod nodeaffinitypod2 -o jsonpath=\"${BASE}[1].preference.matchExpressions[0].values[0]}\")\necho \"$W0\" | grep -qx 1 || exit 1\necho \"$V0\" | grep -qx production || exit 1\necho \"$W1\" | grep -qx 2 || exit 1\necho \"$V1\" | grep -qx test\n","hint_context":"Use `kubectl get pod nodeaffinitypod2 -o jsonpath='{.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution}'`.\n","explanation_context":"`preferredDuringSchedulingIgnoredDuringExecution` is a soft constraint — the scheduler\nscores nodes that satisfy each term by its `weight` and favors higher-scoring nodes, but\nwill still schedule the Pod on a node that satisfies neither term if nothing else fits.\nSince this Pod has no `required` rule, it is never blocked by the absence of an `app`\nlabel anywhere in the cluster.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"688c2790-92f7-5900-805c-a3de3b6270b5","lab_id":"618e6f99-3c6f-59bb-8306-a2af680012b8","position":4,"title":"Confirm nodeaffinitypod3's Exists operator rule","description":"Confirm that **nodeaffinitypod3** declares a `required` nodeAffinity rule using operator\n`Exists` on key `app` — `Exists` takes no `values` list; it only checks that the label\nkey is present on the node, regardless of its value.\n","verification_script":"#!/bin/bash\nBASE='{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0]'\nKEY=$(kubectl get pod nodeaffinitypod3 -o jsonpath=\"${BASE}.key}\")\nOP=$(kubectl get pod nodeaffinitypod3 -o jsonpath=\"${BASE}.operator}\")\necho \"$KEY\" | grep -qx app || exit 1\necho \"$OP\" | grep -qx Exists\n","hint_context":"Use `kubectl get pod nodeaffinitypod3 -o jsonpath='{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0]}'`.\n","explanation_context":"`Exists` (like `DoesNotExist`) is a key-only operator — it never takes a `values` list.\nIt matches any node carrying the label key `app` regardless of what it's set to, unlike\n`In`/`NotIn`, which also compare the value.\n","points":15,"is_optional":false,"is_stateful":false},{"id":"fdbf9e54-459a-50bb-8353-19e824c8f550","lab_id":"618e6f99-3c6f-59bb-8306-a2af680012b8","position":5,"title":"Confirm the actual scheduling outcome on the fake node","description":"This lab's cluster has a single fake (kwok) node whose labels are only\n`kubernetes.io/*`, `beta.kubernetes.io/*`, `node-role.kubernetes.io/agent`, and\n`type=kwok` — it carries **no `app` label at all**. Confirm the scheduling outcome this\nproduces: **nodeaffinitypod2** (soft preference only) reaches `Running`, while\n**nodeaffinitypod1** and **nodeaffinitypod3** (hard `required` rules keyed on the\nmissing `app` label) remain `Pending` because no node in the cluster satisfies their\n`nodeSelectorTerms`.\n","verification_script":"#!/bin/bash\nPHASE2=$(kubectl get pod nodeaffinitypod2 -o jsonpath='{.status.phase}')\necho \"$PHASE2\" | grep -qx Running || exit 1\nPHASE1=$(kubectl get pod nodeaffinitypod1 -o jsonpath='{.status.phase}')\necho \"$PHASE1\" | grep -qx Pending || exit 1\nPHASE3=$(kubectl get pod nodeaffinitypod3 -o jsonpath='{.status.phase}')\necho \"$PHASE3\" | grep -qx Pending\n","hint_context":"Compare `kubectl get pods -o wide` for all three Pods against the node's real labels via\n`kubectl get nodes --show-labels` — none of them start with `app`.\n","explanation_context":"A `required` nodeAffinity rule is enforced at scheduling time: if no node's labels\nsatisfy it, the scheduler leaves the Pod unbound (`Pending`) indefinitely rather than\nfalling back to a mismatched node. Both `nodeaffinitypod1` (`In [production]`) and\n`nodeaffinitypod3` (`Exists`) key on `app`, a label the single fake node never carries,\nso neither can ever be scheduled here. `nodeaffinitypod2` has no `required` rule — only\ntwo `preferred` terms — so the scheduler simply ranks the one available node (which\nmatches neither preference, scoring 0) and schedules the Pod anyway, reaching `Running`.\n","points":20,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = '1d2949c0-a5df-546e-9d12-fa20bb497bf6', updated_at = now()
WHERE id = '618e6f99-3c6f-59bb-8306-a2af680012b8' AND published_version_id IS NULL;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)
VALUES ('6dc582d6-8698-52e1-a43f-45df751a2bd2', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '52756a52-681c-5932-95e7-9e7f879beff3', 'Lab: Taint & Toleration', 'lab', 3, 30)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)
VALUES ('adc92324-910d-51f4-8ec4-017096717a93', '00000000-0000-0000-0000-000000000001', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '6dc582d6-8698-52e1-a43f-45df751a2bd2', 'module', 'Lab: Taint & Toleration', NULL, 'terminal', 'mindforge/lab-k8s:1.31', $script$mkdir -p /home/labuser/work
cat > /home/labuser/work/podtoleration.yaml <<'MFEOF'
apiVersion: v1
kind: Pod
metadata:
  name: toleratedpod1
  labels:
    env: test
spec:
  containers:
  - name: toleratedcontainer1
    image: nginx:latest
  tolerations:
  - key: "platform"
    operator: "Equal"
    value: "production"
    effect: "NoSchedule"
---
apiVersion: v1
kind: Pod
metadata:
  name: toleratedpod2
  labels:
    env: test
spec:
  containers:
  - name: toleratedcontainer2
    image: nginx
  tolerations:
  - key: "platform"
    operator: "Exists"
    effect: "NoSchedule"
MFEOF
#!/bin/bash
set -euo pipefail
kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
$script$, 60, 3, 10, true, false, NULL, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();

INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
('033968d9-b8a3-53a1-90b7-302d7b16eb9b', 'adc92324-910d-51f4-8ec4-017096717a93', 1, 'Taint the cluster node', $md$Find the name of the cluster's (single) node and apply a taint
`platform=production:NoSchedule` to it using `kubectl taint`.
$md$, $script$#!/bin/bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
test -n "$NODE" || exit 1
kubectl get node "$NODE" -o jsonpath='{.spec.taints[?(@.key=="platform")].value}' | grep -qx production || exit 1
kubectl get node "$NODE" -o jsonpath='{.spec.taints[?(@.key=="platform")].effect}' | grep -qx NoSchedule
$script$, 'Get the node name with `kubectl get nodes -o jsonpath=''{.items[0].metadata.name}''`, then
run `kubectl taint nodes <node> platform=production:NoSchedule`.
', 'A taint is applied to a Node and repels Pods unless they carry a matching toleration.
The `key=value:effect` syntax here creates taint `platform=production` with effect
`NoSchedule`, meaning the scheduler will not place new Pods on this node unless they
tolerate it.
', 15, false, true),
('e07ed27b-0d7a-5285-b922-5eb70ba5d7a6', 'adc92324-910d-51f4-8ec4-017096717a93', 2, 'Confirm an untolerated Pod cannot schedule on the tainted node', $md$Create a Pod named **notoleratedpod** (image `nginx`) with no tolerations, e.g.
`kubectl run notoleratedpod --image=nginx`. Because the node is tainted with
`platform=production:NoSchedule` and this Pod declares no matching toleration, it
should remain unscheduled.
$md$, $script$#!/bin/bash
kubectl get pod notoleratedpod >/dev/null 2>&1 || exit 1
NODENAME=$(kubectl get pod notoleratedpod -o jsonpath='{.spec.nodeName}' 2>/dev/null)
test -z "$NODENAME" || exit 1
kubectl get pod notoleratedpod -o jsonpath='{.status.phase}' | grep -qx Pending
$script$, 'Use `kubectl run notoleratedpod --image=nginx`, then check that
`kubectl get pod notoleratedpod -o jsonpath=''{.spec.nodeName}''` is empty and
`.status.phase` is `Pending`.
', 'With only one Node in the cluster and that Node tainted `NoSchedule`, the scheduler has
no eligible Node for a Pod lacking a toleration — it leaves the Pod `Pending` with
`nodeName` unset rather than binding it anywhere. This is the taint doing its job.
', 15, false, true),
('267fb157-6d7f-5658-92d5-b90fb1047d58', 'adc92324-910d-51f4-8ec4-017096717a93', 3, 'Create the tolerated Pods', $md$Apply `podtoleration.yaml` (already in your workdir) to create two Pods —
**toleratedpod1** and **toleratedpod2** — each carrying a toleration for the
`platform=production:NoSchedule` taint.
$md$, $script$#!/bin/bash
kubectl get pod toleratedpod1 >/dev/null 2>&1 || exit 1
kubectl get pod toleratedpod2 >/dev/null 2>&1 || exit 1
$script$, 'Use `kubectl apply -f podtoleration.yaml`.', '`podtoleration.yaml` declares two Pods sharing the `env=test` label, each with a
`tolerations` entry under `.spec` — this is the only extra field a Pod needs to become
eligible for scheduling onto a tainted Node.
', 15, false, true),
('e2fe9446-f6ed-5cfa-9fa3-c59e1a7ee3fa', 'adc92324-910d-51f4-8ec4-017096717a93', 4, 'Confirm toleratedpod1''s toleration exactly matches the taint', $md$Confirm that **toleratedpod1**'s toleration uses `operator: Equal` with `key: platform`,
`value: production`, and `effect: NoSchedule` — an exact match for the taint on the node.
$md$, $script$#!/bin/bash
kubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations[0].key}' | grep -qx platform || exit 1
kubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations[0].operator}' | grep -qx Equal || exit 1
kubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations[0].value}' | grep -qx production || exit 1
kubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations[0].effect}' | grep -qx NoSchedule
$script$, 'Inspect `kubectl get pod toleratedpod1 -o jsonpath=''{.spec.tolerations}''`.', 'The `Equal` operator requires `key`, `value`, and `effect` to match the taint exactly.
toleratedpod1''s toleration is written to match `platform=production:NoSchedule` field
for field — a looser toleration (missing `value`, or a different `effect`) would not
tolerate this specific taint.
', 10, false, false),
('a8c8036c-9878-5541-bb23-965acf0246e2', 'adc92324-910d-51f4-8ec4-017096717a93', 5, 'Confirm toleratedpod2''s toleration uses the Exists operator', $md$Confirm that **toleratedpod2**'s toleration uses `operator: Exists` with `key: platform`
and `effect: NoSchedule` — tolerating any taint value on that key, not just `production`.
$md$, $script$#!/bin/bash
kubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations[0].key}' | grep -qx platform || exit 1
kubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations[0].operator}' | grep -qx Exists || exit 1
kubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations[0].effect}' | grep -qx NoSchedule || exit 1
VALUE=$(kubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations[0].value}' 2>/dev/null)
test -z "$VALUE"
$script$, 'Inspect `kubectl get pod toleratedpod2 -o jsonpath=''{.spec.tolerations}''`.', 'The `Exists` operator only checks that the `key` (and, if set, `effect`) is present on
the taint — it ignores `value` entirely, which is why `podtoleration.yaml` omits `value`
for toleratedpod2. This toleration matches `platform=<anything>:NoSchedule`.
', 10, false, false),
('6c4ae8b2-3170-57ab-9da1-a6bd97ed92db', 'adc92324-910d-51f4-8ec4-017096717a93', 6, 'Confirm both tolerated Pods scheduled successfully despite the taint', $md$Confirm that **toleratedpod1** and **toleratedpod2** were both bound to the tainted node
(`.spec.nodeName` set) and reached phase `Running`, proving their tolerations let the
scheduler place them despite the `platform=production:NoSchedule` taint.
$md$, $script$#!/bin/bash
for POD in toleratedpod1 toleratedpod2; do
  NODENAME=$(kubectl get pod "$POD" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
  test -n "$NODENAME" || exit 1
  kubectl get pod "$POD" -o jsonpath='{.status.phase}' | grep -qx Running || exit 1
done
$script$, 'Check `kubectl get pod toleratedpod1 toleratedpod2 -o wide` for the `NODE` and `STATUS`
columns.
', 'A toleration doesn''t attract a Pod to a tainted Node — it only removes the repulsion,
letting the scheduler consider that Node like any other. Here it''s the only Node
available, so both tolerated Pods land on it and reach `Running`, in contrast to
notoleratedpod''s `Pending` state.
', 15, false, false)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;

INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES ('18637ca0-9a1d-534a-b3f6-1e2a9243075e', 'adc92324-910d-51f4-8ec4-017096717a93', 1, $json$[{"id":"033968d9-b8a3-53a1-90b7-302d7b16eb9b","lab_id":"adc92324-910d-51f4-8ec4-017096717a93","position":1,"title":"Taint the cluster node","description":"Find the name of the cluster's (single) node and apply a taint\n`platform=production:NoSchedule` to it using `kubectl taint`.\n","verification_script":"#!/bin/bash\nNODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')\ntest -n \"$NODE\" || exit 1\nkubectl get node \"$NODE\" -o jsonpath='{.spec.taints[?(@.key==\"platform\")].value}' | grep -qx production || exit 1\nkubectl get node \"$NODE\" -o jsonpath='{.spec.taints[?(@.key==\"platform\")].effect}' | grep -qx NoSchedule\n","hint_context":"Get the node name with `kubectl get nodes -o jsonpath='{.items[0].metadata.name}'`, then\nrun `kubectl taint nodes \u003cnode\u003e platform=production:NoSchedule`.\n","explanation_context":"A taint is applied to a Node and repels Pods unless they carry a matching toleration.\nThe `key=value:effect` syntax here creates taint `platform=production` with effect\n`NoSchedule`, meaning the scheduler will not place new Pods on this node unless they\ntolerate it.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"e07ed27b-0d7a-5285-b922-5eb70ba5d7a6","lab_id":"adc92324-910d-51f4-8ec4-017096717a93","position":2,"title":"Confirm an untolerated Pod cannot schedule on the tainted node","description":"Create a Pod named **notoleratedpod** (image `nginx`) with no tolerations, e.g.\n`kubectl run notoleratedpod --image=nginx`. Because the node is tainted with\n`platform=production:NoSchedule` and this Pod declares no matching toleration, it\nshould remain unscheduled.\n","verification_script":"#!/bin/bash\nkubectl get pod notoleratedpod \u003e/dev/null 2\u003e\u00261 || exit 1\nNODENAME=$(kubectl get pod notoleratedpod -o jsonpath='{.spec.nodeName}' 2\u003e/dev/null)\ntest -z \"$NODENAME\" || exit 1\nkubectl get pod notoleratedpod -o jsonpath='{.status.phase}' | grep -qx Pending\n","hint_context":"Use `kubectl run notoleratedpod --image=nginx`, then check that\n`kubectl get pod notoleratedpod -o jsonpath='{.spec.nodeName}'` is empty and\n`.status.phase` is `Pending`.\n","explanation_context":"With only one Node in the cluster and that Node tainted `NoSchedule`, the scheduler has\nno eligible Node for a Pod lacking a toleration — it leaves the Pod `Pending` with\n`nodeName` unset rather than binding it anywhere. This is the taint doing its job.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"267fb157-6d7f-5658-92d5-b90fb1047d58","lab_id":"adc92324-910d-51f4-8ec4-017096717a93","position":3,"title":"Create the tolerated Pods","description":"Apply `podtoleration.yaml` (already in your workdir) to create two Pods —\n**toleratedpod1** and **toleratedpod2** — each carrying a toleration for the\n`platform=production:NoSchedule` taint.\n","verification_script":"#!/bin/bash\nkubectl get pod toleratedpod1 \u003e/dev/null 2\u003e\u00261 || exit 1\nkubectl get pod toleratedpod2 \u003e/dev/null 2\u003e\u00261 || exit 1\n","hint_context":"Use `kubectl apply -f podtoleration.yaml`.","explanation_context":"`podtoleration.yaml` declares two Pods sharing the `env=test` label, each with a\n`tolerations` entry under `.spec` — this is the only extra field a Pod needs to become\neligible for scheduling onto a tainted Node.\n","points":15,"is_optional":false,"is_stateful":true},{"id":"e2fe9446-f6ed-5cfa-9fa3-c59e1a7ee3fa","lab_id":"adc92324-910d-51f4-8ec4-017096717a93","position":4,"title":"Confirm toleratedpod1's toleration exactly matches the taint","description":"Confirm that **toleratedpod1**'s toleration uses `operator: Equal` with `key: platform`,\n`value: production`, and `effect: NoSchedule` — an exact match for the taint on the node.\n","verification_script":"#!/bin/bash\nkubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations[0].key}' | grep -qx platform || exit 1\nkubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations[0].operator}' | grep -qx Equal || exit 1\nkubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations[0].value}' | grep -qx production || exit 1\nkubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations[0].effect}' | grep -qx NoSchedule\n","hint_context":"Inspect `kubectl get pod toleratedpod1 -o jsonpath='{.spec.tolerations}'`.","explanation_context":"The `Equal` operator requires `key`, `value`, and `effect` to match the taint exactly.\ntoleratedpod1's toleration is written to match `platform=production:NoSchedule` field\nfor field — a looser toleration (missing `value`, or a different `effect`) would not\ntolerate this specific taint.\n","points":10,"is_optional":false,"is_stateful":false},{"id":"a8c8036c-9878-5541-bb23-965acf0246e2","lab_id":"adc92324-910d-51f4-8ec4-017096717a93","position":5,"title":"Confirm toleratedpod2's toleration uses the Exists operator","description":"Confirm that **toleratedpod2**'s toleration uses `operator: Exists` with `key: platform`\nand `effect: NoSchedule` — tolerating any taint value on that key, not just `production`.\n","verification_script":"#!/bin/bash\nkubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations[0].key}' | grep -qx platform || exit 1\nkubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations[0].operator}' | grep -qx Exists || exit 1\nkubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations[0].effect}' | grep -qx NoSchedule || exit 1\nVALUE=$(kubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations[0].value}' 2\u003e/dev/null)\ntest -z \"$VALUE\"\n","hint_context":"Inspect `kubectl get pod toleratedpod2 -o jsonpath='{.spec.tolerations}'`.","explanation_context":"The `Exists` operator only checks that the `key` (and, if set, `effect`) is present on\nthe taint — it ignores `value` entirely, which is why `podtoleration.yaml` omits `value`\nfor toleratedpod2. This toleration matches `platform=\u003canything\u003e:NoSchedule`.\n","points":10,"is_optional":false,"is_stateful":false},{"id":"6c4ae8b2-3170-57ab-9da1-a6bd97ed92db","lab_id":"adc92324-910d-51f4-8ec4-017096717a93","position":6,"title":"Confirm both tolerated Pods scheduled successfully despite the taint","description":"Confirm that **toleratedpod1** and **toleratedpod2** were both bound to the tainted node\n(`.spec.nodeName` set) and reached phase `Running`, proving their tolerations let the\nscheduler place them despite the `platform=production:NoSchedule` taint.\n","verification_script":"#!/bin/bash\nfor POD in toleratedpod1 toleratedpod2; do\n  NODENAME=$(kubectl get pod \"$POD\" -o jsonpath='{.spec.nodeName}' 2\u003e/dev/null)\n  test -n \"$NODENAME\" || exit 1\n  kubectl get pod \"$POD\" -o jsonpath='{.status.phase}' | grep -qx Running || exit 1\ndone\n","hint_context":"Check `kubectl get pod toleratedpod1 toleratedpod2 -o wide` for the `NODE` and `STATUS`\ncolumns.\n","explanation_context":"A toleration doesn't attract a Pod to a tainted Node — it only removes the repulsion,\nletting the scheduler consider that Node like any other. Here it's the only Node\navailable, so both tolerated Pods land on it and reach `Running`, in contrast to\nnotoleratedpod's `Pending` state.\n","points":15,"is_optional":false,"is_stateful":false}]$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;

UPDATE lab_definitions
SET is_published = true, published_version_id = '18637ca0-9a1d-534a-b3f6-1e2a9243075e', updated_at = now()
WHERE id = 'adc92324-910d-51f4-8ec4-017096717a93' AND published_version_id IS NULL;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b9747857-d195-5477-aac3-67e7241b0bac', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the lesson''s liveness-exec Pod, the container runs `touch /tmp/healthy; sl...', 'intermediate', 2, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9819dea7-a4c6-5546-befd-52076472867f', 'b9747857-d195-5477-aac3-67e7241b0bac', 1, $json${"prompt":"In the lesson's liveness-exec Pod, the container runs `touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600`, and its livenessProbe runs `cat /tmp/healthy` every 5 seconds after an initial 5 second delay. What happens roughly 30+ seconds after the container starts?","multiple":false,"options":[{"id":"a","text":"Nothing happens; the probe only runs once at container startup","is_correct":false},{"id":"b","text":"The probe starts failing because the file no longer exists, and kubelet restarts the container","is_correct":true},{"id":"c","text":"The Pod is immediately deleted by the scheduler","is_correct":false},{"id":"d","text":"The probe passes forever because the file existed at some point during the container's life","is_correct":false}],"explanation":"Once /tmp/healthy is removed at around 30 seconds, each subsequent `cat /tmp/healthy`\nliveness check (run every periodSeconds: 5) returns a non-zero exit code, so the probe\nreports failure. Kubelet responds by restarting the container — this is exactly what a\nliveness probe is for: detecting a stuck or unhealthy process and recovering from it.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c69b273d-100c-5a0b-8f46-f0ae653b2a97', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the lesson''s node affinity lab, before any node is labelled app=production...', 'intermediate', 3, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('90e0dca9-963f-5044-9bd0-40cedb8e5056', 'c69b273d-100c-5a0b-8f46-f0ae653b2a97', 1, $json${"prompt":"In the lesson's node affinity lab, before any node is labelled app=production, nodeaffinitypod1 (which uses requiredDuringSchedulingIgnoredDuringExecution for the app=production label) and nodeaffinitypod2 (which uses preferredDuringSchedulingIgnoredDuringExecution for the same label) are both created. What is the observed result?","multiple":false,"options":[{"id":"a","text":"Both pods start running immediately on any available node","is_correct":false},{"id":"b","text":"nodeaffinitypod1 stays Pending until a node is labelled app=production, while nodeaffinitypod2 starts running immediately anyway","is_correct":true},{"id":"c","text":"Both pods stay Pending forever because no node has the app=production label","is_correct":false},{"id":"d","text":"nodeaffinitypod2 stays Pending while nodeaffinitypod1 runs immediately, the reverse of what actually happens","is_correct":false}],"explanation":"requiredDuringSchedulingIgnoredDuringExecution is a hard requirement — the pod will not\nbe scheduled until a matching node exists, so nodeaffinitypod1 stays Pending.\npreferredDuringSchedulingIgnoredDuringExecution is only a soft preference — the\nscheduler tries to honor it but still runs the pod anywhere if no matching node is\nfound, so nodeaffinitypod2 starts immediately. Once the node is labelled\napp=production, the required pod also starts running.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('368ee26f-aec5-56c5-984f-c9a32e9313eb', '00000000-0000-0000-0000-000000000001', 'coding', 'You are given a node''s taint and a Pod''s list of tolerations, and must decide...', 'intermediate', 5, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('55e7f6f4-f6bc-5183-850b-ca4521bd4f15', '368ee26f-aec5-56c5-984f-c9a32e9313eb', 1, $json${"prompt":"You are given a node's taint and a Pod's list of tolerations, and must decide whether\nthe Pod can be scheduled on the node.\n\n**Input:**\n- Line 1: the taint in the form `KEY=VALUE:EFFECT` (e.g. `app=production:NoSchedule`)\n- Line 2: an integer N, the number of tolerations the Pod has\n- Next N lines: each toleration in the form `KEY=VALUE`\n\nPrint `SCHEDULED` if one of the Pod's tolerations matches the taint's key and value.\nOtherwise print `PENDING`.\n\n**Example:**\n```\napp=production:NoSchedule\n2\nenv=test\napp=production\n```\nOutput: `SCHEDULED`\n","languages":["python","javascript"],"starter_code":{"javascript":"const lines = require('fs').readFileSync(0, 'utf8').trim().split('\\n');\nconst [keyValue] = lines[0].split(':');\nconst [key, value] = keyValue.split('=');\nconst n = parseInt(lines[1]);\nlet scheduled = false;\nfor (let i = 2; i \u003c 2 + n; i++) {\n  const [tkey, tvalue] = lines[i].trim().split('=');\n  if (tkey === key \u0026\u0026 tvalue === value) scheduled = true;\n}\nconsole.log(scheduled ? 'SCHEDULED' : 'PENDING');\n","python":"import sys\nlines = sys.stdin.read().split('\\n')\nkey_value, effect = lines[0].split(':')\nkey, value = key_value.split('=')\nn = int(lines[1])\nscheduled = False\nfor i in range(2, 2 + n):\n    tkey, tvalue = lines[i].split('=')\n    if tkey == key and tvalue == value:\n        scheduled = True\nprint('SCHEDULED' if scheduled else 'PENDING')\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"app=production:NoSchedule\n2\nenv=test\napp=production\n","expected":"SCHEDULED","hidden":false,"weight":1},{"id":"t2","stdin":"platform=production:NoSchedule\n1\napp=production\n","expected":"PENDING","hidden":true,"weight":1},{"id":"t3","stdin":"version=new:NoExecute\n1\nversion=new\n","expected":"SCHEDULED","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('32bb1357-1742-5b32-b579-7eaab7d3a64b', '00000000-0000-0000-0000-000000000001', 'Quiz: Health & Scheduling', 'k8s-scheduling-quiz', 'Quiz covering Health & Scheduling.', 'mixed', 'published', 'module', '6aaf7df2-aa2a-5abc-99b4-63d92491ceca', 15, 60, 5, 10, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('5d4e0e37-1cb6-50cc-9632-325170d78cc0', '32bb1357-1742-5b32-b579-7eaab7d3a64b', 'b9747857-d195-5477-aac3-67e7241b0bac', '9819dea7-a4c6-5546-befd-52076472867f', 0, 2),
('bd45d1f2-57c3-5288-a83e-05ae4a6bfd3d', '32bb1357-1742-5b32-b579-7eaab7d3a64b', 'c69b273d-100c-5a0b-8f46-f0ae653b2a97', '90e0dca9-963f-5044-9bd0-40cedb8e5056', 1, 3),
('49eee541-c9e2-5d11-b72f-a6e1446316cc', '32bb1357-1742-5b32-b579-7eaab7d3a64b', '368ee26f-aec5-56c5-984f-c9a32e9313eb', '55e7f6f4-f6bc-5183-850b-ca4521bd4f15', 2, 5)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('6aaf7df2-aa2a-5abc-99b4-63d92491ceca', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '52756a52-681c-5932-95e7-9e7f879beff3', 'Quiz: Health & Scheduling', 'assessment', 4, 15, '32bb1357-1742-5b32-b579-7eaab7d3a64b')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Cluster Setup & Operations
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('a6a3c179-127f-5a21-b823-1ddb520e36eb', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Cluster Setup & Operations', 7)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes)
VALUES ('2c2863cc-1d25-5e1c-8281-0616c84947ec', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'a6a3c179-127f-5a21-b823-1ddb520e36eb', 'Cluster Setup & Operations', 'notes', 0, $md$
## K8s Kubeadm Cluster Setup

## LAB: K8s Cluster Setup with Kubeadm and Containerd 

This scenario shows how to create K8s cluster on virtual PC (multipass, kubeadm, containerd)

**Easy way to create K8s Cluster with Ubuntu (Control-Plane, Workers) and Windows Servers:**

- Ubuntu 20.04 Installation Files (updated: K8s 1.26.2, calico 3.25.0, containerd 1.6.10) without using Corporate Proxy:
  - https://github.com/omerbsezer/Fast-Kubernetes/blob/main/create_real_cluster/ubuntu20.04-kubeadm1.26.2-calico3.25.0-containerd1.6.10/install.sh
  - https://github.com/omerbsezer/Fast-Kubernetes/blob/main/create_real_cluster/ubuntu20.04-kubeadm1.26.2-calico3.25.0-containerd1.6.10/master.sh
- Ubuntu 24.04 Installation Files (updated: K8s 1.32.0, calico 3.29.1, containerd 1.7.24) without using Corporate Proxy:
  - https://github.com/omerbsezer/Fast-Kubernetes/blob/main/create_real_cluster/ubuntu24.04-kubeadm1.32.0-calico3.29.1-containerd1.7.24/install-ubuntu24.04-k8s1.32.sh
  - https://github.com/omerbsezer/Fast-Kubernetes/blob/main/create_real_cluster/ubuntu24.04-kubeadm1.32.0-calico3.29.1-containerd1.7.24/master-ubuntu24.04-k8s1.32.sh
- Windows 2019 Server Installation Files (K8s 1.23.5, calico 3.25.0, docker as container runtime) without using Corporate Proxy:
  - https://github.com/omerbsezer/Fast-Kubernetes/blob/main/create_real_cluster/win2019-kubeadm1.26.2-calico3.25.0-docker/install1.ps1
  - https://github.com/omerbsezer/Fast-Kubernetes/blob/main/create_real_cluster/win2019-kubeadm1.26.2-calico3.25.0-docker/install2.ps1
  - https://github.com/omerbsezer/Fast-Kubernetes/blob/main/create_real_cluster/win2019-kubeadm1.26.2-calico3.25.0-docker/install-docker-ce.ps1
- Windows 2022 Server Installation Files (K8s 1.32.0, calico 3.29.1, containerd 1.7.24) without using Corporate Proxy:
  - https://github.com/omerbsezer/Fast-Kubernetes/blob/main/create_real_cluster/win2022-kubeadm1.32.0-calico3.29.1-containerd1.7.24/install1.ps1
  - https://github.com/omerbsezer/Fast-Kubernetes/blob/main/create_real_cluster/win2022-kubeadm1.32.0-calico3.29.1-containerd1.7.24/install2.ps1

**IMPORTANT:** 
- If your cluster is behind the corporate proxy, you should add proxy settings on **Environment Variables, Docker Config, Containerd Config**.
- Links in the script files might change in time (e.g. Calico updated their links)
- Important Notes from K8s:
  - K8s on Windows: https://kubernetes.io/docs/concepts/windows/intro/ 
  - Supported Versions: https://kubernetes.io/docs/concepts/windows/intro/#windows-os-version-support

### Table of Contents
- [Creating Cluster With Kubeadm, Containerd](#creating)
  - [Multipass Installation - Creating VM](#creatingvm)
  - [IP-Tables Bridged Traffic Configuration](#ip-tables)
  - [Install Containerd](#installcontainerd)
  - [Install KubeAdm](#installkubeadm)
  - [Install Kubernetes Cluster](#installkubernetes)
  - [Install Kubernetes Network Infrastructure](#network)
  - [(Optional) If you need Windows Node: Creating Windows Node](#creatingWindows)
- [Joining New K8s Worker Node to Existing Cluster](#joining)
  - [Brute-Force Method](#bruteforce)
  - [Easy Way to Get Join Command](#easy)
- [IP address changes in Kubernetes Master Node](#master_ip_changed)
- [Removing the Worker Node from Cluster](#removing)
- [Installing Docker on Existing Cluster & Starting of Running Local Registry for Storing Local Image](#docker_registry)
  - [Installing Docker](#installingdocker)
  - [Running Docker Registry](#dockerregistry)
- [Pulling Image from Docker Local Registry and Configure Containerd](#local_image)
- [NFS Server Connection for Persistent Volume](#nfs_server)

## 1. Creating Cluster With Kubeadm, Containerd <a name="creating"></a>

#### 1.1 Multipass Installation - Creating VM <a name="creatingvm"></a>

- "Multipass is a mini-cloud on your workstation using native hypervisors of all the supported plaforms (Windows, macOS and Linux)"
- Fast to install and to use.
- **Link:** https://multipass.run/

``` 
# creating master, worker1
# -c => cpu, -m => memory, -d => disk space
multipass launch --name master -c 2 -m 2G -d 10G   
multipass launch --name worker1 -c 2 -m 2G -d 10G
``` 

![image](https://user-images.githubusercontent.com/10358317/156150337-2f4b3ac9-df42-4567-a848-6869362a3001.png)

``` 
# get shell on master 
multipass shell master
# get shell on worker1
multipass shell worker1
``` 

![image](https://user-images.githubusercontent.com/10358317/156150843-db217ba0-8fff-4a77-9f3d-09f9f71314df.png)

#### 1.2 IP-Tables Bridged Traffic Configuration <a name="ip-tables"></a>

- Run on ALL nodes: 
``` 
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
``` 

- Run on ALL nodes: 
``` 
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
```

![image](https://user-images.githubusercontent.com/10358317/156151342-8e72ed0f-701e-41ff-88b9-e2bdaf9c51e5.png)

![image](https://user-images.githubusercontent.com/10358317/156151447-e4685bef-6437-46ba-9460-2cdd0f1dbe12.png)

- Run on ALL nodes: 
``` 
sudo sysctl --system
```

![image](https://user-images.githubusercontent.com/10358317/156158062-01f3edc8-df31-4a83-9dcc-d173c3cc921b.png)

##### This part is optional:

- Close swaps on the OS. Because it is required if you run on directly OS (on-premise)(instead of running on VM)
```
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

- If you install your cluster behind the proxy, you should define http_proxy, https_proxy, ftp_proxy and no_proxy environment variables on /etc/environment.
- You should add ::6443 and Master Node IP.
```
export no_proxy="192.168.*.*, ::6443, <yourMasterIP>:6443, 172.24.*.*, 172.25.*.*, 10.*.*.*, localhost, 127.0.0.1"
```

#### 1.3 Install Containerd <a name="installcontainerd"></a>
- Run on ALL nodes: 
``` 
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
```

- Run on ALL nodes: 
``` 
sudo modprobe overlay
sudo modprobe br_netfilter
```

- Run on ALL nodes: 
``` 
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
```

- Run on ALL nodes: 
``` 
sudo sysctl --system
```

![image](https://user-images.githubusercontent.com/10358317/156159159-1cb24ead-4cdb-4912-8382-c12a23d9271c.png)

![image](https://user-images.githubusercontent.com/10358317/156159208-dfc96be6-62b6-4b6d-8e12-1a48541e89cb.png)

- Run on ALL nodes: 
``` 
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install containerd -y
sudo mkdir -p /etc/containerd
sudo su -
containerd config default | tee /etc/containerd/config.toml
exit
sudo systemctl restart containerd
```

![image](https://user-images.githubusercontent.com/10358317/156160352-035d8bf2-79c5-43c0-a6d6-74b6211993a7.png)

![image](https://user-images.githubusercontent.com/10358317/156160304-2cedfc2f-a436-44a3-8d60-a3af2bf3436c.png)

![image](https://user-images.githubusercontent.com/10358317/156160237-582b6fb3-6289-4e8e-a3f9-f4f9c5a15b91.png)

![image](https://user-images.githubusercontent.com/10358317/156160159-10df522b-f726-4a5a-93e6-19b4bb85f10a.png)

![image](https://user-images.githubusercontent.com/10358317/156160102-ce0437a8-1054-46ab-b79d-47527d4462e3.png)

#### 1.4 Install KubeAdm <a name="installkubeadm"></a>
- Run on ALL nodes: 
``` 
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

![image](https://user-images.githubusercontent.com/10358317/156160934-11c45c68-a5e5-46fd-bde7-96301277b906.png)

![image](https://user-images.githubusercontent.com/10358317/156160979-f4f79703-9e60-4b59-b8fe-5fbd14969622.png)

![image](https://user-images.githubusercontent.com/10358317/156161071-59d5f19a-ca62-48a2-97db-73de53e2d29d.png)

![image](https://user-images.githubusercontent.com/10358317/156161142-e7ba1322-9cf8-4edf-9018-082fa5b2f76a.png)


#### 1.5 Install Kubernetes Cluster <a name="installkubernetes"></a>

- Run on ALL nodes: 
``` 
sudo kubeadm config images pull
```

![image](https://user-images.githubusercontent.com/10358317/156161542-7da94e9a-f124-4e05-896d-0c9fb2208729.png)

- From worker1, ping the master to learn IP of master.
``` 
ping master
```
![image](https://user-images.githubusercontent.com/10358317/156161683-63d2d56a-e5b1-4826-9665-e872a333d520.png)

- Run on Master: 
``` 
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=<ip> --control-plane-endpoint=<ip>
# sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=172.31.45.74 --control-plane-endpoint=172.31.45.74
```

![image](https://user-images.githubusercontent.com/10358317/156162236-15fa0c78-dccc-4bfb-8c0b-179b86a8ed31.png)

- After kubeadm init command, master node responses back the followings:
 
![image](https://user-images.githubusercontent.com/10358317/156163029-e31ea507-9912-4377-a93d-93863c37039a.png)

- On the Master node run:

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

![image](https://user-images.githubusercontent.com/10358317/156163241-66fed5a3-593e-4efd-8f12-2d024ef7554c.png)

- On the worker node, run to join cluster (tokens are different in your case, please look at the kubeadm init respond):

```
sudo kubeadm join 172.31.45.74:6443 --token w7nntd.7t6qg4cd418wzkup \
        --discovery-token-ca-cert-hash sha256:1f03886e5a28fb9716e01794b4a01144f362bf431220f15ca98bed2f5a44e91b
```

- If it is required to create another master node, copy the control plane line (tokens are different in your case, please look at the kubeadm init respond):

```
sudo kubeadm join 172.31.45.74:6443 --token w7nntd.7t6qg4cd418wzkup \
        --discovery-token-ca-cert-hash sha256:1f03886e5a28fb9716e01794b4a01144f362bf431220f15ca98bed2f5a44e91b \
        --control-plane
```

![image](https://user-images.githubusercontent.com/10358317/156163626-ae2baf3f-43e8-4747-8fdc-80738603adbe.png)

- On Master node: 

![image](https://user-images.githubusercontent.com/10358317/156163717-c9c771c1-a850-4706-80dd-7fa85b890c2a.png)


#### 1.6 Install Kubernetes Network Infrastructure <a name="network"></a>

- Calico is used for network plugin on K8s. Others (flannel, weave) could be also used. 
- Run only on Master, in our examples, we are using Calico instead of Flannel: 
  - Calico:
  ```
  kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
  kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml
  ```
  - Flannel:
  ```
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
  ```

![image](https://user-images.githubusercontent.com/10358317/156164127-d21ff5be-35d6-4ec6-a507-2ae0155031ac.png)

![image](https://user-images.githubusercontent.com/10358317/156164265-1d13bab5-6c55-4421-b7a8-e835d5d0ebfc.png)

- After running network implementation, nodes are now ready. Only Master node is used to get information about the cluster.

![image](https://user-images.githubusercontent.com/10358317/156164572-5525bda3-6ff5-49a2-9a2f-392a804b4da2.png)

![image](https://user-images.githubusercontent.com/10358317/156165250-f1647540-467a-445d-8381-dd320922a70d.png)

##### 1.6.1 If You have Windows Node to add your Cluster:

- Instead of running it as above, you should run Calico with this way, run on Master node:
```
# Download Calico CNI
curl https://docs.projectcalico.org/manifests/calico.yaml > calico.yaml
# Apply Calico CNI
kubectl apply -f ./calico.yaml
```

Run on the Master Node: 
```
# required to add windows node
sudo -i
cd /usr/local/bin/
curl -o calicoctl -O -L  "https://github.com/projectcalico/calicoctl/releases/download/v3.19.1/calicoctl" 
chmod +x calicoctl
exit  
        
# Disable "IPinIP":        
calicoctl get ipPool default-ipv4-ippool  -o yaml > ippool.yaml
nano ippool.yaml  # set ipipmode: Never
calicoctl apply -f ippool.yaml
    
kubectl get felixconfigurations.crd.projectcalico.org default  -o yaml -n kube-system > felixconfig.yaml
nano felixconfig.yaml #Set: "ipipEnabled: false"
kubectl apply -f felixconfig.yaml     

# This is required to prevent Linux nodes from borrowing IP addresses from Windows nodes:"
calicoctl ipam configure --strictaffinity=true
sudo reboot

kubectl cluster-info
kubectl get nodes -o wide
ssh <username>@<WindowsIP> 'mkdir c:\k'
scp -r $HOME/.kube/config <username>@<WindowsIP>:/k/        # send to Win PC from master node, while installing calico, it is required
```

- Ref: https://github.com/gary-RR/my_YouTube_Kuberenetes_Hybird/blob/main/setupcluster.sh

#### (Optional) If you need Windows Node: Creating Windows Node <a name="creatingWindows"></a>

- Kubernetes requires a minimum Windows-2019 Server (https://kubernetes.io/docs/setup/production-environment/windows/intro-windows-in-kubernetes/)
- Run-on the PowerShell with administration privilege on the Windows nodes:

```
New-NetFireWallRule -DisplayName "Allow All Traffic" -Direction OutBound -Action Allow  
New-NetFireWallRule -DisplayName "Allow All Traffic" -Direction InBound -Action Allow 

Install-WindowsFeature -Name containers    # install docker
Restart-Computer -Force 

.\install-docker-ce.ps1

Set-Service -Name docker -StartupType 'Automatic' 
 
#Install additional Windows networking components 

Install-WindowsFeature RemoteAccess 
Install-WindowsFeature RSAT-RemoteAccess-PowerShell 
Install-WindowsFeature Routing 
Restart-Computer -Force 
Install-RemoteAccess -VpnType RoutingOnly 
Set-Service -Name RemoteAccess -StartupType 'Automatic' 
start-service RemoteAccess 

# Install Calico
mkdir c:\k 
#Copy the Kubernetes kubeconfig file from the master node (default, Location $HOME/.kube/config), to c:\k\config. 

Invoke-WebRequest https://docs.projectcalico.org/scripts/install-calico-windows.ps1 -OutFile c:\install-calico-windows.ps1 

c:\install-calico-windows.ps1 -KubeVersion 1.23.5 
 
#Verify that the Calico services are running. 
Get-Service -Name CalicoNode 
Get-Service -Name CalicoFelix 

#Install and start kubelet/kube-proxy service. Execute following PowerShell script/commands. 
C:\CalicoWindows\kubernetes\install-kube-services.ps1 
Start-Service -Name kubelet 
Start-Service -Name kube-proxy 

#Copy kubectl.exe, kubeadm.etc to the folder below which is on the path:  
cp C:\k\*.exe C:\Users\<username>\AppData\Local\Microsoft\WindowsApps 
 
#Test Win node##################################### 
#List all cluster nodes 
kubectl get nodes -o wide     
 
[Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://<ProxyIP>:3128", [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://<ProxyIP>:3128", [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("NO_PROXY", "192.168.*.*, ::6443, <MasterNodeIP>:6443, 172.24.*.*, 172.25.*.*, 10.*.*.*, localhost, 127.0.0.1, 0.0.0.0/8", [EnvironmentVariableTarget]::Machine)
Restart-Service docker
```

- Create win-webserver.yaml file for testing of Win Node, run on the Windows2019, details:  https://kubernetes.io/docs/setup/production-environment/windows/user-guide-windows-containers/
- Ref: https://github.com/gary-RR/my_YouTube_Kuberenetes_Hybird/blob/main/Setting-ThingsUp-On-Windows-Server.sh

## 2. Joining New K8s Worker Node to Existing Cluster <a name="joining"></a>

### 2.1 Brute-Force Method <a name="bruteforce"></a>

- If we lose the token and token CA cert dash and API server address, wé need to learn them to join a new node into the cluster.
- We are adding new node to existing cluster above. We need to get join token, discovery token CA cert hash, API server advertise address. After getting info, we'll create join command for each nodes. 
- Run on Master to get certificate and token information:

```
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
kubeadm token list
kubectl cluster-info
```

![image](https://user-images.githubusercontent.com/10358317/156349584-9fe2f41e-4368-43ef-9674-c78512230938.png)

- In this example, token TTL has 3 hours left (normally, token expires in 24 hours). So we don't need to create new token.  
- If the token is expired, generate a new one with the command:

```
sudo kubeadm token create
kubeadm token list
```

- Create join command for worker nodes:

```
kubeadm join \
  <control-plane-host>:<control-plane-port> \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

- In our case, we run the following command on both workers (worker2, worker3):

```
sudo kubeadm join 172.31.32.27:6443 --token 39g7sx.v589tv38nxhus74k --discovery-token-ca-cert-hash sha256:1db5d45337803e35e438cdcdd9ff77449fef3272381ee43784626f19c873d356
```

![image](https://user-images.githubusercontent.com/10358317/156350767-b14335d0-1d63-4ab1-a939-6eb47fadac9d.png)

![image](https://user-images.githubusercontent.com/10358317/156350852-d1df7b93-13aa-462d-8cce-51f3b9b6e553.png)

### 2.2 Easy Way to Get Join Command <a name="easy"></a>
- Run on the master node:
```
kubeadm token create --print-join-command 
```
- Copy the join command above and paste it on **ALL worker nodes**.
- Then, we get nodes ready, run on master:

```
kubectl get nodes
```

![image](https://user-images.githubusercontent.com/10358317/156351061-7c1af34b-63cd-49dc-a8a1-74679c765516.png)

- Ref: https://computingforgeeks.com/join-new-kubernetes-worker-node-to-existing-cluster/

##  3. IP address changes in Kubernetes Master Node <a name="master_ip_changed"></a>
- After restarting Master Node, it could be possible that the IP of master node is updated. Your K8s cluster API's IP is still old IP of the node. So you should configure the K8s cluster with new IP.

- You cannot reach API when using kubectl commands:

![image](https://user-images.githubusercontent.com/10358317/156803085-e99717a4-da62-453f-97bb-fb86c09edaca.png)

- If you installed the docker for the docker registry, you can remove the exited containers:

```
sudo docker rm $(sudo docker ps -a -f status=exited -q)
```

#### On Master Node: 

```
sudo kubeadm reset
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
```

- After kubeadm reset, if there is an error that shows the some of the ports still using, please use following command to kill process, then run kubeadm init:

```
sudo netstat -lnp | grep <PortNumber>
sudo kill <PID>
```

![image](https://user-images.githubusercontent.com/10358317/156803554-21741c6e-74bb-4902-9130-bc835b91e76f.png)

![image](https://user-images.githubusercontent.com/10358317/156803646-f943be3e-158d-4f3d-9f26-fe06a8436439.png)

- It shows which command should be used to join cluster:

```
sudo kubeadm join 172.31.40.125:6443 --token 07vo3z.q2n2qz6bd07ipdnf \
        --discovery-token-ca-cert-hash sha256:46c7dcb092ca091e71ab39bd542e73b90b3f7bdf0c486202b857a678cd9879ba
```
![image](https://user-images.githubusercontent.com/10358317/156803877-89ac5a24-6dd6-40d0-8568-3c6b70acbd89.png)

![image](https://user-images.githubusercontent.com/10358317/156804162-cc8c3f2b-5d3f-407a-9ced-31322b6bb39b.png)


- Network Configuration with new IP:

```
kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml
```

![image](https://user-images.githubusercontent.com/10358317/156804328-c8068ef9-5a7d-4230-a4e9-56aa6a111da9.png)

#### On Worker Nodes: 

```
sudo kubeadm reset
sudo kubeadm join 172.31.40.125:6443 --token 07vo3z.q2n2qz6bd07ipdnf \
        --discovery-token-ca-cert-hash sha256:46c7dcb092ca091e71ab39bd542e73b90b3f7bdf0c486202b857a678cd9879ba
```

![image](https://user-images.githubusercontent.com/10358317/156805582-bb66e20b-5b81-49b5-995f-96023c943f3b.png)

![image](https://user-images.githubusercontent.com/10358317/156805882-e2e2144d-f3dc-4b87-81a8-a9f1c4827a5b.png)

- On Master Node:

- Worker1 is now joined the cluster.

```
kubectl get nodes
```

![image](https://user-images.githubusercontent.com/10358317/156805995-49e8a6f5-5293-46b8-9684-59f18d6f5ab2.png)

##  4. Removing the Worker Node from Cluster <a name="removing"></a>

- Run commands on Master Node to remove specific worker node:

```
kubectl get nodes
kubectl drain worker2
kubectl delete node worker2
```

![image](https://user-images.githubusercontent.com/10358317/157018826-8cbae29e-b5e4-4a6d-bf8e-72d3006ce33e.png)

- Run on the specific deleted node (worker2)

```
sudo kubeadm reset
```

![image](https://user-images.githubusercontent.com/10358317/157018963-422b1b72-667c-4375-b9ee-8035823396d7.png)

##  5. Installing Docker on Existing Cluster & Starting of Running Local Registry for Storing Local Image <a name="docker_registry"></a>

#### 5.1 Installing Docker <a name="installingdocker"></a>

- Run commands on Master Node to install docker on Master node:

```
 sudo apt-get update
 sudo apt-get install ca-certificates curl gnupg lsb-release
 curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
 echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
sudo docker run hello-world
```

**Goto for more information:** https://docs.docker.com/engine/install/ubuntu/

![image](https://user-images.githubusercontent.com/10358317/157026833-fcd829fd-a5dd-4701-b71a-89327445483d.png)

![image](https://user-images.githubusercontent.com/10358317/157027173-8be0d193-4ac9-4a82-ac3b-33fbd68ba42d.png)

![image](https://user-images.githubusercontent.com/10358317/157027863-787bf3cb-3e0c-4888-8de6-80e2145a383c.png)

![image](https://user-images.githubusercontent.com/10358317/157028189-2585365e-51e5-4dfa-9d60-5ac9d73c258a.png)

![image](https://user-images.githubusercontent.com/10358317/157028470-e09a783d-1413-4d87-bbaf-463741871a68.png)

- Copy and run on all nodes to change Docker's Cgroup:

```
cd /etc/docker
sudo touch daemon.json
sudo nano daemon.json
# in the file, paste:
{
"exec-opts": ["native.cgroupdriver=systemd"]
}
sudo systemctl restart docker
sudo docker image ls
kubectl get nodes
```

![image](https://user-images.githubusercontent.com/10358317/157424989-671ee3e8-b33c-4d7e-b0d6-ee1fd5685f70.png)

![image](https://user-images.githubusercontent.com/10358317/157425768-a8446317-3477-4719-9bf8-0014ef134335.png)

![image](https://user-images.githubusercontent.com/10358317/157425383-4d82e707-1a98-4dcd-b59e-1239121b5850.png)

- If your cluster is behind the proxy, configure PROXY settings of Docker (ref: add docker proxy: https://docs.docker.com/config/daemon/systemd/). Copy and run on all nodes:
```
sudo mkdir -p /etc/systemd/system/docker.service.d
cd /etc/systemd/system/docker.service.d/
sudo touch http-proxy.conf
sudo nano http-proxy.conf
# copy and paste in the file:
[Service]
Environment="HTTP_PROXY=http://<ProxyIP>:3128"
Environment="HTTPS_PROXY=http://<ProxyIP>:3128"
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl show --property=Environment docker
sudo docker run hello-world
```

- Use docker command without sudo:

```
sudo groupadd docker
sudo usermod -aG docker [non-root user]
# logout and login to enable it
```

#### 5.2 Running Docker Registry <a name="dockerregistry"></a>

- Run on Master to pull registry:

```
sudo docker image pull registry
```

- Run container using 'Registry' image: (-p: port binding [hostPort]:[containerPort], -d: detach mode (running background), -e: change environment variables status)
```
sudo docker container run -d -p 5000:5000 --restart always --name localregistry -e REGISTRY_STORAGE_DELETE_ENABLED=true registry
```

- Run registry container with binding mount (-v) and without getting error 500 (REGISTRY_VALIDATION_DISABLED=true):
```
sudo docker run -d -p 5000:5000 --restart=always --name registry -v /home/docker_registry:/var/lib/registry -e REGISTRY_STORAGE_DELETE_ENABLED=true -e REGISTRY_VALIDATION_DISABLED=true -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 registry
```

![image](https://user-images.githubusercontent.com/10358317/157030622-69ab3019-6cff-43ee-8a3d-fe277d7632b5.png)

![image](https://user-images.githubusercontent.com/10358317/157030738-be8eb8c3-0f87-4d39-969b-bd94cb8b0f9f.png)

- Open with browser or run curl command:
```
curl http://127.0.0.1:5000/v2/_catalog
```
![image](https://user-images.githubusercontent.com/10358317/157031139-edf0162d-d753-4d75-a39a-127583bb47fe.png)


##  6. Pulling Image from Docker Local Registry and Configure Containerd  <a name="local_image"></a>

- In this scenario, docker local registry already runs on the Master node (see [Section 5](#docker_registry))
- First add insecure-registry into /etc/docker/daemon.js on the **ALL Nodes**:

```
sudo nano /etc/docker/daemon.json
# copy insecure-registries and paste it
{
"exec-opts": ["native.cgroupdriver=systemd"],
"insecure-registries":["192.168.219.64:5000"]
}
sudo systemctl restart docker.service
```

![image](https://user-images.githubusercontent.com/10358317/157729358-cf496d8f-24f9-4bff-b263-7a196efb035c.png)

- Pull image from DockerHub, label with new tag and push the local registry on master node:

```
sudo docker image pull nginx:latest
ifconfig                           # to get master IP
sudo docker image tag nginx:latest 192.168.219.64:5000/nginx:latest
sudo docker image push 192.168.219.64:5000/nginx:latest
curl http://192.168.219.64:5000/v2/_catalog
sudo docker image pull 192.168.219.64:5000/nginx:latest
```

- Create docker config and get authentication username and pass in base64 coded:

```
sudo docker login       # this creates /root/.docker/config
sudo cat /root/.docker/config.json | base64 -w0   # copy the base64 encoded key
```

- Create my-secret.yaml and paste the base64 encoded key: 

```
apiVersion: v1
kind: Secret
metadata:
  name: registrypullsecret
data:
  .dockerconfigjson: <base-64-encoded-json-here>
type: kubernetes.io/dockerconfigjson
```

- Create secret. Kubelet uses this secret to pull image:

```
kubectl create -f my-secret.yaml && kubectl get secrets
```

- Create nginx_pod.yaml. Image name shows where the image is pulled from. In addition, "imagePullSecrets" should be defined, which secret should be used for pulling image for local docker registry.  
 
```
apiVersion: v1
kind: Pod
metadata:
  name: my-private-pod
spec:
  containers:
    - name: private
      image: 192.168.219.64:5000/nginx:latest
  imagePullSecrets:
    - name: registrypullsecret
```

![image](https://user-images.githubusercontent.com/10358317/157726621-858e57b1-4e4c-48dc-9900-c5fe3024d5ae.png)

- On the **ALL Nodes**, registry IP and the port should be defined:

```
sudo nano /etc/containerd/config.toml   # if containerd is using as runtime. If this was Docker, on /etc/docker/daemon.js add insecure-registries like master 
# copy and paste (our IP: 192.168.219.64, change it with your IP):
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."192.168.219.64:5000"]
          endpoint = ["http://192.168.219.64:5000"]
    [plugins."io.containerd.grpc.v1.cri".registry.configs]
      [plugins."io.containerd.grpc.v1.cri".registry.configs."192.168.219.64:5000".tls]
        insecure_skip_verify = true
# restart containerd.service
sudo systemctl restart containerd.service
```

![image](https://user-images.githubusercontent.com/10358317/157726335-fc7091da-2300-4f4e-a9da-6416a6810329.png)


- If registry IP and the port is not defined, you will get this error:  "http: server gave HTTP response to HTTPS client.
- If pod's status is ImagePullBackOff (Error), it can be inspected with describe command:

```
kubectl describe pods my-private-pod
```

![image](https://user-images.githubusercontent.com/10358317/157730392-09a1a2b6-0eec-4f68-97e9-066d00ea541d.png)


- On Master:

```
kubectl apply -f nginx_pod.yaml
kubectl get pods -o wide
```
![image](https://user-images.githubusercontent.com/10358317/157725926-90b57357-cf8f-4d27-a91c-01a7d0eb047c.png)

## 7. NFS Server Connection for Persistent Volume <a name="nfs_server"></a>

- If it is required NFS Server, you can create NFS Server 
  - if you have Windows 2019 Server: https://youtu.be/_x3vg25i7GQ
  - if you have Ubuntu: https://rudimartinsen.com/2022/01/05/nginx-nfs-kubernetes/
  
- Run on ALL Nodes to reach NFS Server:

```
sudo apt install nfs-common
sudo apt install cifs-utils
sudo mkdir /data                                           # create /data directory under root and mount it to NFS
sudo mount -t nfs <NFSServerIP>:/share /data/              # /share directory is created while creating NFS server
sudo chmod 777 /data                                       # give permissions to reach mounted shared area
```

### Reference
 
 - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
 - https://github.com/aytitech/k8sfundamentals/tree/main/setup
 - https://multipass.run/
 - https://computingforgeeks.com/join-new-kubernetes-worker-node-to-existing-cluster/
 - https://docs.docker.com/engine/install/ubuntu/
 - https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
 - https://stackoverflow.com/questions/32726923/pulling-images-from-private-registry-in-kubernetes
 - https://stackoverflow.com/questions/65681045/adding-insecure-registry-in-containerd


## K8s Kubeadm Cluster Docker

## LAB: K8s Cluster Setup with Kubeadm and Docker

- This scenario shows how to create K8s cluster on virtual PC (multipass, kubeadm, docker) 

### Table of Contents
- [Creating Cluster With Kubeadm, Docker](#creating)
- [IP address changes in Kubernetes Master Node](#master_ip_changed)


## 1. Creating Cluster With Kubeadm, Docker <a name="creating"></a>

#### 1.1 Multipass Installation - Creating VM

- "Multipass is a mini-cloud on your workstation using native hypervisors of all the supported plaforms (Windows, macOS and Linux)"
- Multipass is lightweight, fast, easy to use Ubuntu VM  (on demand for any workstation)
- Fast to install and to use.
- **Link:** https://multipass.run/

``` 
# creating VM
multipass launch --name k8s-controller --cpus 2 --mem 2048M --disk 10G 
multipass launch --name k8s-node1 --cpus 2 --mem 1024M --disk 7G
multipass launch --name k8s-node2 --cpus 2 --mem 1024M --disk 7G
``` 

![image](https://user-images.githubusercontent.com/10358317/157879969-a049706d-e8b8-4096-97bb-dca4e9a9b87e.png)

``` 
# get shells on different terminals
multipass shell k8s-controller
multipass shell k8s-node1
multipass shell k8s-node2
multipass list
``` 

![image](https://user-images.githubusercontent.com/10358317/157880347-dead1390-692c-4725-8e37-89121a346d7e.png)

#### 1.2 Install Docker

- Run for all 3 nodes on different terminals:

``` 
sudo apt-get update
sudo apt-get install docker.io -y                # install Docker
sudo systemctl start docker                      # start and enable the Docker service
sudo systemctl enable docker
sudo usermod -aG docker $USER                    # add the current user to the docker group
newgrp docker                                    # make the system aware of the new group addition
```

#### 1.3 Install Kubeadm

- Run for all 3 nodes on different terminals:

```
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add              # add the repository key and the repository
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt-get install kubeadm kubelet kubectl -y                                               # install all of the necessary Kubernetes tools
```

- Run on new terminal:

```
multipass list
```

![image](https://user-images.githubusercontent.com/10358317/157883859-55497a48-3774-4f6c-bf8c-29cc8d591a82.png)

- Run on controller, add IPs of PCs:

```
sudo nano /etc/hosts
```

![image](https://user-images.githubusercontent.com/10358317/157883663-af21c3fb-bc19-4b37-9da1-112b1c974c84.png)

- Run for all 3 nodes on different terminals:

```
sudo swapoff -a         # turn off swap
```

- Create this file "daemon.json" in the directory "/etc/docker", docker change cgroup driver to systemd, run on 3 different machines:

```
cd /etc/docker
sudo touch daemon.json
sudo nano daemon.json
# copy and paste it on daemon.json
{
"exec-opts": ["native.cgroupdriver=systemd"]
}
sudo systemctl restart docker
```

- Run on the controller:

```
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
sudo kubectl get nodes
```

![image](https://user-images.githubusercontent.com/10358317/157886788-4a136836-924b-4938-bfdc-0a07e9c16163.png)

![image](https://user-images.githubusercontent.com/10358317/157887715-27661178-2a0b-4314-ae84-30598cfd5e68.png)

- Run on the nodes (node1, node2):

```
sudo kubeadm join 172.29.108.209:6443 --token ug13ec.cvi0jwi9xyf82b6f \
        --discovery-token-ca-cert-hash sha256:12d59142ccd0148d3f12a673b5c47a2f549cce6b7647963882acd90f9b0fbd28
```      

- Run "kubectl get nodes" on the controller, after deploying pod network, nodes will be ready.

![image](https://user-images.githubusercontent.com/10358317/157888135-5ad0e931-8a2d-4389-83c2-ec1d8d909c25.png)

- Run on Controller to deploy a pod network:
  - Flannel:
    ```
    sudo kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
    ```
  - Calico:
    ```
    kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
    kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml
    ```   
    
![image](https://user-images.githubusercontent.com/10358317/157889081-d9ee73ed-ebb3-4386-bbef-03113b199ef3.png)
    
- After testing more (restarting master, etc.), Containerd is more flexible and usable than Dockerd run time => [KubeAdm-Containerd Setup](https://github.com/omerbsezer/Fast-Kubernetes/blob/main/K8s-Kubeadm-Cluster-Setup.md), because every restart, /etc/hosts should be updated. However, updating of /etc/hosts is not required in the containerd. 

##  2. IP address changes in Kubernetes Master Node <a name="master_ip_changed"></a>
- After restarting Master Node, it could be possible that the IP of master node is updated. Your K8s cluster API's IP is still old IP of the node. So you should configure the K8s cluster with new IP.

- If you installed the docker for the docker registry, you can remove the exited containers:

```
sudo docker rm $(sudo docker ps -a -f status=exited -q)
```

#### On Master Node: 

- Run on controller, add IPs of PCs, after restarting IPs should be again updated:

```
sudo nano /etc/hosts
```

- Reset kubeadm and init new cluster:

```
sudo kubeadm reset
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
```

- It shows which command should be used to join cluster:

```
sudo kubeadm join 172.31.40.125:6443 --token 07vo3z.q2n2qz6bd07ipdnf \
        --discovery-token-ca-cert-hash sha256:46c7dcb092ca091e71ab39bd542e73b90b3f7bdf0c486202b857a678cd9879ba
```



- Network Configuratin with new IP:

```
kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml
```



### Reference
- https://thenewstack.io/deploy-a-kubernetes-desktop-cluster-with-ubuntu-multipass/


## K8s Enable Dashboard On Cluster

## LAB: Enable Dashboard on Cluster


### K8s Cluster (with Multipass VM)
- K8s cluster was created before:
   - **Goto:** [K8s Kubeadm Cluster Setup](https://github.com/omerbsezer/Fast-Kubernetes/blob/main/K8s-Kubeadm-Cluster-Setup.md)

### Enable Dashboard on Cluster

- To enable dashboard on cluster, apply yaml file (https://github.com/kubernetes/dashboard)
```
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml
Kubectl proxy
on browser: http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/
```

![image](https://user-images.githubusercontent.com/10358317/156365236-cda2797e-c786-41f4-b026-0a5779ebba5a.png)

- Now we should find to token to enter dashboard as admin user.

```
kubectl create serviceaccount dashboard-admin-sa
kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin-sa
kubectl get secrets
kubectl describe secret dashboard-admin-sa-token-m84l5             # token name change, pls find it using "kubectl get secrets"
```

![image](https://user-images.githubusercontent.com/10358317/156364438-8b3a192d-b36c-4b8d-8aaf-6387e707ac08.png)

![image](https://user-images.githubusercontent.com/10358317/156364553-e917899b-b918-4cdc-b87f-5f59f63c63f9.png)

![image](https://user-images.githubusercontent.com/10358317/156364657-25877a8c-827a-4d59-8332-eb4b05f09de0.png)

- Enter Token that is grabbed before: 

![image](https://user-images.githubusercontent.com/10358317/156364296-a213c2fe-ad04-4ba7-97d4-fea5046aa6cf.png)

- Now we reached the dashboard:

![image](https://user-images.githubusercontent.com/10358317/156365659-e6fc81a8-e5e4-4443-9ed3-3d839cc63842.png)

### Enable Dashboard on Minikube

- Minikube has addons to enable dashboard:

``` 
minikube addons enable dashboard
minikube addons enable metrics-server
minikube dashboard
# if running on WSL/WSL2 to open browser
sensible-browser http://127.0.0.1:45771/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/
```     
    
![image](https://user-images.githubusercontent.com/10358317/152148024-6ec65b33-9fd0-42eb-89c3-927e453553a2.png)

### Reference

- https://www.replex.io/blog/how-to-install-access-and-add-heapster-metrics-to-the-kubernetes-dashboard
- https://github.com/kubernetes/dashboard


## Cluster Setup Reference Scripts

The scripts below are the upstream repository's `create_real_cluster/` install and master scripts, included verbatim as read-only reference material. Provisioning a real multi-node kubeadm cluster requires bare-metal or multi-VM infrastructure that is out of scope for the single-container lab sandbox, so this content is provided for study rather than wrapped in a graded interactive lab.

### create_real_cluster/ubuntu20.04-kubeadm1.26.2-calico3.25.0-containerd1.6.10/install.sh

```bash
#!/bin/bash
## this script is to install K8s dependency
## before using: chmod 777 install.sh
## usage => ./install.sh

set -e -o pipefail # fail on error , debug all lines

sudo apt-get update
sudo apt-get upgrade -y

echo "Configuring k8s.conf..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system

sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "Configuring containerd.conf..."
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "Configuring 99-kubernetes-cri.conf..."
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

echo "Installing containerd..."
sudo apt-get install containerd -y
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

echo "Installing kubeadm..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "Installing docker..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io  

cd /etc/docker
sudo touch /etc/docker/daemon.json

echo "Configuring docker daemon.json..."
cat <<EOF | sudo tee /etc/docker/daemon.json
{
"exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
cat /etc/docker/daemon.json
sudo systemctl restart docker
 
sudo usermod -aG docker $USER
sudo docker run hello-world

sudo kubeadm config images pull

echo "*******" 
echo "*** Now, run master.sh to install master node..."
echo "*** Usage => master.sh <MasterNodeIP>"
echo "*** If you are installing worker node, on master node: kubeadm token create --print-join-command"
echo "*** Copy and Paste the response into the each WORKER Node with SUDO command..."
echo "*******" 
```

### create_real_cluster/ubuntu20.04-kubeadm1.26.2-calico3.25.0-containerd1.6.10/master.sh

```bash
#!/bin/bash
## this script is to create K8s Master, 
## usage => master.sh <MasterNodeIP>

set -e -o pipefail # fail on error , debug all lines

echo "Initiating K8s Cluster..."
sudo kubeadm init --pod-network-cidr=172.24.0.0/16 --apiserver-advertise-address=$1 --control-plane-endpoint=$1
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Install calico..."
curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml > calico.yaml
kubectl apply -f ./calico.yaml

echo "Install calicoctl..."
sudo curl -o /usr/local/bin/calicoctl -O -L "https://github.com/projectcalico/calico/releases/download/v3.25.0/calicoctl-linux-amd64"
sudo chmod +x /usr/local/bin/calicoctl

echo "Disable IPinIP..."  
echo "Waiting 40sec..."
sleep 40
calicoctl get ipPool 'default-ipv4-ippool' -o yaml
calicoctl get ipPool 'default-ipv4-ippool' -o yaml > ippool.yaml
sed -i 's/Always/Never/g' ippool.yaml 
calicoctl apply -f ippool.yaml

echo "Configure felixconfig..."   
echo "Waiting 5sec..."
sleep 5 
kubectl get felixconfigurations.crd.projectcalico.org default  -o yaml -n kube-system > felixconfig.yaml
sed -i 's/true/false/g' felixconfig.yaml
kubectl apply -f felixconfig.yaml     

calicoctl ipam configure --strictaffinity=true
sleep 2 
echo "" 
echo "*******" 
echo "*** Please REBOOT/RESTART the PC now..."
echo "*** After restart run on this Master node: kubeadm token create --print-join-command"
echo "*** After restart if you encounter error (not to reach cluster, or API), please run closing swap commands again:"
echo "*** sudo swapoff -a"
echo "*** sudo sed -i '/ swap / s/^/#/' /etc/fstab"
echo "*** Copy and Paste the response into the each WORKER Node with SUDO command..."
kubeadm token create --print-join-command 
echo ""
echo "*** K8s Master Node is now up and the cluster is created..."
echo "*******" 
kubectl cluster-info
kubectl get nodes -o wide
#sudo reboot

# https://docs.tigera.io/calico/latest/getting-started/kubernetes/windows-calico/kubeconfig
echo "*******" 
echo "*** Calico-Node secret will be created for Windows Calico..."
echo "*******" 
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: calico-node
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: calico-node
type: kubernetes.io/service-account-token
EOF
```

### create_real_cluster/ubuntu24.04-kubeadm1.32.0-calico3.29.1-containerd1.7.24/install-ubuntu24.04-k8s1.32.sh

```bash
#!/bin/bash
## this script is to install K8s dependency
## before using: chmod 777 install.sh
## usage => ./install.sh

set -e -o pipefail # fail on error , debug all lines

sudo apt-get update
sudo apt-get upgrade -y

echo "Configuring k8s.conf..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system

sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "Configuring containerd.conf..."
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "Configuring 99-kubernetes-cri.conf..."
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

echo "Installing containerd..."
sudo apt-get install containerd -y
sudo apt update && sudo apt install containerd.io -y
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
# following SystemdCgroup is too important, issue in systemdCgroup, it applies after Ubuntu21.02
# [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
#  SystemdCgroup = true
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml  
sudo systemctl restart containerd

echo "Installing kubeadm..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
## see all versions: apt-cache showpkg kubelet

echo "Installing docker..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io  

cd /etc/docker
sudo touch /etc/docker/daemon.json

echo "Configuring docker daemon.json..."
cat <<EOF | sudo tee /etc/docker/daemon.json
{
"exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
cat /etc/docker/daemon.json
sudo systemctl restart docker
 
sudo usermod -aG docker $USER
sudo docker run hello-world

sudo kubeadm config images pull

echo "*******" 
echo "*** Now, run master.sh to install master node..."
echo "*** Usage => master.sh <MasterNodeIP>"
echo "*** If you are installing worker node, on master node: kubeadm token create --print-join-command"
echo "*** Copy and Paste the response into the each WORKER Node with SUDO command..."
echo "*******" 
```

### create_real_cluster/ubuntu24.04-kubeadm1.32.0-calico3.29.1-containerd1.7.24/master-ubuntu24.04-k8s1.32.sh

```bash
#!/bin/bash
## this script is to create K8s Master, 
## usage => master.sh <MasterNodeIP>

set -e -o pipefail # fail on error , debug all lines

echo "Initiating K8s Cluster..."
sudo kubeadm init --pod-network-cidr=172.24.0.0/16 --apiserver-advertise-address=$1 --control-plane-endpoint=$1
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Install calico..."
curl https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml > calico.yaml
kubectl apply -f ./calico.yaml

echo "Install calicoctl..."
sudo curl -o /usr/local/bin/calicoctl -O -L "https://github.com/projectcalico/calico/releases/download/v3.29.1/calicoctl-linux-amd64"
sudo chmod +x /usr/local/bin/calicoctl

echo "Disable IPinIP..."  
echo "Waiting 40sec..."
sleep 40
calicoctl get ipPool 'default-ipv4-ippool' -o yaml
calicoctl get ipPool 'default-ipv4-ippool' -o yaml > ippool.yaml
sed -i 's/Always/Never/g' ippool.yaml 
calicoctl apply -f ippool.yaml

echo "Configure felixconfig..."   
echo "Waiting 5sec..."
sleep 5 
kubectl get felixconfigurations.crd.projectcalico.org default  -o yaml -n kube-system > felixconfig.yaml
sed -i 's/true/false/g' felixconfig.yaml
kubectl apply -f felixconfig.yaml     

calicoctl ipam configure --strictaffinity=true
sleep 2 
echo "" 
echo "*******" 
echo "*** Please REBOOT/RESTART the PC now..."
echo "*** After restart run on this Master node: kubeadm token create --print-join-command"
echo "*** After restart if you encounter error (not to reach cluster, or API), please run closing swap commands again:"
echo "*** sudo swapoff -a"
echo "*** sudo sed -i '/ swap / s/^/#/' /etc/fstab"
echo "*** Copy and Paste the response into the each WORKER Node with SUDO command..."
kubeadm token create --print-join-command 
echo ""
echo "*** K8s Master Node is now up and the cluster is created..."
echo "*******" 
kubectl cluster-info
kubectl get nodes -o wide
#sudo reboot

# https://docs.tigera.io/calico/latest/getting-started/kubernetes/windows-calico/kubeconfig
echo "*******" 
echo "*** Calico-Node secret will be created for Windows Calico..."
echo "*******" 
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: calico-node
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: calico-node
type: kubernetes.io/service-account-token
EOF
```

### create_real_cluster/win2019-kubeadm1.26.2-calico3.25.0-docker/install-docker-ce.ps1

```powershell
# Microsoft: https://github.com/microsoft/Windows-Containers/blob/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1
############################################################
# Script to install the community edition of docker on Windows
############################################################

<#
    .NOTES
        Copyright (c) Microsoft Corporation.  All rights reserved.

        Use of this sample source code is subject to the terms of the Microsoft
        license agreement under which you licensed this sample source code. If
        you did not accept the terms of the license agreement, you are not
        authorized to use this sample source code. For the terms of the license,
        please see the license agreement between you and Microsoft or, if applicable,
        see the LICENSE.RTF on your install media or the root of your tools installation.
        THE SAMPLE SOURCE CODE IS PROVIDED "AS IS", WITH NO WARRANTIES.

    .SYNOPSIS
        Installs the prerequisites for creating Windows containers

    .DESCRIPTION
        Installs the prerequisites for creating Windows containers

    .PARAMETER DockerPath
        Path to Docker.exe, can be local or URI

    .PARAMETER DockerDPath
        Path to DockerD.exe, can be local or URI

    .PARAMETER DockerVersion
        Version of docker to pull from download.docker.com - ! OVERRIDDEN BY DockerPath & DockerDPath

    .PARAMETER ExternalNetAdapter
        Specify a specific network adapter to bind to a DHCP network

    .PARAMETER SkipDefaultHost
        Prevents setting localhost as the default network configuration

    .PARAMETER Force 
        If a restart is required, forces an immediate restart.
        
    .PARAMETER HyperV 
        If passed, prepare the machine for Hyper-V containers
        
    .PARAMETER NATSubnet 
        Use to override the default Docker NAT Subnet when in NAT mode.

    .PARAMETER NoRestart
        If a restart is required the script will terminate and will not reboot the machine

    .PARAMETER ContainerBaseImage
        Use this to specify the URI of the container base image you wish to pre-pull

    .PARAMETER Staging

    .PARAMETER TransparentNetwork
        If passed, use DHCP configuration.  Otherwise, will use default docker network (NAT). (alias -UseDHCP)

    .PARAMETER TarPath
        Path to the .tar that is the base image to load into Docker.

    .EXAMPLE
        .\install-docker-ce.ps1

#>
#Requires -Version 5.0

[CmdletBinding(DefaultParameterSetName="Standard")]
param(
    [string]
    [ValidateNotNullOrEmpty()]
    $DockerPath = "default",

    [string]
    [ValidateNotNullOrEmpty()]
    $DockerDPath = "default",

    [string]
    [ValidateNotNullOrEmpty()]
    $DockerVersion = "latest",

    [string]
    $ExternalNetAdapter,

    [switch]
    $Force,

    [switch]
    $HyperV,

    [switch]
    $SkipDefaultHost,

    [string]
    $NATSubnet,

    [switch]
    $NoRestart,

    [string]
    $ContainerBaseImage,

    [Parameter(ParameterSetName="Staging", Mandatory)]
    [switch]
    $Staging,

    [switch]
    [alias("UseDHCP")]
    $TransparentNetwork,

    [string]
    [ValidateNotNullOrEmpty()]
    $TarPath
)

$global:RebootRequired = $false
$global:ErrorFile = "$pwd\Install-ContainerHost.err"
$global:BootstrapTask = "ContainerBootstrap"
$global:HyperVImage = "NanoServer"
$global:AdminPriviledges = $false

$global:DefaultDockerLocation = "https://download.docker.com/win/static/stable/x86_64/"
$global:DockerDataPath = "$($env:ProgramData)\docker"
$global:DockerServiceName = "docker"

function
Restart-And-Run()
{
    Test-Admin

    Write-Output "Restart is required; restarting now..."

    $argList = $script:MyInvocation.Line.replace($script:MyInvocation.InvocationName, "")

    #
    # Update .\ to the invocation directory for the bootstrap
    #
    $scriptPath = $script:MyInvocation.MyCommand.Path

    $argList = $argList -replace "\.\\", "$pwd\"

    if ((Split-Path -Parent -Path $scriptPath) -ne $pwd)
    {
        $sourceScriptPath = $scriptPath
        $scriptPath = "$pwd\$($script:MyInvocation.MyCommand.Name)"

        Copy-Item $sourceScriptPath $scriptPath
    }

    Write-Output "Creating scheduled task action ($scriptPath $argList)..."
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoExit $scriptPath $argList"

    Write-Output "Creating scheduled task trigger..."
    $trigger = New-ScheduledTaskTrigger -AtLogOn

    Write-Output "Registering script to re-run at next user logon..."
    Register-ScheduledTask -TaskName $global:BootstrapTask -Action $action -Trigger $trigger -RunLevel Highest | Out-Null

    try
    {
        if ($Force)
        {
            Restart-Computer -Force
        }
        else
        {
            Restart-Computer
        }
    }
    catch
    {
        Write-Error $_

        Write-Output "Please restart your computer manually to continue script execution."
    }

    exit
}


function
Install-Feature
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $FeatureName
    )

    Write-Output "Querying status of Windows feature: $FeatureName..."
    if (Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue)
    {
        if ((Get-WindowsFeature $FeatureName).Installed)
        {
            Write-Output "Feature $FeatureName is already enabled."
        }
        else
        {
            Test-Admin

            Write-Output "Enabling feature $FeatureName..."
        }

        $featureInstall = Add-WindowsFeature $FeatureName

        if ($featureInstall.RestartNeeded -eq "Yes")
        {
            $global:RebootRequired = $true;
        }
    }
    else
    {
        if ((Get-WindowsOptionalFeature -Online -FeatureName $FeatureName).State -eq "Disabled")
        {
            if (Test-Nano)
            {
                throw "This NanoServer deployment does not include $FeatureName.  Please add the appropriate package"
            }

            Test-Admin

            Write-Output "Enabling feature $FeatureName..."
            $feature = Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart

            if ($feature.RestartNeeded -eq "True")
            {
                $global:RebootRequired = $true;
            }
        }
        else
        {
            Write-Output "Feature $FeatureName is already enabled."

            if (Test-Nano)
            {
                #
                # Get-WindowsEdition is not present on Nano.  On Nano, we assume reboot is not needed
                #
            }
            elseif ((Get-WindowsEdition -Online).RestartNeeded)
            {
                $global:RebootRequired = $true;
            }
        }
    }
}


function
New-ContainerTransparentNetwork
{
    if ($ExternalNetAdapter)
    {
        $netAdapter = (Get-NetAdapter |? {$_.Name -eq "$ExternalNetAdapter"})[0]
    }
    else
    {
        $netAdapter = (Get-NetAdapter |? {($_.Status -eq 'Up') -and ($_.ConnectorPresent)})[0]
    }

    Write-Output "Creating container network (Transparent)..."
    New-ContainerNetwork -Name "Transparent" -Mode Transparent -NetworkAdapterName $netAdapter.Name | Out-Null
}


function
Install-ContainerHost
{
    "If this file exists when Install-ContainerHost.ps1 exits, the script failed!" | Out-File -FilePath $global:ErrorFile

    if (Test-Client)
    {
        if (-not $HyperV)
        {
            Write-Output "Enabling Hyper-V containers by default for Client SKU"
            $HyperV = $true
        }    
    }
    #
    # Validate required Windows features
    #
    Install-Feature -FeatureName Containers

    if ($HyperV)
    {
        Install-Feature -FeatureName Hyper-V
    }

    if ($global:RebootRequired)
    {
        if ($NoRestart)
        {
            Write-Warning "A reboot is required; stopping script execution"
            exit
        }

        Restart-And-Run
    }

    #
    # Unregister the bootstrap task, if it was previously created
    #
    if ((Get-ScheduledTask -TaskName $global:BootstrapTask -ErrorAction SilentlyContinue) -ne $null)
    {
        Unregister-ScheduledTask -TaskName $global:BootstrapTask -Confirm:$false
    }    

    #
    # Configure networking
    #
    if ($($PSCmdlet.ParameterSetName) -ne "Staging")
    {
        if ($TransparentNetwork)
        {
            Write-Output "Waiting for Hyper-V Management..."
            $networks = $null

            try
            {
                $networks = Get-ContainerNetwork -ErrorAction SilentlyContinue
            }
            catch
            {
                #
                # If we can't query network, we are in bootstrap mode.  Assume no networks
                #
            }

            if ($networks.Count -eq 0)
            {
                Write-Output "Enabling container networking..."
                New-ContainerTransparentNetwork
            }
            else
            {
                Write-Output "Networking is already configured.  Confirming configuration..."
                
                $transparentNetwork = $networks |? { $_.Mode -eq "Transparent" }

                if ($transparentNetwork -eq $null)
                {
                    Write-Output "We didn't find a configured external network; configuring now..."
                    New-ContainerTransparentNetwork
                }
                else
                {
                    if ($ExternalNetAdapter)
                    {
                        $netAdapters = (Get-NetAdapter |? {$_.Name -eq "$ExternalNetAdapter"})

                        if ($netAdapters.Count -eq 0)
                        {
                            throw "No adapters found that match the name $ExternalNetAdapter"
                        }

                        $netAdapter = $netAdapters[0]
                        $transparentNetwork = $networks |? { $_.NetworkAdapterName -eq $netAdapter.InterfaceDescription }

                        if ($transparentNetwork -eq $null)
                        {
                            throw "One or more external networks are configured, but not on the requested adapter ($ExternalNetAdapter)"
                        }

                        Write-Output "Configured transparent network found: $($transparentNetwork.Name)"
                    }
                    else
                    {
                        Write-Output "Configured transparent network found: $($transparentNetwork.Name)"
                    }
                }
            }
        }
    }

    #
    # Install, register, and start Docker
    #
    if (Test-Docker)
    {
        Write-Output "Docker is already installed."
    }
    else
    {
        if ($NATSubnet)
        {
            Install-Docker -DockerPath $DockerPath -DockerDPath $DockerDPath -NATSubnet $NATSubnet -ContainerBaseImage $ContainerBaseImage
        }
        else
        {
            Install-Docker -DockerPath $DockerPath -DockerDPath $DockerDPath -ContainerBaseImage $ContainerBaseImage
        }
    }

    if ($TarPath)
    {
        cmd /c "docker load -i `"$TarPath`""
    }

    Remove-Item $global:ErrorFile

    Write-Output "Script complete!"
}

function
Copy-File
{
    [CmdletBinding()]
    param(
        [string]
        $SourcePath,
        
        [string]
        $DestinationPath
    )
    
    if ($SourcePath -eq $DestinationPath)
    {
        return
    }
          
    if (Test-Path $SourcePath)
    {
        Copy-Item -Path $SourcePath -Destination $DestinationPath
    }
    elseif (($SourcePath -as [System.URI]).AbsoluteURI -ne $null)
    {
        if (Test-Nano)
        {
            $handler = New-Object System.Net.Http.HttpClientHandler
            $client = New-Object System.Net.Http.HttpClient($handler)
            $client.Timeout = New-Object System.TimeSpan(0, 30, 0)
            $cancelTokenSource = [System.Threading.CancellationTokenSource]::new() 
            $responseMsg = $client.GetAsync([System.Uri]::new($SourcePath), $cancelTokenSource.Token)
            $responseMsg.Wait()

            if (!$responseMsg.IsCanceled)
            {
                $response = $responseMsg.Result
                if ($response.IsSuccessStatusCode)
                {
                    $downloadedFileStream = [System.IO.FileStream]::new($DestinationPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
                    $copyStreamOp = $response.Content.CopyToAsync($downloadedFileStream)
                    $copyStreamOp.Wait()
                    $downloadedFileStream.Close()
                    if ($copyStreamOp.Exception -ne $null)
                    {
                        throw $copyStreamOp.Exception
                    }      
                }
            }  
        }
        elseif ($PSVersionTable.PSVersion.Major -ge 5)
        {
            #
            # We disable progress display because it kills performance for large downloads (at least on 64-bit PowerShell)
            #
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $SourcePath -OutFile $DestinationPath -UseBasicParsing
            $ProgressPreference = 'Continue'
        }
        else
        {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($SourcePath, $DestinationPath)
        } 
    }
    else
    {
        throw "Cannot copy from $SourcePath"
    }
}


function 
Test-Admin()
{
    # Get the ID and security principal of the current user account
    $myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
  
    # Get the security principal for the Administrator role
    $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
  
    # Check to see if we are currently running "as Administrator"
    if ($myWindowsPrincipal.IsInRole($adminRole))
    {
        $global:AdminPriviledges = $true
        return
    }
    else
    {
        #
        # We are not running "as Administrator"
        # Exit from the current, unelevated, process
        #
        throw "You must run this script as administrator"   
    }
}


function 
Test-Client()
{
    return (-not ((Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue) -or (Test-Nano)))
}


function 
Test-Nano()
{
    $EditionId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'EditionID').EditionId

    return (($EditionId -eq "ServerStandardNano") -or 
            ($EditionId -eq "ServerDataCenterNano") -or 
            ($EditionId -eq "NanoServer") -or 
            ($EditionId -eq "ServerTuva"))
}


function 
Wait-Network()
{
    $connectedAdapter = Get-NetAdapter |? ConnectorPresent

    if ($connectedAdapter -eq $null)
    {
        throw "No connected network"
    }
       
    $startTime = Get-Date
    $timeElapsed = $(Get-Date) - $startTime

    while ($($timeElapsed).TotalMinutes -lt 5)
    {
        $readyNetAdapter = $connectedAdapter |? Status -eq 'Up'

        if ($readyNetAdapter -ne $null)
        {
            return;
        }

        Write-Output "Waiting for network connectivity..."
        Start-Sleep -sec 5

        $timeElapsed = $(Get-Date) - $startTime
    }

    throw "Network not connected after 5 minutes"
}


function 
Install-Docker()
{
    [CmdletBinding()]
    param(
        [string]
        [ValidateNotNullOrEmpty()]
        $DockerPath = "default",

        [string]
        [ValidateNotNullOrEmpty()]
        $DockerDPath = "default",
                
        [string]
        [ValidateNotNullOrEmpty()]
        $NATSubnet,

        [switch]
        $SkipDefaultHost,

        [string]
        $ContainerBaseImage
    )

    Test-Admin

    #If one of these are set to default then the whole .zip needs to be downloaded anyways.
    Write-Output "DOCKER $DockerPath"
    if ($DockerPath -eq "default" -or $DockerDPath -eq "default") {
        Write-Output "Checking Docker versions"
        #Get the list of .zip packages available from docker.
        $availableVersions = ((Invoke-WebRequest -Uri $DefaultDockerLocation -UseBasicParsing).Links | Where-Object {$_.href -like "docker*"}).href | Sort-Object -Descending
        
        #Parse the versions from the file names
        $availableVersions = ($availableVersions | Select-String -Pattern "docker-(\d+\.\d+\.\d+).+"  -AllMatches | Select-Object -Expand Matches | %{ $_.Groups[1].Value })
        $version = $availableVersions[0]

        if($DockerVersion -ne "latest") {
            $version = $DockerVersion
            if(!($availableVersions | Select-String $DockerVersion)) {
                Write-Error "Docker version supplied $DockerVersion was invalid, please choose from the list of available versions: $availableVersions"
                throw "Invalid docker version supplied."
            }
        }

        $zipUrl = $global:DefaultDockerLocation + "docker-$version.zip"
        $destinationFolder = "$env:UserProfile\DockerDownloads"

        if(!(Test-Path "$destinationFolder")) {
            md -Path $destinationFolder | Out-Null
        } elseif(Test-Path "$destinationFolder\docker-$version") {
            Remove-Item -Recurse -Force "$destinationFolder\docker-$version"
        }

        Write-Output "Downloading $zipUrl to $destinationFolder\docker-$version.zip"
        Copy-File -SourcePath $zipUrl -DestinationPath "$destinationFolder\docker-$version.zip"
        Expand-Archive -Path "$destinationFolder\docker-$version.zip" -DestinationPath "$destinationFolder\docker-$version"

        if($DockerPath -eq "default") {
            $DockerPath = "$destinationFolder\docker-$version\docker\docker.exe"
        }
        if($DockerDPath -eq "default") {
            $DockerDPath = "$destinationFolder\docker-$version\docker\dockerd.exe"
        }
    }

    Write-Output "Installing Docker... $DockerPath"
    Copy-File -SourcePath $DockerPath -DestinationPath $env:windir\System32\docker.exe
        
    Write-Output "Installing Docker daemon... $DockerDPath"
    Copy-File -SourcePath $DockerDPath -DestinationPath $env:windir\System32\dockerd.exe
    
    $dockerConfigPath = Join-Path $global:DockerDataPath "config"
    
    if (!(Test-Path $dockerConfigPath))
    {
        md -Path $dockerConfigPath | Out-Null
    }

    #
    # Register the docker service.
    # Configuration options should be placed at %programdata%\docker\config\daemon.json
    #
    Write-Output "Configuring the docker service..."

    $daemonSettings = New-Object PSObject
        
    $certsPath = Join-Path $global:DockerDataPath "certs.d"

    if (Test-Path $certsPath)
    {
        $daemonSettings | Add-Member NoteProperty hosts @("npipe://", "0.0.0.0:2376")
        $daemonSettings | Add-Member NoteProperty tlsverify true
        $daemonSettings | Add-Member NoteProperty tlscacert (Join-Path $certsPath "ca.pem")
        $daemonSettings | Add-Member NoteProperty tlscert (Join-Path $certsPath "server-cert.pem")
        $daemonSettings | Add-Member NoteProperty tlskey (Join-Path $certsPath "server-key.pem")
    }
    elseif (!$SkipDefaultHost.IsPresent)
    {
        # Default local host
        $daemonSettings | Add-Member NoteProperty hosts @("npipe://")
    }

    if ($NATSubnet -ne "")
    {
        $daemonSettings | Add-Member NoteProperty fixed-cidr $NATSubnet
    }

    $daemonSettingsFile = Join-Path $dockerConfigPath "daemon.json"

    $daemonSettings | ConvertTo-Json | Out-File -FilePath $daemonSettingsFile -Encoding ASCII
    
    & dockerd --register-service --service-name $global:DockerServiceName

    Start-Docker

    #
    # Waiting for docker to come to steady state
    #
    Wait-Docker

    if(-not [string]::IsNullOrEmpty($ContainerBaseImage)) {
        Write-Output "Attempting to pull specified base image: $ContainerBaseImage"
        docker pull $ContainerBaseImage
    }

    Write-Output "The following images are present on this machine:"
    
    docker images -a | Write-Output

    Write-Output ""
}

function 
Start-Docker()
{
    Start-Service -Name $global:DockerServiceName
}


function 
Stop-Docker()
{
    Stop-Service -Name $global:DockerServiceName
}


function 
Test-Docker()
{
    $service = Get-Service -Name $global:DockerServiceName -ErrorAction SilentlyContinue

    return ($service -ne $null)
}


function 
Wait-Docker()
{
    Write-Output "Waiting for Docker daemon..."
    $dockerReady = $false
    $startTime = Get-Date

    while (-not $dockerReady)
    {
        try
        {
            docker version | Out-Null

            if (-not $?)
            {
                throw "Docker daemon is not running yet"
            }

            $dockerReady = $true
        }
        catch 
        {
            $timeElapsed = $(Get-Date) - $startTime

            if ($($timeElapsed).TotalMinutes -ge 1)
            {
                throw "Docker Daemon did not start successfully within 1 minute."
            } 

            # Swallow error and try again
            Start-Sleep -sec 1
        }
    }
    Write-Output "Successfully connected to Docker Daemon."
}

try
{
    Install-ContainerHost
}
catch 
{
    Write-Error $_
}
```

### create_real_cluster/win2019-kubeadm1.26.2-calico3.25.0-docker/install1.ps1

```powershell
echo "#########################################################"
echo "Script will start in 10 Seconds..."
Start-Sleep -s 10

echo "Firewall rules : Allow All Traffic..."
New-NetFireWallRule -DisplayName "Allow All Traffic" -Direction OutBound -Action Allow  
New-NetFireWallRule -DisplayName "Allow All Traffic" -Direction InBound -Action Allow 

echo "Installing Docker Container..."
Install-WindowsFeature -Name containers  

# DockerMsftProvider Depreciated!! instead of it, using install-docker-ce.ps1 from Microsoft to install on Windows Servers
#echo "Installing DockerMsftProvider, Waiting 15 Seconds..."
#Start-Sleep -s 15
#Install-Module DockerMsftProvider -Force
#Install-Package Docker -ProviderName DockerMsftProvider -Force 

echo "Installing Docker, Waiting 10 Seconds..."
Start-Sleep -s 10
.\install-docker-ce.ps1

echo "Setting Service Docker, Waiting 20 Seconds..."
Start-Sleep -s 20
Set-Service -Name docker -StartupType 'Automatic' 
 
echo "Installing additional Windows networking components: RemoteAccess, RSAT-RemoteAccess-PowerShell, Routing, Waiting 10 Seconds..."
Start-Sleep -s 10
Install-WindowsFeature RemoteAccess 

echo "Installing RSAT-RemoteAccess-PowerShell, Waiting 10 Seconds..."
Start-Sleep -s 10
Install-WindowsFeature RSAT-RemoteAccess-PowerShell 

echo "Installing Routing, Waiting 10 Seconds..."
Start-Sleep -s 10
Install-WindowsFeature Routing 

echo "#########################################################"
echo "Docker and network components are installed..."
echo "After Restart, please run INSTALL2.ps1..."
echo "Before to run this install2.ps1, please be sure creating 'k' directory under C directory (c:\k) and includes K8s config file..."
echo "e.g. mkdir c:\k"
echo "e.g. run on the master node:  scp -r /home/ubuntu/.kube/config windowsuser@IP:C:\k"
echo "e.g. or copy the config file content, and paste it on Windows c:\k"
echo "#########################################################"
echo "Computer will be restarted in 10 Seconds..."
Start-Sleep -s 10
Restart-Computer -Force 
```

### create_real_cluster/win2019-kubeadm1.26.2-calico3.25.0-docker/install2.ps1

```powershell
echo "#########################################################"
echo "Before to run this script, please be sure creating 'k' directory under C directory (c:\k) and includes K8s config file..."
echo "e.g. mkdir c:\k"
echo "e.g. run on the master node:  scp -r /home/ubuntu/.kube/config windowsuser@IP:C:\k"
echo "#########################################################"
echo "Script will start in 10 Seconds..."
Start-Sleep -s 10

echo "Installing remote access..."
Install-RemoteAccess -VpnType RoutingOnly 
Set-Service -Name RemoteAccess -StartupType 'Automatic' 
start-service RemoteAccess 

echo "Installing Calico, Waiting 10 Seconds..."
Start-Sleep -s 10
Invoke-WebRequest https://github.com/projectcalico/calico/releases/download/v3.25.0/install-calico-windows.ps1 -OutFile c:\install-calico-windows.ps1
c:\install-calico-windows.ps1 -DownloadOnly yes -KubeVersion 1.23.5
Get-Service -Name CalicoNode 
Get-Service -Name CalicoFelix 

echo "Installing Kubelet Service, Waiting 10 Seconds..."
Start-Sleep -s 10
C:\CalicoWindows\kubernetes\install-kube-services.ps1 
Start-Service -Name kubelet 
Start-Service -Name kube-proxy 
 
echo "Testing kubectl..."
kubectl get nodes -o wide     

echo "#########################################################"
echo "Congrulations, kubernetes installed on Win..." 
echo "Calico Ref: https://docs.tigera.io/calico/latest/getting-started/kubernetes/windows-calico/kubernetes/standard"
echo "#########################################################"
```

### create_real_cluster/win2022-kubeadm1.32.0-calico3.29.1-containerd1.7.24/install1.ps1

```powershell
echo "#########################################################"
echo "Script will start in 10 Seconds..."
Start-Sleep -s 10

echo "Firewall rules : Allow All Traffic..."
New-NetFireWallRule -DisplayName "Allow All Traffic" -Direction OutBound -Action Allow  
New-NetFireWallRule -DisplayName "Allow All Traffic" -Direction InBound -Action Allow 

echo "Installing Containers..."
Install-WindowsFeature -Name containers  

echo "Installing Containerd, Waiting 10 Seconds..."
Start-Sleep -s 10
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-ContainerdRuntime/install-containerd-runtime.ps1" -o install-containerd-runtime.ps1
.\install-containerd-runtime.ps1

echo "Setting Service Containerd, Waiting 20 Seconds..."
Start-Sleep -s 20
Set-Service -Name containerd -StartupType 'Automatic' 
 
echo "Installing additional Windows networking components: RemoteAccess, RSAT-RemoteAccess-PowerShell, Routing, Waiting 10 Seconds..."
Start-Sleep -s 10
Install-WindowsFeature RemoteAccess 

echo "Installing RSAT-RemoteAccess-PowerShell, Waiting 10 Seconds..."
Start-Sleep -s 10
Install-WindowsFeature RSAT-RemoteAccess-PowerShell 

echo "Installing Routing, Waiting 10 Seconds..."
Start-Sleep -s 10
Install-WindowsFeature Routing 

echo "#########################################################"
echo "Docker and network components are installed..."
echo "After Restart, please run INSTALL2.ps1..."
echo "Before to run this install2.ps1, please be sure creating 'k' directory under C directory (c:\k) and includes K8s config file..."
echo "e.g. mkdir c:\k"
echo "e.g. run on the master node:  scp -r /home/ubuntu/.kube/config windowsuser@IP:C:\k"
echo "e.g. or copy the config file content, and paste it on Windows c:\k"
echo "#########################################################"
echo "Computer will be restarted in 10 Seconds..."
Start-Sleep -s 10
Restart-Computer -Force 
```

### create_real_cluster/win2022-kubeadm1.32.0-calico3.29.1-containerd1.7.24/install2.ps1

```powershell
echo "#########################################################"
echo "Before to run this script, please be sure creating 'k' directory under C directory (c:\k) and includes K8s config file..."
echo "e.g. mkdir c:\k"
echo "e.g. run on the master node:  scp -r /home/ubuntu/.kube/config windowsuser@IP:C:\k"
echo "#########################################################"
echo "Script will start in 10 Seconds..."
Start-Sleep -s 10

echo "Installing remote access..."
Install-RemoteAccess -VpnType RoutingOnly 
Set-Service -Name RemoteAccess -StartupType 'Automatic' 
start-service RemoteAccess 

echo "Installing Calico, Waiting 10 Seconds..."
Start-Sleep -s 10
Invoke-WebRequest -Uri https://github.com/projectcalico/calico/releases/download/v3.29.2/install-calico-windows.ps1 -OutFile c:\install-calico-windows.ps1
c:\install-calico-windows.ps1 -ReleaseBaseURL "https://github.com/projectcalico/calico/releases/download/v3.29.2" -ReleaseFile "calico-windows-v3.29.2.zip" -KubeVersion "1.32.0" -DownloadOnly "yes" -ServiceCidr "10.96.0.0/24" -DNSServerIPs "127.0.0.1"

$ENV:CNI_BIN_DIR="c:\program files\containerd\cni\bin"
$ENV:CNI_CONF_DIR="c:\program files\containerd\cni\conf"
c:\calicowindows\install-calico.ps1
c:\calicowindows\start-calico.ps1

echo "Installing Kubelet Service, Waiting 10 Seconds..."
Start-Sleep -s 10
c:\calicowindows\kubernetes\install-kube-services.ps1
New-NetFirewallRule -Name 'Kubelet-In-TCP' -DisplayName 'Kubelet (node)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 10250
Start-Service -Name kubelet 
Start-Service -Name kube-proxy 

echo "Testing kubectl..."
kubectl get nodes -o wide   


echo "#########################################################"
echo "Congrulations, kubernetes installed on Win..." 
echo "Calico Ref: https://docs.tigera.io/calico/latest/getting-started/kubernetes/windows-calico/kubernetes/standard"
echo "#########################################################"
# ref: https://medium.com/@lubomir-tobek/kubernetes-cluster-and-adding-a-windows-worker-node-0a5b65bffbaa
```
$md$, 60)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b12db871-05a7-5d91-a355-7cf5f23f4d02', '00000000-0000-0000-0000-000000000001', 'mcq', 'After running `sudo kubeadm init` on the control-plane node, which commands a...', 'beginner', 2, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('92a34821-4c7b-5e72-bc67-ebd4844a617b', 'b12db871-05a7-5d91-a355-7cf5f23f4d02', 1, $json${"prompt":"After running `sudo kubeadm init` on the control-plane node, which commands are required to let a regular (non-root) user run `kubectl` against the new cluster, as shown in the lesson?","multiple":false,"options":[{"id":"a","text":"Only sudo kubeadm init is needed; kubectl works immediately for any user without further steps","is_correct":false},{"id":"b","text":"Create $HOME/.kube, copy /etc/kubernetes/admin.conf into it as config, then chown that file to the current user","is_correct":true},{"id":"c","text":"Reinstall kubectl using a special --user flag on apt-get install","is_correct":false},{"id":"d","text":"Run kubectl config set-context to switch the current user to root","is_correct":false}],"explanation":"The lesson's setup steps are `mkdir -p $HOME/.kube`, `sudo cp -i\n/etc/kubernetes/admin.conf $HOME/.kube/config`, and `sudo chown $(id -u):$(id -g)\n$HOME/.kube/config`. This copies the admin kubeconfig generated by kubeadm init and\nhands ownership to the current user so kubectl can read it without sudo.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3f32bc90-e94e-514f-bf99-df566fb31e0f', '00000000-0000-0000-0000-000000000001', 'mcq', 'According to the lesson, what two pieces of information (besides the API serv...', 'beginner', 2, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4b56242b-a64c-5a12-a3a7-13e596da2f33', '3f32bc90-e94e-514f-bf99-df566fb31e0f', 1, $json${"prompt":"According to the lesson, what two pieces of information (besides the API server address) does a worker node need in order to run `kubeadm join` and join an existing cluster?","multiple":false,"options":[{"id":"a","text":"The cluster's join token and its discovery-token-ca-cert-hash","is_correct":true},{"id":"b","text":"The control-plane node's root password and SSH private key","is_correct":false},{"id":"c","text":"The name of the CNI plugin and the Pod CIDR range","is_correct":false},{"id":"d","text":"The kubeconfig file of another worker node that has already joined","is_correct":false}],"explanation":"The lesson repeatedly shows the form `kubeadm join \u003caddress\u003e --token \u003ctoken\u003e\n--discovery-token-ca-cert-hash sha256:\u003chash\u003e`. The token authenticates the worker with\nthe control plane, and the discovery-token-ca-cert-hash lets the worker verify the\ncontrol plane's identity. `kubeadm token create --print-join-command` is the easy way\nshown in the lesson to regenerate this full join command later.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e9f93475-c462-5e72-ac02-d71264f4b5fd', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the lesson''s ''Enable Dashboard on Cluster'' walkthrough, after applying the...', 'intermediate', 3, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f7296826-36e8-5e08-bcb9-cca399f0bd2e', 'e9f93475-c462-5e72-ac02-d71264f4b5fd', 1, $json${"prompt":"In the lesson's 'Enable Dashboard on Cluster' walkthrough, after applying the Kubernetes Dashboard manifest and running `kubectl proxy`, how does the lesson obtain admin credentials to log into the dashboard UI?","multiple":false,"options":[{"id":"a","text":"It creates a ServiceAccount named dashboard-admin-sa, binds it to the cluster-admin ClusterRole with a ClusterRoleBinding, then reads that ServiceAccount's token from its secret","is_correct":true},{"id":"b","text":"The dashboard ships with a built-in admin/admin login","is_correct":false},{"id":"c","text":"It reuses the same kubeconfig file that kubectl uses, pasted directly into the browser","is_correct":false},{"id":"d","text":"It runs minikube dashboard, which disables authentication entirely even on non-minikube clusters","is_correct":false}],"explanation":"The lesson runs `kubectl create serviceaccount dashboard-admin-sa`, then\n`kubectl create clusterrolebinding dashboard-admin-sa --clusterrole=cluster-admin\n--serviceaccount=default:dashboard-admin-sa` to grant it admin rights, then finds its\ntoken with `kubectl get secrets` and `kubectl describe secret\ndashboard-admin-sa-token-...`, and pastes that token into the Dashboard's token login\nscreen. The separate `minikube addons enable dashboard` path shown later in the lesson\nis a simpler option available only on minikube."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('c78fe849-5b5e-594f-833a-731b252a7a3e', '00000000-0000-0000-0000-000000000001', 'Quiz: Cluster Setup & Operations', 'k8s-cluster-ops-quiz', 'Quiz covering Cluster Setup & Operations.', 'mcq', 'published', 'module', '0bfbb16a-6679-565f-9573-e306d6c30409', 15, 60, 5, 7, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('ae5425d2-aea3-5453-b309-dd3f6fa25992', 'c78fe849-5b5e-594f-833a-731b252a7a3e', 'b12db871-05a7-5d91-a355-7cf5f23f4d02', '92a34821-4c7b-5e72-bc67-ebd4844a617b', 0, 2),
('dc9ec86a-6dd0-5352-9219-e3640c98aced', 'c78fe849-5b5e-594f-833a-731b252a7a3e', '3f32bc90-e94e-514f-bf99-df566fb31e0f', '4b56242b-a64c-5a12-a3a7-13e596da2f33', 1, 2),
('ec18e6c3-a069-5507-8277-90c5b0e6a0f2', 'c78fe849-5b5e-594f-833a-731b252a7a3e', 'e9f93475-c462-5e72-ac02-d71264f4b5fd', 'f7296826-36e8-5e08-bcb9-cca399f0bd2e', 2, 3)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('0bfbb16a-6679-565f-9573-e306d6c30409', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'a6a3c179-127f-5a21-b823-1ddb520e36eb', 'Quiz: Cluster Setup & Operations', 'assessment', 1, 15, 'c78fe849-5b5e-594f-833a-731b252a7a3e')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Helm & Packaging
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('8c7e60f0-4e81-55a1-b5d2-e985155f8562', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Helm & Packaging', 8)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes)
VALUES ('4c83f344-4fc6-528b-ad75-f64acb9e916a', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '8c7e60f0-4e81-55a1-b5d2-e985155f8562', 'Helm & Packaging', 'notes', 0, $md$
## Helm

## Helm

### Helm Install
- Installed on Ubuntu 20.04 (for other platforms: https://helm.sh/docs/intro/install/)

```
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```
- Check version (helm version):

![image](https://user-images.githubusercontent.com/10358317/153708424-d875f4bc-1af5-4169-85af-c87044e64f17.png)

- **ArtifactHUB:** https://artifacthub.io/
- ArtifactHub is like DockerHub, but it includes Helm Charts. (e.g. search wordpress on artifactHub on browser)

![image](https://user-images.githubusercontent.com/10358317/153708626-6715df00-81c0-4314-b2fa-6c6b563a1af1.png)

- With Helm Search on Hub:
```
helm search hub wordpress        # searches package on the Hub
helm search repo wordpress       # searches package on the local machine repository list
helm search repo bitnami         # searches bitnami in the repo list   

```
![image](https://user-images.githubusercontent.com/10358317/153708687-c2542aa5-e763-4967-b8a9-0f4b82ab7af0.png)




- **Repo:** the list on the local machine, repo item includes the package's download page (e.g. https://charts.bitnami.com/bitnami) 

```
helm repo add bitnami https://charts.bitnami.com/bitnami            # adds link into my repo list
helm search repo wordpress                                          # searches package on the local machine repository list
helm repo list                                                      # list all repo
helm pull [chart]
helm pull jenkins/jenkins
helm pull bitnami/jenkins                                           # pull and download chart to the current directory
tar zxvf jenkins-3.11.4.tgz                                         # extract downloaded chart
```

![image](https://user-images.githubusercontent.com/10358317/153730338-0f00f81b-b2e8-4fd9-be3c-3a8acd9e2d2a.png)

![image](https://user-images.githubusercontent.com/10358317/153730367-6ef92437-49bd-47df-8ca2-009301872614.png)

- Downloaded chart file structure and files:
 - **values.yaml**: includes values, variables, configs, replicaCount, imageName, etc. These values are injected into the template yaml files (e.g. replicas: {{ .Values.replicaCount }} in the deployment yaml file)
 - **charts.yaml**: includes chart information (annotations, maintainers, appVersion, apiVersion, description, sources, etc.)
 - **template**: directory that includes all K8s yaml template files (deployment,secret,configmap, etc.)
 - **values-summary**: includes the configurable parameters about application, K8s (parameter, description and value) 

```
tree jenkins
```

![image](https://user-images.githubusercontent.com/10358317/153730633-6e4b4d24-e4c0-4b4b-bab8-a8f06eb2c074.png)


- Install chart on K8s with application/release name
 
```
helm install helm-release-wordpress bitnami/wordpress               # install bitnami/wordpress chart with helm-release-wordpress name on default namespace
helm install release bitnami/wordpress --namespace production       # install release on production namespace
helm install my-release \                                           # possible to set username/password while creating pods
  --set wordpressUsername=admin \
  --set wordpressPassword=password \
  --set mariadb.auth.rootPassword=secretpassword \
    bitnami/wordpress
helm install wordpress-release bitnami/wordpress -f ./values.yaml   # values.yaml includes import values (e.g. username,pass,..), if it is updated and using this file, it is possible to install with these values. 
echo '{mariadb.auth.database: user0db, mariadb.auth.username: user0}' > values.yaml
helm install -f values.yaml bitnami/wordpress --generate-name       # with using "-f values.yaml", updated values are used 
helm install j1 jenkins                                             # jenkins is downloaded and extracted directory. After values.yaml updated, also possible to install with this updated app config
```

![image](https://user-images.githubusercontent.com/10358317/153709179-d36c5c8a-39d9-4ba4-ab30-243706caa6ae.png)

- To see the status of the release:

```
helm status helm-release-wordpress
```
![image](https://user-images.githubusercontent.com/10358317/153711226-1d058594-9ba9-402d-a422-4f2c95e19070.png)

- We can change/show the values that are the variables (e.g.username,password): 
```
helm show values bitnami/wordpress
```
![image](https://user-images.githubusercontent.com/10358317/153711295-2a25ea75-6ce1-434f-9138-54b262c100f1.png)


- You can see the all K8s objects that are automatically created by Helm

```
kubectl get pods
kubectl get svc
kubectl get deployment
kubectl get pv
kubectl get pvc
kubectl get configmap
kubectl get secrets
kubectl get pods --all-namespace
helm list
```
![image](https://user-images.githubusercontent.com/10358317/153709719-c26478a4-cad5-4d9b-80ab-9302c89629e2.png)

- Get password of wordpress:

![image](https://user-images.githubusercontent.com/10358317/153709965-d702a32a-0041-4c5d-b0de-12b229476dfe.png)

- Open tunnel from minikube:

```
minikube service helm-release-wordpress --url
```

![image](https://user-images.githubusercontent.com/10358317/153709988-8252a1f1-dd56-46a3-a2d5-8ea8e7423a61.png)

![image](https://user-images.githubusercontent.com/10358317/153710041-47838752-ff54-4321-9fc1-e4d37211840d.png)

- Using username and pass (http://127.0.0.1:46007/admin):

![image](https://user-images.githubusercontent.com/10358317/153710100-cc29ac32-4f7d-4c69-a466-31dac86c1f06.png)
![image](https://user-images.githubusercontent.com/10358317/153710112-697852b5-e3c9-4166-9038-f9494b99488f.png)

- Uninstall helm release:

![image](https://user-images.githubusercontent.com/10358317/153711396-c6b4e973-22a3-4246-99a0-026ff4c7c14c.png)

- Upgrade, rollback, history:
```
helm install j1 jenkins                                    # create j1 release with jenkins chart
helm upgrade -f [filename.yaml] [RELEASE] [CHART]
helm upgrade -f values.yaml j1 jenkins/jenkins
helm rollback [RELEASE] [REVISION]
helm rollback j1 1
helm history [RELEASE]
helm rollback j1
```
![image](https://user-images.githubusercontent.com/10358317/153731806-95b20cd9-f3fd-4ea8-9fed-d8b37993d3d6.png)

- To learn more Helm commands:

**Goto:** [Helm Commands Cheatsheet](https://github.com/omerbsezer/Fast-Kubernetes/blob/main/HelmCheatsheet.md)



## Helm Cheatsheet

## Helm Commands Cheatsheet

### 1. Help, Version

#### See the general help for Helm
```
helm --help
```
#### See help for a particular command
```
helm [command] --help
```
#### See the installed version of Helm
```
helm version
```

### 2. Repo Add, Remove, Update

#### Add a repository from the internet
```
helm repo add [name] [url]
```
#### Remove a repository from your system
```
helm repo remove [name]
```
#### Update repositories
```
helm repo update
```

### 3. Repo List, Search

#### List chart repositories
```
helm repo list
```
#### Search charts for a keyword
```
helm search [keyword]
```
#### Search repositories for a keyword
```
helm search repo [keyword]
```
#### Search Helm Hub
```
helm search hub [keyword]
```

### 4. Install/Uninstall

#### Install an app
```
helm install [name] [chart]
```

#### Install an app in a specific namespace
```
helm install [name] [chart] --namespace [namespace]
```

#### Override the default values with those specified in a file of your choice
```
helm install [name] [chart] --values [yaml-file/url]
```

#### Run a test install to validate and verify the chart
```
helm install [name] --dry-run --debug
```

#### Uninstall a release
```
helm uninstall [release name]
```

### 5. Chart Management

#### Create a directory containing the common chart files and directories
```
helm create [name]
```

#### Package a chart into a chart archive
```
helm package [chart-path]
```

#### Run tests to examine a chart and identify possible issues
```
helm lint [chart]
```

#### Inspect a chart and list its contents
```
helm show all [chart]
```
#### Display the chart’s definition
```
helm show chart [chart]
```

#### Download a chart
```
helm pull [chart]
```

#### Download a chart and extract the archive’s contents into a directory
```
helm pull [chart] --untar --untardir [directory]
```

#### Display a list of a chart’s dependencies
```
helm dependency list [chart]
```

### 6. Release Monitoring

#### List all the available releases in the current namespace
```
helm list
```
#### List all the available releases across all namespaces
```
helm list --all-namespaces
```
#### List all the releases in a specific namespace
```
helm list --namespace [namespace]
```
#### List all the releases in a specific output format
```
helm list --output [format]
```
#### See the status of a release
```
helm status [release]
```
#### See the release history
```
helm history [release]
```
#### See information about the Helm client environment
```
helm env
```

### 7. Upgrade/Rollback

#### Upgrade an app
```
helm upgrade [release] [chart]
```

#### Tell Helm to roll back changes if the upgrade fails
```
helm upgrade [release] [chart] --atomic
```

#### Upgrade a release. If it does not exist on the system, install it
```
helm upgrade [release] [chart] --install
```

#### Upgrade to a version other than the latest one Upgrade an app
```
helm upgrade [release] [chart] --version [version-number]
```

#### Roll back a release
```
helm rollback [release] [revision]
```

### 8. GET Information

#### Download all the release information
```
helm get all [release]
```
#### Download all hooks
```
helm get hooks [release]
```
#### Download the manifest
```
helm get manifest [release]
```
#### Download the notes
```
helm get notes [release]
```
#### Download the values file
```
helm get all [release]
```
#### Release history
```
helm history [release]
```

### 9. Plugin

#### Install plugins
```
helm plugin install [path/url1] [path/url2]
```
#### View a list of all the installed plugins
```
helm plugin list
```
#### Update plugins
```
helm plugin update [plugin1] [plugin2]
```
#### Uninstall a plugin
```
helm plugin uninstall [plugin]
```





## K8s Helm Jenkins

## LAB: Helm-Jenkins on running K8s Cluster (2 Node Multipass VM)

- "Whenever you trigger a Jenkins job, the Jenkins Kubernetes plugin will make an API call to create a Kubernetes agent pod. Then, the Jenkins agent pod gets deployed in the kubernetes with few environment variables containing the Jenkins server details and secrets."
- "When the agent pod comes up, it used the details in its environment variables and talks back to Jenkins using the JNLP method" (Ref: DevopsCube)

<p align="center">
  <img src="https://user-images.githubusercontent.com/10358317/156229862-7046f57b-29eb-4c47-b8cd-fbe4376eac89.png">
</p>

### K8s Cluster (2 Node Multipass VM)
- K8s cluster was created before:
   - **Goto:** [K8s Kubeadm Cluster Setup](https://github.com/omerbsezer/Fast-Kubernetes/blob/main/K8s-Kubeadm-Cluster-Setup.md)

- On that cluster, helm was installed on the master node.

### Helm Install

- Install on Ubuntu 20.04 (for other platforms: https://helm.sh/docs/intro/install/)

```
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
helm version
```

### Jenkins Install

```
helm repo add jenkins https://charts.jenkins.io        
helm repo list
mkdir helm
cd helm
helm pull jenkins/jenkins                                           
tar zxvf jenkins-3.11.4.tgz                                       
```

- After unzipping, entered into the jenkins directory, you'll find values.yaml file. Disable the persistence with false. 
- If your cluster on-premise does not support storage class (like our multipass VM cluster), PVC and PV, disable persistence. But if you are working on minikube, minikube supports PVC and PV automatically. 
- If you don't disable persistence, you'll encounter that your PODs will not run (wait pending). You can inspect PVC, PV and Pod with kubectl describe command. 

![image](https://user-images.githubusercontent.com/10358317/156223521-0982d3d4-61aa-4a33-a068-a634e7382eed.png)

- Install Helm Jenkins Release:
```
helm install j1 jenkins
kubectl get pods
kubectl get svc
kubectl get pods -o wide
```

![image](https://user-images.githubusercontent.com/10358317/156224502-024f42ad-62e6-4887-9058-ae09f3beb91d.png)

- To get Jenkins password (username:admin), run:
```
kubectl exec --namespace default -it svc/j1-jenkins -c jenkins -- /bin/cat /run/secrets/chart-admin-password && echo  
```
![image](https://user-images.githubusercontent.com/10358317/156224860-c40406a7-7fbf-45bc-ada5-d4bb54cf1b25.png)

- Port Forwarding:
```
kubectl --namespace default port-forward svc/j1-jenkins 8080:8080
```
![image](https://user-images.githubusercontent.com/10358317/156225021-759b0507-37be-484c-87f3-777c0472e4ba.png)


### Install Graphical Desktop to Reach Browser using Multipass VM

- Install ubuntu-desktop, so you can reach multipass VM's browser using Windows RDP (Xrdp) (https://discourse.ubuntu.com/t/graphical-desktop-in-multipass/16229)

```
sudo apt update
sudo apt install ubuntu-desktop xrdp
sudo passwd ubuntu    # set password
```

### Jenkins Configuration

- Helm also downloads automatically some of the plugins  (kubernetes:1.31.3, workflow-aggregator:2.6, git:4.10.2, configuration-as-code:1.55.1) (Jenkins Version: 2.319.3)
- Manage Jenkins > Configure  System > Cloud
![image](https://user-images.githubusercontent.com/10358317/156225898-1487b783-d112-4fcb-8ffa-66195e2d5f35.png)

![image](https://user-images.githubusercontent.com/10358317/156226068-0afcd9c2-9537-4431-8cdd-954625a73434.png)

![image](https://user-images.githubusercontent.com/10358317/156226209-b05eb0fd-d467-42e0-9fc9-ad1b37cb6efa.png)

![image](https://user-images.githubusercontent.com/10358317/156226315-0dd0f343-d02d-45a3-b2ef-5289ad6dcd03.png)

![image](https://user-images.githubusercontent.com/10358317/156226468-2c09dd57-9d94-426d-ba9d-0c88f865afec.png)

![image](https://user-images.githubusercontent.com/10358317/156226617-caf80b7c-d20b-4cc2-84c3-d42742531cd5.png)

- New Item on main page: 

![image](https://user-images.githubusercontent.com/10358317/156226810-bfafc539-0ab5-4c18-b2ce-68191d5b0e4d.png)

![image](https://user-images.githubusercontent.com/10358317/156226947-78293336-a4ca-468c-b1e7-37247829d261.png)

- Add script > Build > Execute Shell:

![image](https://user-images.githubusercontent.com/10358317/156227131-c9f2a519-2749-405e-ab4a-7ae27c6b2787.png)

- After triggering jobs, Jenkins (on Master) creates agents on Worker1 automatically. After jobs are completed, they are terminated.

![image](https://user-images.githubusercontent.com/10358317/156227423-0dc264b5-9060-46c5-a353-4d15ea64e9fa.png)



### Reference

- https://www.jenkins.io/doc/book/scaling/scaling-jenkins-on-kubernetes/
- https://devopscube.com/jenkins-build-agents-kubernetes/


$md$, 45)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('9bd279a5-00b1-5953-a418-99a84c50d2fe', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is a Helm chart?', 'intermediate', 3, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c98ef511-5868-5f18-a22c-8a4008340717', '9bd279a5-00b1-5953-a418-99a84c50d2fe', 1, $json${"prompt":"What is a Helm chart?","multiple":false,"options":[{"id":"a","text":"A running instance of an application inside a Kubernetes namespace","is_correct":false},{"id":"b","text":"A packaged collection of Kubernetes YAML templates plus a values.yaml file and Chart.yaml metadata that together define a deployable application","is_correct":true},{"id":"c","text":"A remote server that stores container images, similar to a Docker registry","is_correct":false},{"id":"d","text":"A Kubernetes admission webhook that validates Helm-managed resources","is_correct":false}],"explanation":"A Helm chart is the package format Helm installs. Its values.yaml holds configurable\nvalues that get injected into the template files (e.g. replicas: {{ .Values.replicaCount }}),\nChart.yaml holds chart metadata (apiVersion, appVersion, maintainers, description), and the\ntemplate/ directory holds the actual Kubernetes manifest templates (Deployment, Service,\nConfigMap, Secret, etc.).\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d8df29c2-ea6c-5add-81af-35be37ab6a31', '00000000-0000-0000-0000-000000000001', 'mcq', 'After running `helm install my-release bitnami/wordpress`, what does `my-rele...', 'intermediate', 2, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('abf969a7-dd92-518f-80ee-1c17527d9f34', 'd8df29c2-ea6c-5add-81af-35be37ab6a31', 1, $json${"prompt":"After running `helm install my-release bitnami/wordpress`, what does `my-release` represent?","multiple":false,"options":[{"id":"a","text":"The name of the Helm repository the chart was pulled from","is_correct":false},{"id":"b","text":"The name assigned to this specific installed instance (release) of the chart, used by later commands such as helm status, helm upgrade, and helm uninstall","is_correct":true},{"id":"c","text":"The Kubernetes namespace the chart will be installed into","is_correct":false},{"id":"d","text":"The version tag of the chart being installed","is_correct":false}],"explanation":"Helm calls an installed instance of a chart a \"release\". Commands like helm status\n\u003crelease\u003e, helm upgrade -f values.yaml \u003crelease\u003e \u003cchart\u003e, helm rollback \u003crelease\u003e\n\u003crevision\u003e, and helm uninstall \u003crelease name\u003e all operate on that release name, not on\nthe chart or repository name.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('aca724bd-e499-56f0-b936-8b920fbfb20f', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which command adds a new chart repository (e.g. Bitnami''s) to your local Helm...', 'beginner', 2, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7aaca806-36fc-5546-870e-9da02407ac70', 'aca724bd-e499-56f0-b936-8b920fbfb20f', 1, $json${"prompt":"Which command adds a new chart repository (e.g. Bitnami's) to your local Helm client so its charts can be searched and installed from your machine?","multiple":false,"options":[{"id":"a","text":"helm search hub bitnami","is_correct":false},{"id":"b","text":"helm pull bitnami","is_correct":false},{"id":"c","text":"helm repo add bitnami https://charts.bitnami.com/bitnami","is_correct":true},{"id":"d","text":"helm install bitnami","is_correct":false}],"explanation":"helm repo add [name] [url] registers a chart repository locally; helm repo list then\nshows it and helm search repo searches the locally added repositories. helm search hub\ninstead searches Artifact Hub directly without needing a local repo add, and helm pull\nonly downloads a chart archive from a repo that has already been added."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('4918b4f2-671c-5a78-b8ba-3e00a1f9fb09', '00000000-0000-0000-0000-000000000001', 'Quiz: Helm & Packaging', 'k8s-helm-quiz', 'Quiz covering Helm & Packaging.', 'mcq', 'published', 'module', '8daa77a0-ae8d-5f35-aff4-2cda833e53e7', 15, 60, 5, 7, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('f3c98495-af04-507e-b009-8cb61ae20d9d', '4918b4f2-671c-5a78-b8ba-3e00a1f9fb09', '9bd279a5-00b1-5953-a418-99a84c50d2fe', 'c98ef511-5868-5f18-a22c-8a4008340717', 0, 3),
('67b5dc0f-77ec-54c7-98a0-f899837e5c3f', '4918b4f2-671c-5a78-b8ba-3e00a1f9fb09', 'd8df29c2-ea6c-5add-81af-35be37ab6a31', 'abf969a7-dd92-518f-80ee-1c17527d9f34', 1, 2),
('78c375ff-af31-5b38-93c5-e4c69151c52e', '4918b4f2-671c-5a78-b8ba-3e00a1f9fb09', 'aca724bd-e499-56f0-b936-8b920fbfb20f', '7aaca806-36fc-5546-870e-9da02407ac70', 2, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('8daa77a0-ae8d-5f35-aff4-2cda833e53e7', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '8c7e60f0-4e81-55a1-b5d2-e985155f8562', 'Quiz: Helm & Packaging', 'assessment', 1, 15, '4918b4f2-671c-5a78-b8ba-3e00a1f9fb09')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Observability
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('b5b0d081-fa01-57fe-860d-388f86b35cd6', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Observability', 9)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes)
VALUES ('19c963d4-687d-5ae5-9936-3faef76f4bb5', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'b5b0d081-fa01-57fe-860d-388f86b35cd6', 'Observability', 'notes', 0, $md$## LAB: K8s Monitoring: Prometheus and Grafana

This scenario shows how to implement Prometheus and Grafana on K8s Cluster.


### Table of Contents
- [Monitoring With SSH](#ssh)
- [Monitoring With Prometheus and Grafana](#prometheus-grafana)
  - [Prometheus and Grafana for Windows](#windows)

There are different options to monitor K8s cluster: SSH, Kubernetes Dashboard, Prometheus and Grafana, etc.
  
## 1. Monitoring With SSH <a name="ssh"></a>

- SSH can be used to get basic information about the cluster, nodes, and pods.
- Make SSH connection to Master Node of the K8s Cluster

``` 
ssh username@masterIP
```

- To get the nodes of the K8s

``` 
kubectl get nodes -o wide
```

- To get the pods on the K8s Cluster

```
kubectl get pods -o wide
```

- For Linux PCs: To get the pods on the K8s Cluster in real-time with the "watch" command

``` 
watch kubectl get pods -o wide
```

- To get all K8s objects:

```
kubectl get all
```

## 2. Monitoring With Prometheus and Grafana <a name="prometheus-grafana"></a>

- While implementting Prometheus and Grafana, Helm is used. 
- To add Prometheus repo into local repo and download it:

```
mkdir helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm pull  prometheus-community/kube-prometheus-stack
tar zxvf kube-prometheus-stack-34.10.0.tgz
cd kube-prometheus-stack
```

- "Values.yaml" file can be viewed and updated according to new values and new configuration.
- To install prometheus, release name is prometheus 

```
helm install prometheus kube-prometheus-stack
```

- Port forwarding is needed on the default connection, run on the different terminals: 

```
kubectl port-forward deployment/prometheus-grafana 3000
kubectl port-forward prometheus-prometheus-kube-prometheus-prometheus-0 9090
```

- Default provided username: admin, password: prom-operator

![image](https://user-images.githubusercontent.com/10358317/171119775-74e42538-afde-4cad-ac3b-01bd00b434f5.png)

- Monitoring all nodes' resources in terms of CPU, memory, disk space, network transmitted/received

![image](https://user-images.githubusercontent.com/10358317/171121847-88a7ee68-c38e-4fbd-ac72-30900e2c2e86.png)

![image](https://user-images.githubusercontent.com/10358317/171122247-d0e5a80c-0460-4ede-9e3a-8a15fa03b89b.png)


- Use nodeport option to make reachable with IP:Port. 
- Uninstall the current release run.

```
helm uninstall prometheus
```

- Open values.yaml file (kube-prometheus-stack/charts/grafana/values.yaml), change type from "ClusterIP" to "NodePort" and add "nodePort: 32333" 

![image](https://user-images.githubusercontent.com/10358317/171122676-59c04a9d-1170-42cb-8c84-d1de9e6c341e.png)

- Run the new release

```
helm install prometheus kube-prometheus-stack
```

- On the browser from any PC on the cluster, grafana screen can be viewed: MasterIP:32333

- Update (kube-prometheus-stack/charts/prometheus-node-exporter/values.yaml) to implement that node exporter works only on Linux machines. Add nodeSelector: kubernetes.io/os: linux

#### 2.1. Prometheus and Grafana for Windows <a name="windows"></a>

- Download windows_exporter-0.18.1-amd64.exe (latest version) from here: https://github.com/prometheus-community/windows_exporter/releases
- Copy/Move to under C:\ directory ("C:\windows_exporter-0.18.1-amd64.exe")
- Open Powershell with Admistration Rights, run:

```
New-Service -Name "windows_node_exporter" -BinaryPathName "C:\windows_exporter-0.18.1-amd64.exe"
Start-Service -Name windows_node_exporter
```
- Now, windows_exporter works as a service and runs automatically when restarting the windows node.  Check if it works in 2 ways: 
  - Open the browser and run: http://localhost:9182/metrics  to see resource data/metrics
  - Open Task Manager - Services Tab and see whether windows_node_exporter runs or not.

- Uninstall the current release run.

```
helm uninstall prometheus
```

- Open values.yaml in the kube-prometheus-stack directory (targets:  Windows IP, default port 9182)

```
    #additionalScrapeConfigs: [] (Line ~2480)
    additionalScrapeConfigs:
    - job_name: 'kubernetes-windows-exporter'
      static_configs:
        - targets: ["WindowsIP:9182"] 
```

- Run the new release

```
helm install prometheus kube-prometheus-stack
```

- Open Grafana and "Import"

![image](https://user-images.githubusercontent.com/10358317/171125351-f2560aff-f9cb-4929-9971-2d3c94c10891.png)

- Download Prometheus "Windows Exporter Node" dashboard from here: https://grafana.com/grafana/dashboards/14510/revisions
- There are  2 options: 
  - Copy the Json content and paste panel json,
  - Upload Json File

![image](https://user-images.githubusercontent.com/10358317/171125688-1df89d6f-ea85-4b13-bc0d-86934e6e4017.png)

- Select "Prometheus" as data source

- Now it works. Windows Node Exporter:

![image](https://user-images.githubusercontent.com/10358317/171122469-7b53a060-d778-463e-b215-cf8befb076b9.png)

## Reference

- https://youtu.be/jatcPHvChfI 
$md$, 20)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b964ad06-9027-50bb-b745-db1cf31522d1', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the kube-prometheus-stack setup described in the lesson, what role does He...', 'intermediate', 3, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5b2f8fd9-b01b-516e-96c2-62727f1a1948', 'b964ad06-9027-50bb-b745-db1cf31522d1', 1, $json${"prompt":"In the kube-prometheus-stack setup described in the lesson, what role does Helm play?","multiple":false,"options":[{"id":"a","text":"Helm is used to write PromQL queries against the Prometheus database","is_correct":false},{"id":"b","text":"Helm adds the prometheus-community chart repository and installs the kube-prometheus-stack chart, which deploys Prometheus and Grafana onto the cluster","is_correct":true},{"id":"c","text":"Helm completely replaces kubectl for all cluster monitoring tasks","is_correct":false},{"id":"d","text":"Helm is only used to install the Windows node exporter service","is_correct":false}],"explanation":"The lesson runs `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`,\n`helm pull prometheus-community/kube-prometheus-stack`, and `helm install prometheus\nkube-prometheus-stack` to deploy the whole Prometheus + Grafana stack as a single release\nnamed prometheus. kubectl is still used afterward for port-forwarding and inspecting pods.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('58b33983-df98-5fce-ad49-8e63a570a219', '00000000-0000-0000-0000-000000000001', 'mcq', 'After installing the kube-prometheus-stack chart with release name `prometheu...', 'beginner', 2, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c9939bba-627e-540b-8cde-4dc98c7f7e8d', '58b33983-df98-5fce-ad49-8e63a570a219', 1, $json${"prompt":"After installing the kube-prometheus-stack chart with release name `prometheus`, what are the default Grafana login credentials given in the lesson?","multiple":false,"options":[{"id":"a","text":"username: root, password: grafana","is_correct":false},{"id":"b","text":"username: admin, password: admin","is_correct":false},{"id":"c","text":"username: admin, password: prom-operator","is_correct":true},{"id":"d","text":"No credentials are required; Grafana is open by default","is_correct":false}],"explanation":"The lesson states the default provided username is admin and the default password is\nprom-operator when Grafana is deployed via the kube-prometheus-stack Helm chart.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('76a60d18-2c8c-5a64-9053-e85d3356cbd7', '00000000-0000-0000-0000-000000000001', 'mcq', 'The lesson changes Grafana''s Service type from ClusterIP to NodePort (adding ...', 'intermediate', 3, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e7dc0b90-e9e2-578b-af4e-9560c966ba99', '76a60d18-2c8c-5a64-9053-e85d3356cbd7', 1, $json${"prompt":"The lesson changes Grafana's Service type from ClusterIP to NodePort (adding nodePort: 32333) in values.yaml before reinstalling the release. Why is this change needed?","multiple":false,"options":[{"id":"a","text":"ClusterIP services cannot be scraped by Prometheus","is_correct":false},{"id":"b","text":"NodePort exposes the Grafana Service on a static port on every node's IP, making the dashboard reachable at MasterIP:32333 from any machine on the cluster network instead of requiring kubectl port-forward","is_correct":true},{"id":"c","text":"NodePort is required for any Helm chart to install successfully","is_correct":false},{"id":"d","text":"ClusterIP services are automatically deleted after 24 hours","is_correct":false}],"explanation":"By default the Grafana Service is ClusterIP, reachable only inside the cluster (or via\nkubectl port-forward deployment/prometheus-grafana 3000). Changing the type to NodePort\nand setting nodePort: 32333 exposes it on that port on every node's IP, so the lesson can\nbrowse to MasterIP:32333 directly."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('0e885af3-4393-5331-a0f9-7441054ab6c7', '00000000-0000-0000-0000-000000000001', 'Quiz: Observability', 'k8s-observability-quiz', 'Quiz covering Observability.', 'mcq', 'published', 'module', '404642ba-977e-5b0c-b766-59e027ff951b', 15, 60, 5, 8, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('fa23e644-9e1b-560e-916f-f4118cc520db', '0e885af3-4393-5331-a0f9-7441054ab6c7', 'b964ad06-9027-50bb-b745-db1cf31522d1', '5b2f8fd9-b01b-516e-96c2-62727f1a1948', 0, 3),
('d54da056-7670-5bcb-848b-b7d8dfff5d3a', '0e885af3-4393-5331-a0f9-7441054ab6c7', '58b33983-df98-5fce-ad49-8e63a570a219', 'c9939bba-627e-540b-8cde-4dc98c7f7e8d', 1, 2),
('d55b0dad-49e7-5c7c-8d2d-903e665b9d8e', '0e885af3-4393-5331-a0f9-7441054ab6c7', '76a60d18-2c8c-5a64-9053-e85d3356cbd7', 'e7dc0b90-e9e2-578b-af4e-9560c966ba99', 2, 3)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('404642ba-977e-5b0c-b766-59e027ff951b', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'b5b0d081-fa01-57fe-860d-388f86b35cd6', 'Quiz: Observability', 'assessment', 1, 15, '0e885af3-4393-5331-a0f9-7441054ab6c7')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Reference
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('e4330df2-0c59-592e-be64-093765351ea3', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'Reference', 10)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes)
VALUES ('f533fd17-715c-5f6f-bffe-a29bef310af2', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'e4330df2-0c59-592e-be64-093765351ea3', 'Reference', 'notes', 0, $md$## Kubernetes Commands Cheatsheet

#### minikube command
```
minikube start
minikube status
kubectl get nodes
minikube stop #does not delete, it runs with start
minikube delete # delete all
```
#### kubeadm command
- Kubeadm provides K8s cluster on on-premise
- You can test Kubeadm on PlayWithKubernetes
- Creating cluster with 1 master, 2 nodes (add new instance) on PlayWithKubernetes
```
on master: kubeadm init --apiserver-advertise-address $(hostname -i) --pod-network-cidr 10.5.0.0/16
on nodes: kubeadm join 192.168.0.13:6443 --token ge5xcq.xh2mcb4rqa8lz0db \
    --discovery-token-ca-cert-hash sha256:a3ba7ced9383a5b5704b6fbf696f243a8322759b68b9d07b747b174fcc838540
on master: mkdir -p $HOME/.kube
on master: cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
on master: chown $(id -u):$(id -g) $HOME/.kube/config
on master: kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml
kubectl get nodes
kubectl run test --image=nginx --restart=Never
```

#### kubectl config: context, user, cluster
```
kubectl config
kubectl config get-contexts  #get all context
kubectl config current-context  #get context
kubectl config use-context docker-desktop  #change context
kubectl config use-context docker-desktop
kubectl config use-context aks-k8s-test  
kubectl config use-context default  # default=minikube 
kubectl get nodes
```

#### cluster-info
```
kubectl cluster-info
kubectl cp --help
kubectl [verb] [type] [object]
kubectl delete pods test_pod
kubectl [get|delete|edit|apply] [pods, deployment, services, etc.] [podName, serviceName, deploymentName, etc.]
```

#### namespace, -n 
```
kubectl get pods # default namespace
kubectl get pods -n kube-system  #list kube-system namespace pods.
kubectl get pods --all-namespaces
kubectl get pods -A # all-namespace
```

#### more info about pods
```
kubectl get pods -A   # all-namespace
kubectl get pods -A -o wide # all-namespace with more detailed
kubectl get pods -A -o yaml
kubectl get pods -A -o json
kubectl get pods -A -o go-template
kubectl get pods -A -o json | jq -r ".items[].spec.containers[].name"   #jq parser query 
```

#### commands help
- 'help' to learn more for commands
```
kubectl apply --help #explain command
kubectl delete --help
```

#### object help: with explain
- 'explain' to learn more for objects 
```
kubectl explain pod
kubectl explain deployment
```

#### pod ~ container
```
kubectl run firstpod --image=nginx --restart=Never
kubectl run secondpod --image=nginx --port=80 --labels=app=frontend --restart=Never
```

#### get info about pods
```
kubectl get pods -o wide
kubectl describe pods firstpod
```

#### show log 
```
kubectl logs firstpod
kubectl logs -f firstpod  #watch live log with -f
```

#### run command in pod
```
kubectl exec firstpod -- hostname  #hostname command run in pod 
kubectl exec firstpod -- ls / #list command run in pod 
```

#### connect container in the pod
```
kubectl exec -it firstpod -- /bin/sh  # open shell, connect container
kubectl exec -it firstpod -- bash # run bash 
```

#### delete pod
```
kubectl delete pods firstpod
```

#### learn/explain api of objects
```
kubectl explain pods
kubectl explain deployments
kubectl explain serviceaccount
```

#### Declerative way with file, Imperative way with command
- File contents:
  - apiVersion: 
  - kind: (pod, deployment, etc.)
  - metadata: (podName, label, etc.)
  - specs: (restartPolicy, container name, image, command, ports, etc.)

#### file apply for declerative 
```
kubectl apply -f pod1.yaml
```

#### edit 
```
kubectl edit pods firstpod
```

#### delete 
```
kubectl delete -f podlabel.yaml #all related objects deleted with declerative way
```

#### watch pods always
```
kubectl get pods -w
```

#### run multiple container on 1 pod, -c containerName
```
kubectl exec -it multicontainer -c webcontainer -- /bin/sh  # -c ile containername, if more than one container
kubectl exec -it multicontainer -c sidecarcontainer -- /bin/sh 
kubectl logs -f multicontainer -c sidecarcontainer
```

#### port-forward to pod
```
kubectl port-forward pod/multicontainer 80:80   ## host:container port, if command is not run, port is not opened
kubectl port-forward pod/multicontainer 8080:80  # when browsing 127.0.0.1:8080, host:8080 goes to pod:80 and directs traffic.
kubectl port-forward <pod-name> <locahost-port>:<pod-port>
kubectl port-forward deployment/mydeployment 5000 6000  # Listen on ports 5000 and 6000 locally, forwarding data to/from ports 5000 and 6000 in a pod selected by the deployment
kubectl port-forward service/myservice 5000 6000 # Listen on ports 5000 and 6000 locally, forwarding data to/from ports 5000 and 6000 in a pod selected by the service
kubectl port-forward --address localhost,10.19.21.23 pod/mypod 8888:5000 # Listen on port 8888 on localhost and selected IP, forwarding to 5000 in the pod
kubectl port-forward pod/mypod :5000 # Listen on a random port locally, forwarding to 5000 in the pod
kubectl port-forward --address 0.0.0.0 pod/mypod 8888:5000  # Listen on port 8888 on all addresses, forwarding to 5000 in the pod
```

#### label ve selector
```
kubectl get pods -l "app" --show-labels  #with -l, search label 
kubectl get pods -l "app=firstapp" --show-labels 
kubectl get pods -l "app=firstapp,tier=frontend" --show-labels
kubectl get pods -l "app in (firstapp)" --show-labels
kubectl get pods -l "!app" --show-labels  #list not app key
kubectl get pods -l "app notin (firstapp)" --show-labels  #inverse
kubectl get pods -l "app in (firstapp,secondapp)" --show-labels  #or 
kubectl get pods -l "app=firstapp,app=secondapp)" --show-labels  #and 
```

#### label addition
```
command (imperative): kubectl label pods pod9 app=thirdapp
command (imperative): kubectl label pods pod9 app-
kubectl label --overwrite pods pod9 team=team3   #overwrite
kubectl label pods --all foo=bar   # all pods, label addition
```

#### label node
- Node could be labelled (e.g. nodes have gpu, ssd, can be labelled)
```
kubectl label nodes minikube hddtype=ssd 
```

#### annotation
```
kubectl annotate pods annotationpod foo=bar ##annotate add
kubectl annotate pods annotationpod foo- ##annotate delete
```

#### namespace: object
```
kubectl get namespaces  
kubectl get pods #defaulttaki podlar
kubectl get pods --namespace kube-system #only kube-system
kubectl get pods -n kube-system #only kube-system
kubectl get pods --all-namespaces #all namespaces
kubectl get pods -A #all namespaces
kubectl exec -it namespacepod -n development -- /bin/sh #run terminal to add namespace
kubectl config set-context --current --namespace=development
kubectl config set-context --current --namespace=default
kubectl delete namespaces development
```

#### DEPLOYMENT: run more than 1 pod and synch
```
kubectl create deployment firstdeployment --image=nginx:latest --replicas=2
kubectl get deployment -w #always watch
kubectl get deployment
kubectl delete pods firstdeployment-pod 
kubectl set image deployment/firstdeployment nginx=httpd  # update containers on deployment
kubectl scale deployment firstdeployment --replicas=5  # manuel scale, increase/decrease replicas
kubectl delete deployment firstdeployment  # delete deployment
```

#### Deployment from file
- There should be at least one entry for spec/selector for each deployment to choose pod
- There should be same entries for template/metadata/labels/app and spec/selector/matchLabels/app for deployment-pod match
```
kubectl apply -f deploymenttemplate.yaml
```

#### rollout
```
kubectl rollout undo deployment firstdeployment # undo
```
  
#### record: save, return to desired revision
```
kubectl apply -f deployrolling.yaml --record
kubectl edit deployment rolldeployment --record 
kubectl set image deployment rolldeployment nginx=httpd:alpine --record=true 
kubectl rollout history deployment rolldeployment                  # show record history 
kubectl rollout history deployment rolldeployment --revision=2     # show 2.revision history
kubectl rollout undo deployment rolldeployment --to-revision=1     # roll to the first revision
```

#### live rollout commands logs on different terminal 
```
kubectl apply -f deployrolling.yaml
on another terminal: kubectl rollout status deployment rolldeployment -w 
kubectl rollout pause deployment rolldeployment   # pause the current deployment rollout/update
kubectl rollout resume deployment rolldeployment  # resume the current deployment rollout/update
```

#### service
- Service, --service-cluster-ip-range "10.100.0.0/16"
- 4 type Service object:
  - ClusterIP: direct traffic on the cluster
  - NodePort: node can be reachable from outside
  - LoadBalancer: load balancing
  - ExternalName
```
kubectl apply -f serviceClusterIP.yaml
kubectl get service -o wide
```
	  
#### service with command
```
kubectl expose deployment backend --type=ClusterIP --name=backend   #clusterIP type service creation
kubectl get service
kubectl expose deployment frontend --type=NodePort --name=frontend  #ndePort type service creation
kubectl get service 
```

#### service-endpoints
```
kubectl get endpoints                 # same endpoints created with services
kubectl describe endpoints frontend   # show ip adresses
kubectl delete pods frontend-xx-xx    # when pod deleted, ip also deleted 
kubectl scale deployment frontend --replicas=5    # new ip added
kubectl scale deployment frontend --replicas=2    
```

#### environment variables
```
spec:
  containers:
  - name: envpod
    image: ozgurozturknet/env:latest
    ports:
    - containerPort: 80
    env:
      - name: USER
        value: "Ozgur"
      - name: database
        value: "testdb.example.com"
```
```
kubectl apply -f podenv.yaml
kubectl get pods
kubectl exec envpod --  printenv  ## env. variable
kubectl exec -it firstpod -- /bin/sh
kubectl port-forward pod/envpod 8080:80  #port forwarding
kubectl delete -f podenv.yaml
```

#### volume
- ephemeral volume (temporary volume): it can be reachable from more than 1 container in the pod. When pod is deleted, volume is also deleted like cache.
- 2 types of ephmeral volume: 
 - 1.emptydir (create empty directory on the node, this volume is mounted on the container)
 - 2.hostpath: worker node (worker PC) with file path, more than one file or directory can be connected

##### emptydir volume:
```
  volumes:
  - name: cache-vol
    emptyDir: {}
```
	
##### container mount:
```
  - name: sidecar
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "sleep 3600"]
    volumeMounts:
    - name: cache-vol
      mountPath: /tmp/log
```
```
kubectl apply -f podvolumeemptydir.yaml
kubectl get pods -w
kubectl exec -it emptydir -c frontend -- bash
kubectl exec emptydir -c frontend -- rm -rf healthcheck #heltcheck siliniyor, container restart ediliyor.
```

##### hostpath type:
```
   containers:
    volumeMounts:
    - name: directory-vol
      mountPath: /dir1 (on container /dir1)
    - name: dircreate-vol
      mountPath: /cache (on container /cache)
    - name: file-vol
      mountPath: /cache/config.json     
	  
  volumes:
  - name: directory-vol
    hostPath:
      path: /tmp  (worker node /tmp directory, create Directory type volume)
      type: Directory 
  - name: dircreate-vol
    hostPath:
      path: /cache (worker node /cache directory, create DirectoryOrCreate type volume)
      type: DirectoryOrCreate
  - name: file-vol
    hostPath:
      path: /cache/config.json
      type: FileOrCreate
```
```
kubectl apply -f podvolumehostpath.yaml
kubectl exec -it hostpath -c hostpathcontainer -- bash
```


#### secret: declerative way
```
kubectl apply -f secret.yaml
kubectl get secrets
kubectl describe secret mysecret
```

#### secret: imperative (cmd)
```
kubectl create secret generic mysecret2 --from-literal=db_server=db.example.com --from-literal=db_username=admin --from-literal=db_password=P@ssw0rd!
kubectl create secret generic mysecret4 --from-file=config.json  #create config.json that inludes pass and username.
```

#### taint and toleration 
```
kubectl describe nodes minikube
kubectl taint node minikube platform=production:NoSchedule  #taint add
kubectl taint node minikube platform-   # taint delete
```

#### connect pod with bash and apt install
```
kubectl exec -it PodName -- bash
apt update
apt install net-tools
apt install iputils-ping
ifconfig
ping x.x.x.x
```

$md$, 20)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('69aef587-5dd0-51e8-a65c-17982422d74c', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which flag lists Pods across every namespace instead of just the current one?', 'beginner', 2, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('186764a5-af58-5c43-9dbf-5842b3d6fb94', '69aef587-5dd0-51e8-a65c-17982422d74c', 1, $json${"prompt":"Which flag lists Pods across every namespace instead of just the current one?","multiple":false,"options":[{"id":"a","text":"kubectl get pods -o wide","is_correct":false},{"id":"b","text":"kubectl get pods -A (or --all-namespaces)","is_correct":true},{"id":"c","text":"kubectl get pods -w","is_correct":false},{"id":"d","text":"kubectl get pods -n default","is_correct":false}],"explanation":"-A / --all-namespaces lists Pods across every namespace. -n \u003cnamespace\u003e restricts output\nto a single namespace (default is the \"default\" namespace if omitted). -o wide adds extra\ncolumns (like node and IP) but stays scoped to the current namespace. -w watches for\nchanges to the resources in the current namespace scope.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('53e1a8bb-8818-53a0-a857-cba2cc934472', '00000000-0000-0000-0000-000000000001', 'mcq', 'You need an interactive shell inside a Pod named `multicontainer` that has tw...', 'intermediate', 3, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ba8aacca-7a14-5880-8e3d-1bf301fdd35e', '53e1a8bb-8818-53a0-a857-cba2cc934472', 1, $json${"prompt":"You need an interactive shell inside a Pod named `multicontainer` that has two containers, `webcontainer` and `sidecarcontainer`. Which command opens a shell specifically in `sidecarcontainer`?","multiple":false,"options":[{"id":"a","text":"kubectl exec -it multicontainer -- /bin/sh","is_correct":false},{"id":"b","text":"kubectl exec -it multicontainer -c sidecarcontainer -- /bin/sh","is_correct":true},{"id":"c","text":"kubectl logs -f multicontainer -c sidecarcontainer","is_correct":false},{"id":"d","text":"kubectl port-forward pod/multicontainer -c sidecarcontainer","is_correct":false}],"explanation":"The -c \u003ccontainerName\u003e flag selects which container to target when a Pod runs more than\none container. Without -c, kubectl exec defaults to the Pod's first container. kubectl\nlogs -f -c streams logs rather than opening a shell, and port-forward does not accept a\n-c flag at all.\n"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('779da969-9e81-5590-806b-567455117471', '00000000-0000-0000-0000-000000000001', 'coding', 'You receive a simplified `kubectl get pods -A` listing, one Pod per line, in ...', 'intermediate', 5, ARRAY['kubernetes','k8s'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('16e9202d-00d0-57b0-97d6-c9aa18377dd8', '779da969-9e81-5590-806b-567455117471', 1, $json${"prompt":"You receive a simplified `kubectl get pods -A` listing, one Pod per line, in the form\n`NAMESPACE NAME PHASE`. Count how many Pods are NOT in the `kube-system` namespace and\nprint that count.\n\n**Example:**\n```\n4\nkube-system coredns-1 Running\ndefault web-1 Running\ndefault web-2 Pending\nkube-system etcd-1 Running\n```\nOutput: `2`\n","languages":["python","javascript"],"starter_code":{"javascript":"const lines = require('fs').readFileSync(0, 'utf8').trim().split('\\n');\nconst n = parseInt(lines[0]);\nlet count = 0;\nfor (let i = 1; i \u003c= n; i++) {\n  const parts = lines[i].trim().split(/\\s+/);\n  if (parts[0] !== 'kube-system') count++;\n}\nconsole.log(count);\n","python":"import sys\nlines = sys.stdin.read().split('\\n')\nn = int(lines[0])\ncount = 0\nfor i in range(1, n + 1):\n    parts = lines[i].split()\n    if parts[0] != 'kube-system':\n        count += 1\nprint(count)\n"},"time_limit_ms":2000,"memory_limit_kb":262144,"test_cases":[{"id":"t1","stdin":"4\nkube-system coredns-1 Running\ndefault web-1 Running\ndefault web-2 Pending\nkube-system etcd-1 Running\n","expected":"2","hidden":false,"weight":1},{"id":"t2","stdin":"1\ndefault single-pod Running\n","expected":"1","hidden":true,"weight":1},{"id":"t3","stdin":"5\nkube-system a Running\nkube-system b Running\nkube-system c Running\nproduction d Running\nproduction e Pending\n","expected":"2","hidden":true,"weight":1}]}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('f19146a6-348e-5f50-8d21-c9a44733ecee', '00000000-0000-0000-0000-000000000001', 'Quiz: kubectl Command Reference', 'k8s-reference-quiz', 'Quiz covering Reference.', 'mixed', 'published', 'module', 'a0585215-5511-5287-b2f5-b797846870be', 15, 60, 5, 10, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('872d1159-c4f2-5e38-97a7-524a0ca42f95', 'f19146a6-348e-5f50-8d21-c9a44733ecee', '69aef587-5dd0-51e8-a65c-17982422d74c', '186764a5-af58-5c43-9dbf-5842b3d6fb94', 0, 2),
('b317d89d-1627-5aeb-8fe3-5ccca1c1f394', 'f19146a6-348e-5f50-8d21-c9a44733ecee', '53e1a8bb-8818-53a0-a857-cba2cc934472', 'ba8aacca-7a14-5880-8e3d-1bf301fdd35e', 1, 3),
('15b86a65-428f-5fa7-85a2-d238bd88aaa2', 'f19146a6-348e-5f50-8d21-c9a44733ecee', '779da969-9e81-5590-806b-567455117471', '16e9202d-00d0-57b0-97d6-c9aa18377dd8', 2, 5)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('a0585215-5511-5287-b2f5-b797846870be', '36d5d8be-468e-5eb6-b650-0f5c827cb390', 'e4330df2-0c59-592e-be64-093765351ea3', 'Quiz: kubectl Command Reference', 'assessment', 1, 15, 'f19146a6-348e-5f50-8d21-c9a44733ecee')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('b76c3962-dcf2-5631-869c-8e2310f740dc', '00000000-0000-0000-0000-000000000014', '36d5d8be-468e-5eb6-b650-0f5c827cb390', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

