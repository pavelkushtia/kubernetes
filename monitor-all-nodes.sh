#!/bin/bash

echo "🔍 Monitoring All Worker Nodes Status"
echo "====================================="
echo "Expected nodes from inventory:"
echo "- master-node (192.168.1.82) ✅ Ready"
echo "- worker-node1 (192.168.1.95)"
echo "- worker-node2 (192.168.1.94)" 
echo "- sanzad-ubuntu-21 (192.168.1.93)"
echo "- sanzad-ubuntu-22 (192.168.1.104)"
echo "- sanzad-ubuntu-23 (192.168.1.105)"
echo ""
echo "Press Ctrl+C to stop monitoring"
echo ""

while true; do
    NODES=$(kubectl get nodes --no-headers | wc -l)
    READY_NODES=$(kubectl get nodes --no-headers | grep " Ready " | wc -l)
    
    echo "$(date): $READY_NODES/$NODES nodes ready (Expected: 6 total)"
    
    # Show current nodes
    kubectl get nodes --no-headers | while read line; do
        echo "  ✅ $line"
    done
    
    if [ $NODES -ge 6 ] && [ $READY_NODES -ge 6 ]; then
        echo ""
        echo "🎉 All nodes are online!"
        kubectl get nodes
        echo ""
        echo "✅ Ready to deploy TweetStream! Run: ./deploy-fresh.sh"
        break
    elif [ $NODES -gt 1 ]; then
        echo "  ⏳ Waiting for remaining worker nodes..."
    else
        echo "  ⏳ Waiting for worker nodes to rejoin cluster..."
    fi
    
    echo ""
    sleep 15
done 