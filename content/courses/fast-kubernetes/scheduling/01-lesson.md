---
kind: lesson
id_key: k8s/scheduling/lesson
course: fast-kubernetes
section: scheduling
section_title: Health & Scheduling
section_position: 6
title: Health & Scheduling
position: 0
estimated_minutes: 45
source:
    - K8s-Liveness-App.md
    - K8s-Node-Affinity.md
    - K8s-Taint-Toleration.md
---

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
