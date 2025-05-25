#!/bin/bash

# Configure all nodes to trust the local Docker registry
set -e

REGISTRY_HOST="192.168.1.82:5555"
NODES=(
    "192.168.1.95"   # worker-node1
    "192.168.1.94"   # worker-node2
    "192.168.1.93"   # sanzad-ubuntu-21
    "192.168.1.104"  # sanzad-ubuntu-22
    "192.168.1.105"  # sanzad-ubuntu-23
)

echo "Configuring Docker registry trust on all worker nodes..."

for node in "${NODES[@]}"; do
    echo "Configuring node: $node"
    
    # Create Docker daemon config
    ssh -o StrictHostKeyChecking=no sanzad@$node "
        sudo mkdir -p /etc/docker
        echo '{\"insecure-registries\":[\"$REGISTRY_HOST\"]}' | sudo tee /etc/docker/daemon.json
        sudo systemctl restart docker || sudo systemctl start docker
        echo 'Node $node configured successfully'
    " || echo "Failed to configure node $node (might not be accessible)"
done

echo "Registry configuration completed!"
echo "Testing registry access from a worker node..."

# Test from first available node
for node in "${NODES[@]}"; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 sanzad@$node "docker pull $REGISTRY_HOST/tweetstream/api:1.0.0" 2>/dev/null; then
        echo "✅ Successfully pulled image from registry on node $node"
        break
    else
        echo "❌ Failed to pull from node $node"
    fi
done 