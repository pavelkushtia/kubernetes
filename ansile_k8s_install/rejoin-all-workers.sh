#!/bin/bash

# Rejoin All Worker Nodes Script
# This script rejoins all worker nodes to the cluster after reboot/disconnect

set -e

echo "🔗 Rejoining All Worker Nodes to Kubernetes Cluster"
echo "===================================================="

# List of ALL worker nodes from inventory
WORKERS=(
    "192.168.1.95:worker-node1"
    "192.168.1.94:worker-node2" 
    "192.168.1.93:sanzad-ubuntu-21"
    "192.168.1.104:sanzad-ubuntu-22"
    "192.168.1.105:sanzad-ubuntu-23"
)

echo "📋 Worker nodes to rejoin:"
for worker in "${WORKERS[@]}"; do
    IFS=':' read -r ip name <<< "$worker"
    echo "  - $name ($ip)"
done
echo ""

# Prompt for sudo password once
echo -n "Enter sudo password for remote nodes: "
read -s SUDO_PASSWORD
echo ""

echo "🎯 Generating fresh join command from master..."
JOIN_COMMAND=$(kubeadm token create --print-join-command)
echo "Join command: $JOIN_COMMAND"
echo ""

echo "🔗 Rejoining worker nodes to cluster..."
for worker in "${WORKERS[@]}"; do
    IFS=':' read -r ip name <<< "$worker"
    echo "Processing $name ($ip)..."
    
    # Check if node is reachable
    if ! ping -c 1 -W 2 $ip >/dev/null 2>&1; then
        echo "  ⚠️  $name ($ip) is not reachable, skipping..."
        continue
    fi
    
    # Reset any existing cluster configuration
    echo "  🧹 Resetting existing cluster config on $name..."
    ssh -o ConnectTimeout=10 sanzad@$ip "echo '$SUDO_PASSWORD' | sudo -S bash -c '
        kubeadm reset -f --cri-socket unix:///var/run/containerd/containerd.sock 2>/dev/null || true
        rm -rf /etc/kubernetes/kubelet.conf 2>/dev/null || true
        systemctl restart kubelet 2>/dev/null || true
    '" 2>/dev/null || echo "    (Reset completed with some expected errors)"
    
    # Join to cluster
    echo "  🔗 Joining $name to cluster..."
    ssh -o ConnectTimeout=10 sanzad@$ip "echo '$SUDO_PASSWORD' | sudo -S $JOIN_COMMAND" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "  ✅ Successfully joined $name to cluster"
    else
        echo "  ❌ Failed to join $name to cluster"
    fi
    echo ""
done

echo "⏳ Waiting for nodes to become ready..."
sleep 10

echo "🔍 Checking cluster status..."
kubectl get nodes -o wide

echo ""
echo "✅ Worker node rejoin process complete!"
echo "🎯 Ready to deploy TweetStream once all nodes show as 'Ready'" 