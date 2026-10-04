---
kind: lesson
id_key: k8s/cluster-ops/lesson
course: fast-kubernetes
section: cluster-ops
section_title: 'Real Clusters: Setup, Security and Operations'
section_position: 10
title: Building a Cluster with kubeadm
position: 0
estimated_minutes: 50
source:
  - K8s-Kubeadm-Cluster-Setup.md
  - K8s-Kubeadm-Cluster-Docker.md
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

Until now you used a cluster someone else built. This lesson shows how a real multi-node cluster is put together with **kubeadm**, the official tool for bootstrapping Kubernetes on your own machines. Even if you will use a managed service at work, knowing these steps explains what every node is actually running, and it is a common interview topic.

## Managed or self-managed?

| | Managed (EKS, GKE, AKS) | Self-managed (kubeadm, k3s, RKE2) |
|---|---|---|
| Control plane | Run, patched and backed up by the provider | You install, upgrade and back it up |
| Cost | Control-plane fee plus nodes | Only the machines, plus your time |
| Control | Less (provider picks some versions and add-ons) | Full |
| Typical use | Most companies in the cloud | On-premises, edge, air-gapped, learning |

**For production in the cloud, choose managed unless you have a strong reason not to.** Running etcd and control-plane upgrades yourself is real operational work.

The plan for the rest of this lesson: 1 control-plane node + workers, Ubuntu, containerd as the runtime, Calico as the network plugin. You can create the VMs locally with **Multipass**:

```bash
multipass launch --name master  -c 2 -m 2G -d 10G     # 2 CPUs, 2 GB RAM, 10 GB disk
multipass launch --name worker1 -c 2 -m 2G -d 10G
multipass shell master
```

The minimum per node is 2 CPUs and 2 GB of RAM for the control plane. Nodes need unique hostnames and MAC addresses, and full network connectivity between them.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-choice-q1", "type": "mcq",
    "prompt": "With a managed service like EKS or GKE, which of these do you NOT have to do yourself?",
    "options": [
      {"id": "a", "text": "Deploy your applications"},
      {"id": "b", "text": "Back up and upgrade etcd and the API server"},
      {"id": "c", "text": "Choose node sizes"},
      {"id": "d", "text": "Write Deployments and Services"}
    ],
    "correct": "b",
    "explanation": "The provider operates the control plane, including etcd. You still own your workloads and usually your node pools." }
] }
```

## Step 1: prepare every node

Run on **all** nodes (control plane and workers).

**Turn off swap.** By default the kubelet refuses to start with swap on, because it makes memory limits unpredictable.

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab        # keep it off after reboot
```

**Load kernel modules and enable forwarding**, so pod traffic can cross the node's bridge and be routed:

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
```

**Behind a corporate proxy?** Set `http_proxy`, `https_proxy` and `no_proxy` (in `/etc/environment` and for containerd's systemd service). `no_proxy` must include the node IPs, the pod and service CIDRs, and the API server address, or nodes will try to reach each other through the proxy.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-prep-q1", "type": "mcq",
    "prompt": "Why does kubeadm's preflight check complain when swap is enabled?",
    "options": [
      {"id": "a", "text": "Swap makes the disk too slow for etcd"},
      {"id": "b", "text": "By default the kubelet requires swap off, because swapping makes memory requests and limits unreliable"},
      {"id": "c", "text": "Swap is needed only on Windows"},
      {"id": "d", "text": "Swap conflicts with Calico"}
    ],
    "correct": "b",
    "explanation": "Kubernetes' memory accounting assumes no swap unless swap support is explicitly configured." }
] }
```

## Step 2: install the container runtime (containerd)

On all nodes:

```bash
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
# IMPORTANT: use the systemd cgroup driver, the same one the kubelet uses
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

The `SystemdCgroup = true` line matters. If containerd and the kubelet use different cgroup drivers, pods restart randomly and the control plane becomes unstable. It is one of the most common broken-cluster causes.

**Docker as the runtime?** Kubernetes removed its built-in Docker support ("dockershim") in 1.24. You can still build images with Docker, and those images run fine on containerd. To keep Docker Engine as the runtime you would need the extra `cri-dockerd` adapter, which new clusters rarely use.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-runtime-q1", "type": "mcq",
    "prompt": "After Kubernetes removed dockershim, can images built with `docker build` still run on a containerd-based cluster?",
    "options": [
      {"id": "a", "text": "No, they must be rebuilt with containerd"},
      {"id": "b", "text": "Yes, they are standard OCI images that any runtime can run"},
      {"id": "c", "text": "Only on Windows nodes"},
      {"id": "d", "text": "Only if Docker is also installed on every node"}
    ],
    "correct": "b",
    "explanation": "Docker builds OCI-compliant images. Removing dockershim only changed which runtime starts containers on nodes." }
] }
```

## Step 3: install kubeadm, kubelet and kubectl

On all nodes. Packages come from the community repository `pkgs.k8s.io`, which has one repository per minor version. (The old `apt.kubernetes.io` repository is frozen; guides that still use it no longer work.) Replace `v1.33` with the version you want:

```bash
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl     # never upgrade these by accident with apt upgrade
sudo systemctl enable --now kubelet
```

- **kubeadm** bootstraps the cluster.
- **kubelet** is the node agent. It restarts in a loop until kubeadm configures it; that is expected.
- **kubectl** is the client. It is only really needed where you run commands.

`apt-mark hold` matters: Kubernetes upgrades follow a specific order (next lesson), and a random `apt upgrade` must not jump versions.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-install-q1", "type": "mcq",
    "prompt": "Why run `apt-mark hold kubelet kubeadm kubectl`?",
    "options": [
      {"id": "a", "text": "To make them start faster"},
      {"id": "b", "text": "So routine OS updates cannot upgrade Kubernetes components out of the planned upgrade order"},
      {"id": "c", "text": "It is required by Calico"},
      {"id": "d", "text": "To hide them from other users"}
    ],
    "correct": "b",
    "explanation": "Kubernetes must be upgraded deliberately (control plane first, one minor version at a time)." }
] }
```

## Step 4: create the control plane

On the **control-plane node** only:

```bash
sudo kubeadm config images pull
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=<MASTER_IP> \
  --control-plane-endpoint=<MASTER_IP>
```

- `--pod-network-cidr` is the IP range for pods. It must match the network plugin's setting and must not overlap your real network. (`192.168.0.0/16` is Calico's default; if your LAN already uses 192.168.x.x, choose e.g. `10.244.0.0/16` and configure Calico to match.)
- `--control-plane-endpoint` should be a stable address. For a highly available cluster it is a load balancer or DNS name in front of several control-plane nodes.

kubeadm generates certificates, writes static pod manifests for etcd, kube-apiserver, kube-controller-manager and kube-scheduler (in `/etc/kubernetes/manifests`, run by the kubelet), and prints two important things: how to set up kubectl, and a **join command**.

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes          # the master is NotReady: no network plugin yet
```

`admin.conf` is a full cluster-admin credential. Treat it like a root password.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-init-q1", "type": "mcq",
    "prompt": "Right after `kubeadm init`, the control-plane node shows NotReady. What is usually missing?",
    "options": [
      {"id": "a", "text": "A worker node"},
      {"id": "b", "text": "A CNI network plugin such as Calico or Flannel"},
      {"id": "c", "text": "A Helm installation"},
      {"id": "d", "text": "An Ingress controller"}
    ],
    "correct": "b",
    "explanation": "Nodes stay NotReady until a network plugin is installed and pods can get IPs." },
  { "id": "k8s-kubeadm-init-q2", "type": "mcq",
    "prompt": "How do the control-plane components run on a kubeadm cluster?",
    "options": [
      {"id": "a", "text": "As systemd services installed by apt"},
      {"id": "b", "text": "As static pods, defined by files in /etc/kubernetes/manifests and started by the kubelet"},
      {"id": "c", "text": "As a Deployment in the default namespace"},
      {"id": "d", "text": "Inside the Calico pods"}
    ],
    "correct": "b",
    "explanation": "kubeadm writes static pod manifests; the kubelet runs them directly. You see them in kube-system as mirror pods." }
] }
```

## Step 5: install the network plugin (CNI)

Pods cannot talk to each other until a **CNI plugin** is installed. Calico (which also supports NetworkPolicy):

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml
watch kubectl get pods -n calico-system      # wait until all Running
kubectl get nodes                            # now Ready
```

Other common choices: **Cilium** (eBPF-based, strong NetworkPolicy and observability) and **Flannel** (simple, but no NetworkPolicy). Check the plugin's docs for the current version. Its manifest URLs change between releases.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-cni-q1", "type": "mcq",
    "prompt": "You need NetworkPolicy enforcement. Which CNI choice would NOT give you that on its own?",
    "options": [
      {"id": "a", "text": "Calico"},
      {"id": "b", "text": "Cilium"},
      {"id": "c", "text": "Flannel"},
      {"id": "d", "text": "All of them enforce it"}
    ],
    "correct": "c",
    "explanation": "Plain Flannel only provides connectivity. NetworkPolicy objects are accepted but not enforced." }
] }
```

## Step 6: join worker nodes

Think of this join command as a guest Wi-Fi password: it lets a new device onto the network, but it expires after a day so it cannot be reused by just anyone who once saw it. On each **worker**, run the join command that `kubeadm init` printed:

```bash
sudo kubeadm join <MASTER_IP>:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

Tokens expire after **24 hours**. To join a node later, create a fresh command on the control plane:

```bash
kubeadm token create --print-join-command
kubeadm token list
```

(If you ever need the CA hash by hand: `openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'`.)

Add `--control-plane --certificate-key <key>` to join an additional **control-plane** node for high availability. Run an **odd number** of control-plane nodes (3 or 5) so etcd keeps a majority (quorum) when one fails.

```bash
kubectl get nodes -o wide        # all nodes Ready
kubectl label node worker1 node-role.kubernetes.io/worker=     # optional: show a ROLE
```

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-join-q1", "type": "mcq",
    "prompt": "A week after setting up the cluster you want to add a worker, but the original join token no longer works. What do you do?",
    "options": [
      {"id": "a", "text": "Reinstall the cluster"},
      {"id": "b", "text": "Run `kubeadm token create --print-join-command` on the control plane and use the new command"},
      {"id": "c", "text": "Copy admin.conf to the worker"},
      {"id": "d", "text": "Restart the kubelet on the master"}
    ],
    "correct": "b",
    "explanation": "Bootstrap tokens expire (24h by default). Creating a new one prints a ready-to-use join command." },
  { "id": "k8s-kubeadm-join-q2", "type": "mcq",
    "prompt": "Why run 3 control-plane nodes instead of 2?",
    "options": [
      {"id": "a", "text": "etcd needs a majority; with 3 members one can fail and 2 still form a majority, with 2 members losing one stops the cluster"},
      {"id": "b", "text": "kubeadm refuses even numbers"},
      {"id": "c", "text": "The scheduler needs three copies"},
      {"id": "d", "text": "It doubles the pod capacity"}
    ],
    "correct": "a",
    "explanation": "etcd quorum is floor(n/2)+1. Two members tolerate zero failures, three tolerate one, five tolerate two." }
] }
```

## Private registries, NFS storage and Windows nodes

**Private image registry.** Real clusters pull company images from a private registry (Harbor, GitLab, ECR, ACR, GCR). The clean way is a registry with a proper TLS certificate plus an `imagePullSecrets` credential (Secrets lesson). For a quick lab registry you can run one yourself:

```bash
docker run -d -p 5000:5000 --restart always --name localregistry registry:2
docker tag myapp:1.0 <MASTER_IP>:5000/myapp:1.0
docker push <MASTER_IP>:5000/myapp:1.0
```

A registry without TLS must be explicitly trusted by containerd on every node (in `/etc/containerd/certs.d/<host:port>/hosts.toml`, then restart containerd). Only do this in labs; in production always use TLS.

**NFS for PersistentVolumes.** On-premises clusters often use an NFS server for shared (RWX) storage. Install `nfs-common` on every node, then either create NFS PVs by hand (Storage lesson) or install the **csi-driver-nfs** (or nfs-subdir-external-provisioner) chart so PVCs get NFS volumes automatically through a StorageClass.

**Windows worker nodes.** Kubernetes can schedule Windows containers on Windows Server 2019/2022 worker nodes. The control plane is always Linux. Windows nodes use containerd, need a CNI that supports Windows (Calico, Flannel with host-gw/VXLAN), and need a `nodeSelector: kubernetes.io/os: windows` on Windows pods, so that Linux pods never land there and vice versa.

**Control-plane IP changed?** kubeadm bakes the API server address into certificates and kubeconfigs. Give control-plane nodes **static IPs or a DNS name** from day one. If the IP does change in a lab, the quick (destructive) fix is `sudo kubeadm reset` on every node, `kubeadm init` again, reinstall the CNI, and re-join the workers.

```knowledge-check
{ "questions": [
  { "id": "k8s-kubeadm-extra-q1", "type": "mcq",
    "prompt": "A mixed cluster has Linux and Windows workers. How do you make sure a Windows container image is only scheduled on Windows nodes?",
    "options": [
      {"id": "a", "text": "It happens automatically for every image"},
      {"id": "b", "text": "Add nodeSelector kubernetes.io/os: windows to the pod spec"},
      {"id": "c", "text": "Run it as a DaemonSet"},
      {"id": "d", "text": "Put it in the kube-system namespace"}
    ],
    "correct": "b",
    "explanation": "Every node carries the kubernetes.io/os label. Selecting it keeps pods on nodes with the matching OS." }
] }
```

## Interview questions and real-world scenarios

**Q: Walk me through creating a cluster with kubeadm.**
Prepare nodes (swap off, kernel modules, sysctl), install containerd with SystemdCgroup, install kubeadm/kubelet/kubectl from pkgs.k8s.io and hold them, `kubeadm init` on the control plane, set up kubeconfig, install a CNI, `kubeadm join` the workers.

**Q: What does kubeadm init actually create?**
Certificates (PKI), kubeconfigs, static pod manifests for etcd and the control plane, the kubelet config, CoreDNS and kube-proxy add-ons, and a bootstrap token for joins.

**Q: Why did Kubernetes remove dockershim, and what changed for users?**
Kubernetes talks to runtimes through CRI; Docker Engine didn't implement CRI, so a shim had to be maintained. Clusters now use containerd or CRI-O directly. Images built with Docker still work unchanged.

**Q: How do you make the control plane highly available?**
3 (or 5) control-plane nodes behind a load balancer (`--control-plane-endpoint`), with stacked or external etcd. Odd member count for quorum.

**Q: Managed vs self-managed Kubernetes?**
Managed removes control-plane operations (etcd, upgrades, HA) at a small cost; self-managed gives full control and suits on-prem, edge or air-gapped setups.

**Real-world scenario: pods on a new kubeadm cluster restart randomly every few minutes.**
Classic cgroup-driver mismatch: containerd was left with `SystemdCgroup = false`. Fix the config on every node and restart containerd and the kubelet.

**Real-world scenario: a new node joins but stays NotReady.**
Check `journalctl -u kubelet`. Usual causes: no CNI pods on that node (check the CNI DaemonSet), firewall blocking required ports (6443, 10250, CNI ports), or swap still on.

```knowledge-check
{
  "questions": [
    {
      "id": "k8s-kubeadm-int-q1",
      "type": "mcq",
      "prompt": "A freshly built kubeadm cluster has pods restarting randomly and etcd complaining. What should you check first?",
      "options": [
        {
          "id": "a",
          "text": "The Helm version"
        },
        {
          "id": "b",
          "text": "That containerd uses SystemdCgroup = true, matching the kubelet's cgroup driver"
        },
        {
          "id": "c",
          "text": "The Ingress class"
        },
        {
          "id": "d",
          "text": "The HPA settings"
        }
      ],
      "correct": "b",
      "explanation": "A cgroup driver mismatch is the classic cause of this instability."
    }
  ]
}
```
