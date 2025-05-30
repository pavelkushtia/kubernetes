#!/bin/bash

echo "🚀 TweetStream Fresh Deployment Script"
echo "======================================="

# Check if worker nodes are ready
echo "📋 Checking node status..."
kubectl get nodes

# Wait for worker nodes to be ready
echo "⏳ Waiting for all nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

if [ $? -ne 0 ]; then
    echo "❌ Not all nodes are ready. Please check node status."
    exit 1
fi

echo "✅ All nodes are ready!"

# Create namespace if it doesn't exist
echo "📦 Creating namespace..."
kubectl create namespace tweetstream --dry-run=client -o yaml | kubectl apply -f -

# Install TweetStream with corrected values
echo "🚀 Installing TweetStream with production values..."
helm install tweetstream ./tweetstream -f tweetstream/values-prod-fixed.yaml -n tweetstream

if [ $? -eq 0 ]; then
    echo "✅ TweetStream installation initiated successfully!"
    echo ""
    echo "📊 Monitoring deployment status..."
    echo "Run: kubectl get pods -n tweetstream -w"
    echo ""
    echo "🌐 Once ready, access the application at:"
    echo "http://tweetstream.192.168.1.82.nip.io"
else
    echo "❌ Installation failed. Check the error messages above."
    exit 1
fi 