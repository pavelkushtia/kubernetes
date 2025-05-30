#!/bin/bash

# Build TweetStream Docker Images
set -e

echo "Building TweetStream Docker images..."

# Build API image
echo "Building API image..."
sudo docker build -t tweetstream/api:1.0.0 ./helm-chart/tweetstream/app-code/api

# Build Frontend image (new organized structure)
echo "Building Frontend image..."
sudo docker build -t tweetstream/frontend:2.2.0 ./helm-chart/tweetstream/app-code/frontend

echo "Frontend now has proper organized structure with authentication, tweeting, and following features"

echo "Docker images built successfully!"
echo "Available images:"
sudo docker images | grep tweetstream 