#!/bin/bash

# Push TweetStream images to Local Registry
set -e

# Configuration
LOCAL_REGISTRY="192.168.1.82:5555"

echo "🚀 Pushing TweetStream images to Local Registry..."
echo "Registry: $LOCAL_REGISTRY"

# Tag images for local registry
echo "📦 Tagging images for Local Registry..."
sudo docker tag tweetstream/api:1.0.0 $LOCAL_REGISTRY/tweetstream/api:1.0.0
sudo docker tag tweetstream/frontend:2.2.0 $LOCAL_REGISTRY/tweetstream/frontend:2.2.0

# Push images
echo "⬆️  Pushing API image..."
sudo docker push $LOCAL_REGISTRY/tweetstream/api:1.0.0

echo "⬆️  Pushing Frontend image..."
sudo docker push $LOCAL_REGISTRY/tweetstream/frontend:2.2.0

echo "✅ Images successfully pushed to Local Registry!"
echo ""
echo "📋 Images available at:"
echo "- $LOCAL_REGISTRY/tweetstream/api:1.0.0"
echo "- $LOCAL_REGISTRY/tweetstream/frontend:2.2.0" 