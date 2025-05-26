#!/bin/bash

# Fix Local Registry Configuration on All Nodes
# This configures all worker nodes to trust the local registry

set -e

REGISTRY_HOST="192.168.1.82:5555"

echo "🔧 Configuring local Docker registry on all nodes..."

# Get list of worker nodes
WORKER_NODES=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name" | grep -v master)

echo "📋 Found worker nodes: $WORKER_NODES"

# Function to configure a single node
configure_node() {
    local node=$1
    echo "🔧 Configuring node: $node"
    
    # Create Docker daemon configuration
    ssh $node 'sudo mkdir -p /etc/docker' || {
        echo "❌ Failed to create Docker directory on $node"
        return 1
    }
    
    # Configure Docker daemon for insecure registry
    ssh $node "sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  \"insecure-registries\": [\"$REGISTRY_HOST\"],
  \"log-driver\": \"json-file\",
  \"log-opts\": {
    \"max-size\": \"10m\",
    \"max-file\": \"3\"
  }
}
EOF" || {
        echo "❌ Failed to configure Docker daemon on $node"
        return 1
    }
    
    # Restart Docker service
    ssh $node 'sudo systemctl restart docker' || {
        echo "❌ Failed to restart Docker on $node"
        return 1
    }
    
    # Wait for Docker to be ready
    sleep 5
    
    # Test registry connectivity
    echo "🧪 Testing registry connectivity on $node..."
    if ssh $node "docker pull $REGISTRY_HOST/tweetstream/api:1.0.0" 2>/dev/null; then
        echo "✅ Registry pull test SUCCESS on $node"
        return 0
    else
        echo "⚠️  Registry pull test FAILED on $node (images may not be pushed yet)"
        return 0  # Don't fail if images aren't pushed yet
    fi
}

# Configure each worker node
success_count=0
total_nodes=0

for node in $WORKER_NODES; do
    total_nodes=$((total_nodes + 1))
    if configure_node $node; then
        success_count=$((success_count + 1))
    fi
    echo ""
done

echo "📊 Configuration Summary:"
echo "   Total nodes: $total_nodes"
echo "   Successful: $success_count"
echo "   Failed: $((total_nodes - success_count))"

if [ $success_count -eq $total_nodes ]; then
    echo "🎉 Local registry is now properly configured on all nodes!"
    exit 0
else
    echo "⚠️  Some nodes failed configuration. Check the output above."
    exit 1
fi 