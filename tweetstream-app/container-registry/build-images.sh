#!/bin/bash

# Build TweetStream Docker Images
set -e

echo "Building TweetStream Docker images..."

# Build API image
echo "Building API image..."
sudo docker build -t tweetstream/api:1.0.0 ./tweetstream/app-code/api

# Note: Frontend is deployed using Python-based approach from improved-frontend.yaml
# The nginx-based frontend in app-code/frontend is broken and not used
echo "Frontend deployment uses Python-based approach (see improved-frontend.yaml)"
echo "Skipping nginx-based frontend build (broken/unused)"

echo "Docker images built successfully!"
echo "Available images:"
sudo docker images | grep tweetstream 