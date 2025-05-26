#!/bin/bash

# Push TweetStream images to GitHub Container Registry
# This provides a proper, production-ready image distribution solution

set -e

# Configuration
GITHUB_USERNAME="pavelkushtia"  # Replace with your GitHub username
REGISTRY="ghcr.io"
NAMESPACE="$GITHUB_USERNAME"

echo "🚀 Pushing TweetStream images to GitHub Container Registry..."
echo "Registry: $REGISTRY/$NAMESPACE"

# Check if user is logged in to GHCR
if ! sudo docker info | grep -q "ghcr.io"; then
    echo "⚠️  Please login to GitHub Container Registry first:"
    echo "   1. Create a Personal Access Token with 'write:packages' scope"
    echo "   2. Run: echo \$GITHUB_TOKEN | sudo docker login ghcr.io -u $GITHUB_USERNAME --password-stdin"
    echo ""
    read -p "Press Enter after logging in..."
fi

# Tag images for GHCR
echo "📦 Tagging images for GitHub Container Registry..."
sudo docker tag tweetstream/api:1.0.0 $REGISTRY/$NAMESPACE/tweetstream-api:1.0.0
sudo docker tag tweetstream/frontend:2.0.0 $REGISTRY/$NAMESPACE/tweetstream-frontend:2.0.0

# Push images
echo "⬆️  Pushing API image..."
sudo docker push $REGISTRY/$NAMESPACE/tweetstream-api:1.0.0

echo "⬆️  Pushing Frontend image..."
sudo docker push $REGISTRY/$NAMESPACE/tweetstream-frontend:2.0.0

echo "✅ Images successfully pushed to GitHub Container Registry!"
echo ""
echo "📋 Update your values.yaml with:"
echo "global:"
echo "  imageRegistry: \"$REGISTRY/$NAMESPACE\""
echo ""
echo "api:"
echo "  image:"
echo "    repository: tweetstream-api"
echo "    tag: \"1.0.0\""
echo ""
echo "frontend:"
echo "  image:"
echo "    repository: tweetstream-frontend"
echo "    tag: \"2.0.0\"" 