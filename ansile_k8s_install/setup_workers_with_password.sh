#!/bin/bash

# Worker Node Setup Script with Password Handling
# This script sets up containerd and Kubernetes on new worker nodes

set -e

echo "🔧 Completing worker node setup..."

# Prompt for sudo password once
echo -n "Enter sudo password for remote nodes: "
read -s SUDO_PASSWORD
echo

# List of new worker nodes
WORKERS=("192.168.1.93" "192.168.1.104" "192.168.1.105")

for worker in "${WORKERS[@]}"; do
    echo "📦 Setting up containerd and Kubernetes on $worker..."
    
    ssh sanzad@$worker "echo '$SUDO_PASSWORD' | sudo -S bash -c '
        # Add Docker repository
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" > /etc/apt/sources.list.d/docker.list
        
        # Add Kubernetes repository
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo \"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /\" > /etc/apt/sources.list.d/kubernetes.list
        
        # Update package list
        apt update
        
        # Install containerd
        apt install -y containerd.io
        
        # Configure containerd
        mkdir -p /etc/containerd
        containerd config default > /etc/containerd/config.toml
        sed -i \"s/SystemdCgroup = false/SystemdCgroup = true/g\" /etc/containerd/config.toml
        systemctl restart containerd
        systemctl enable containerd
        
        # Install Kubernetes components
        apt install -y kubelet=1.28.0-1.1 kubeadm=1.28.0-1.1 kubectl=1.28.0-1.1
        apt-mark hold kubelet kubeadm kubectl
        
        # Enable kubelet
        systemctl enable kubelet
        
        echo \"✅ Setup completed on \$(hostname)\"
    '"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully set up $worker"
    else
        echo "❌ Failed to set up $worker"
        exit 1
    fi
done

echo "🎯 Getting join command from master..."
JOIN_COMMAND=$(kubeadm token create --print-join-command)

echo "🔗 Joining worker nodes to cluster..."
for worker in "${WORKERS[@]}"; do
    echo "Joining $worker to cluster..."
    ssh sanzad@$worker "echo '$SUDO_PASSWORD' | sudo -S $JOIN_COMMAND"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully joined $worker to cluster"
    else
        echo "❌ Failed to join $worker to cluster"
    fi
done

echo "✅ All worker nodes setup complete!"
echo "🔍 Checking cluster status..."
kubectl get nodes -o wide 