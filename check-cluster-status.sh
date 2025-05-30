#!/bin/bash

# Quick Cluster Status Check Script

echo "🔍 Kubernetes Cluster Status Check"
echo "=================================="

echo "📋 Current Cluster Nodes:"
kubectl get nodes -o wide

echo ""
echo "🔧 System Pods Status:"
kubectl get pods -n kube-system

echo ""
echo "🌐 CNI Status:"
kubectl get pods -n kube-flannel

echo ""
echo "📊 Node Connectivity Test:"
WORKERS=(
    "192.168.1.95:worker-node1"
    "192.168.1.94:worker-node2" 
    "192.168.1.93:sanzad-ubuntu-21"
    "192.168.1.104:sanzad-ubuntu-22"
    "192.168.1.105:sanzad-ubuntu-23"
)

for worker in "${WORKERS[@]}"; do
    IFS=':' read -r ip name <<< "$worker"
    if ping -c 1 -W 2 $ip >/dev/null 2>&1; then
        echo "  ✅ $name ($ip) - Reachable"
    else
        echo "  ❌ $name ($ip) - Not reachable"
    fi
done

echo ""
echo "🎯 Cluster Summary:"
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
READY_NODES=$(kubectl get nodes --no-headers | grep " Ready " | wc -l)
echo "  - Total nodes: $TOTAL_NODES"
echo "  - Ready nodes: $READY_NODES"
echo "  - Expected nodes: 6 (1 master + 5 workers)"

if [ $READY_NODES -eq 6 ]; then
    echo ""
    echo "🎉 All nodes are ready! Cluster is fully operational."
    echo "✅ Ready to deploy TweetStream!"
elif [ $READY_NODES -gt 1 ]; then
    echo ""
    echo "⏳ Some worker nodes are still joining..."
    echo "💡 Run './rejoin-all-workers.sh' if nodes are stuck"
else
    echo ""
    echo "⚠️  Only master node is ready. Worker nodes need to join."
    echo "💡 Run './rejoin-all-workers.sh' to rejoin all workers"
fi 