---
kind: lesson
id_key: k8s/pod-fundamentals/lesson
course: fast-kubernetes
section: pod-fundamentals
section_title: Pod Fundamentals
section_position: 1
title: Pod Fundamentals
position: 0
estimated_minutes: 45
source:
    - K8s-CreatingPod-Imperative.md
    - K8-CreatingPod-Declerative.md
    - K8s-Multicontainer-Sidecar.md
---

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
