---
kind: lesson
id_key: k8s/workloads/lesson
course: fast-kubernetes
section: workloads
section_title: Workloads & Controllers
section_position: 2
title: Workloads & Controllers
position: 0
estimated_minutes: 90
source:
    - K8s-Deployment.md
    - K8s-Rollout-Rollback.md
    - K8s-Daemon-Sets.md
    - K8s-Statefulset.md
    - K8s-Job.md
    - K8s-CronJob.md
---

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
