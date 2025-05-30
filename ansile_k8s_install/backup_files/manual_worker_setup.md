# Manual Worker Node Setup Guide

Since the Ansible playbook completed most of the system configuration but failed at containerd installation, you can complete the setup manually by running these commands on each new worker node.

## Step 1: SSH to each worker node and run these commands

For each node (192.168.1.93, 192.168.1.104, 192.168.1.105), SSH to the node and run:

```bash
ssh sanzad@192.168.1.93  # Replace with each IP
```

## Step 2: Install containerd and Kubernetes (run on each worker node)

```bash
# Add Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

# Add Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package list
sudo apt update

# Install containerd
sudo apt install -y containerd.io

# Configure containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Install Kubernetes components
sudo apt install -y kubelet=1.28.0-1.1 kubeadm=1.28.0-1.1 kubectl=1.28.0-1.1
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet
sudo systemctl enable kubelet

echo "✅ Setup completed on $(hostname)"
```

## Step 3: Get join command from master node

On the master node, run:

```bash
kubeadm token create --print-join-command
```

Copy the output (it will look like):
```
kubeadm join 192.168.1.82:6443 --token abc123.xyz789 --discovery-token-ca-cert-hash sha256:abcd1234...
```

## Step 4: Join each worker to the cluster

On each worker node, run the join command with sudo:

```bash
sudo kubeadm join 192.168.1.82:6443 --token abc123.xyz789 --discovery-token-ca-cert-hash sha256:abcd1234...
```

## Step 5: Verify cluster status

Back on the master node, check the cluster:

```bash
kubectl get nodes -o wide
```

You should see all 6 nodes (1 master + 5 workers) in Ready status.

## Alternative: Quick Script Approach

If you prefer, you can create this script on each worker node and run it:

```bash
# Save this as setup.sh on each worker node
#!/bin/bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y containerd.io kubelet=1.28.0-1.1 kubeadm=1.28.0-1.1 kubectl=1.28.0-1.1
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd && sudo systemctl enable containerd
sudo systemctl enable kubelet
sudo apt-mark hold kubelet kubeadm kubectl
echo "Ready to join cluster!"

# Then run: chmod +x setup.sh && ./setup.sh
``` 