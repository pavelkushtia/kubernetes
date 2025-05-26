#!/bin/bash

# Build TweetStream Docker Images
set -e

echo "Building TweetStream Docker images..."

# Build API image
echo "Building API image..."
sudo docker build -t tweetstream/api:1.0.0 ./tweetstream/app-code/api

# Build Frontend image (new organized structure)
echo "Building Frontend image..."
cd helm-chart/tweetstream/app-code/frontend
sudo docker build -t tweetstream/frontend:2.0.0 .
cd ../../../../

echo "Frontend now has proper organized structure with separate HTML, CSS, JS files"

echo "Docker images built successfully!"
echo "Available images:"
sudo docker images | grep tweetstream 