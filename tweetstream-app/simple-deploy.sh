#!/bin/bash

# Simple TweetStream Deployment Script
# Uses local registry with smart fallback

set -e

NAMESPACE="tweetstream"
HELM_CHART_PATH="helm-chart/tweetstream"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🚀 TweetStream Simple Deployment"
echo "================================"

# Check prerequisites
log_info "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    log_error "helm not found"
    exit 1
fi

if [ ! -d "$HELM_CHART_PATH" ]; then
    log_error "Helm chart not found at $HELM_CHART_PATH"
    exit 1
fi

log_success "Prerequisites OK"

# Check if local registry is running
log_info "Checking local registry..."
if curl -s http://192.168.1.82:5555/v2/_catalog | grep -q "tweetstream"; then
    log_success "Local registry is running with TweetStream images"
    USE_REGISTRY=true
else
    log_warning "Local registry not accessible, will use local images only"
    USE_REGISTRY=false
fi

# Create deployment values
log_info "Creating deployment configuration..."

if [ "$USE_REGISTRY" = true ]; then
    cat > simple-values.yaml << 'EOF'
global:
  imageRegistry: "192.168.1.82:5555"

api:
  replicaCount: 2
  image:
    repository: tweetstream/api
    tag: "1.0.0"
    pullPolicy: IfNotPresent
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi
  # Allow scheduling on master node as fallback
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

frontend:
  replicaCount: 2
  image:
    repository: tweetstream/frontend
    tag: "1.0.0"
    pullPolicy: IfNotPresent
  resources:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 100m
      memory: 64Mi
  # Allow scheduling on master node as fallback
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

# Database configuration
database:
  persistence:
    enabled: true
    size: 20Gi
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi

# Redis configuration
redis:
  persistence:
    enabled: true
    size: 5Gi
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

# Keep security relaxed for now
security:
  podSecurityContext: {}
  securityContext: {}

# Enable monitoring
monitoring:
  enabled: true

# Enable Kafka
kafka:
  enabled: true

# Ingress configuration
ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  hosts:
  - host: tweetstream.192.168.1.82.nip.io
    paths:
    - path: /
      pathType: Prefix
      service:
        name: tweetstream-frontend
        port: 80
    - path: /api
      pathType: Prefix
      service:
        name: tweetstream-api
        port: 3000
EOF
else
    cat > simple-values.yaml << 'EOF'
api:
  replicaCount: 1
  image:
    repository: tweetstream/api
    tag: "1.0.0"
    pullPolicy: Never
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi
  # Force to master node where images exist
  nodeSelector:
    kubernetes.io/hostname: master-node
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

frontend:
  replicaCount: 1
  image:
    repository: tweetstream/frontend
    tag: "1.0.0"
    pullPolicy: Never
  resources:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 100m
      memory: 64Mi
  # Force to master node where images exist
  nodeSelector:
    kubernetes.io/hostname: master-node
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

# Database configuration
database:
  persistence:
    enabled: true
    size: 20Gi

# Redis configuration
redis:
  persistence:
    enabled: true
    size: 5Gi

# Keep security relaxed
security:
  podSecurityContext: {}
  securityContext: {}

# Enable monitoring
monitoring:
  enabled: true

# Enable Kafka
kafka:
  enabled: true

# Ingress configuration
ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  hosts:
  - host: tweetstream.192.168.1.82.nip.io
    paths:
    - path: /
      pathType: Prefix
      service:
        name: tweetstream-frontend
        port: 80
    - path: /api
      pathType: Prefix
      service:
        name: tweetstream-api
        port: 3000
EOF
fi

# Deploy the application
log_info "Deploying TweetStream..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

helm install tweetstream $HELM_CHART_PATH -n $NAMESPACE -f simple-values.yaml

log_success "Deployment initiated!"

# Wait for deployment
log_info "Waiting for pods to be ready..."
sleep 10

# Check deployment status
log_info "Checking deployment status..."
kubectl get pods -n $NAMESPACE -o wide

echo ""
log_info "Waiting for services to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=tweetstream -n $NAMESPACE --timeout=300s || {
    log_warning "Some pods may not be ready yet"
}

# Show final status
echo ""
log_info "Final deployment status:"
kubectl get pods -n $NAMESPACE
echo ""
kubectl get svc -n $NAMESPACE
echo ""
kubectl get ingress -n $NAMESPACE

# Test the application
echo ""
log_info "Testing application..."
MASTER_IP="192.168.1.82"
NODEPORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30080")

if curl -s -f -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/health > /dev/null 2>&1; then
    log_success "API health check passed"
else
    log_warning "API health check failed"
fi

if curl -s -f -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/ > /dev/null 2>&1; then
    log_success "Frontend check passed"
else
    log_warning "Frontend check failed"
fi

echo ""
log_success "🎉 TweetStream deployment completed!"
echo ""
log_info "Access the application at:"
echo "  URL: http://$MASTER_IP:$NODEPORT/"
echo "  Host header: tweetstream.192.168.1.82.nip.io"
echo ""
log_info "Or add to your /etc/hosts file:"
echo "  $MASTER_IP tweetstream.192.168.1.82.nip.io"

# Cleanup
rm -f simple-values.yaml

echo ""
log_info "Use './scripts/health-check.sh' to monitor the deployment" 