#!/bin/bash

# Build TweetStream Docker Images
set -e

echo "Building TweetStream Docker images..."

# Build API image
echo "Building API image..."
sudo docker build -t tweetstream/api:1.0.0 ./tweetstream/app-code/api

# Build Frontend image  
echo "Building Frontend image..."
sudo docker build -t tweetstream/frontend:1.0.0 ./tweetstream/app-code/frontend

echo "Docker images built successfully!"
echo "Available images:"
sudo docker images | grep tweetstream 