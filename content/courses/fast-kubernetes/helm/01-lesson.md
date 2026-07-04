---
kind: lesson
id_key: k8s/helm/lesson
course: fast-kubernetes
section: helm
section_title: Helm & Packaging
section_position: 8
title: Helm & Packaging
position: 0
estimated_minutes: 45
source:
    - Helm.md
    - HelmCheatsheet.md
    - K8s-Helm-Jenkins.md
---

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


