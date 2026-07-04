---
kind: lesson
id_key: k8s/cluster-ops/lesson
course: fast-kubernetes
section: cluster-ops
section_title: Cluster Setup & Operations
section_position: 7
title: Cluster Setup & Operations
position: 0
estimated_minutes: 60
source:
    - K8s-Kubeadm-Cluster-Setup.md
    - K8s-Kubeadm-Cluster-Docker.md
    - K8s-Enable-Dashboard-On-Cluster.md
    - create_real_cluster/ubuntu20.04-kubeadm1.26.2-calico3.25.0-containerd1.6.10/install.sh
    - create_real_cluster/ubuntu20.04-kubeadm1.26.2-calico3.25.0-containerd1.6.10/master.sh
    - create_real_cluster/ubuntu24.04-kubeadm1.32.0-calico3.29.1-containerd1.7.24/install-ubuntu24.04-k8s1.32.sh
    - create_real_cluster/ubuntu24.04-kubeadm1.32.0-calico3.29.1-containerd1.7.24/master-ubuntu24.04-k8s1.32.sh
    - create_real_cluster/win2019-kubeadm1.26.2-calico3.25.0-docker/install-docker-ce.ps1
    - create_real_cluster/win2019-kubeadm1.26.2-calico3.25.0-docker/install1.ps1
    - create_real_cluster/win2019-kubeadm1.26.2-calico3.25.0-docker/install2.ps1
    - create_real_cluster/win2022-kubeadm1.32.0-calico3.29.1-containerd1.7.24/install1.ps1
    - create_real_cluster/win2022-kubeadm1.32.0-calico3.29.1-containerd1.7.24/install2.ps1
---

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
