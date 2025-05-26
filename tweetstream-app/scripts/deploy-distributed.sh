#!/bin/bash

# TweetStream Distributed Deployment Script
# Deploys TweetStream across all nodes with proper load balancing

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

echo "🚀 TweetStream Distributed Deployment"
echo "====================================="

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

# Check cluster status
log_info "Checking cluster status..."
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
READY_NODES=$(kubectl get nodes --no-headers | grep " Ready " | wc -l)

log_info "Cluster nodes: $READY_NODES/$TOTAL_NODES ready"

if [ $READY_NODES -lt 2 ]; then
    log_error "Need at least 2 ready nodes for distributed deployment"
    exit 1
fi

# Check if local registry is accessible from worker nodes
log_info "Checking local registry accessibility..."
REGISTRY_HOST="192.168.1.82:5555"

# Test registry from a worker node by checking containerd configuration
WORKER_NODE=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name" | grep -v master | head -1)
if [ -n "$WORKER_NODE" ]; then
    log_info "Testing registry configuration on worker node: $WORKER_NODE"
    if sshpass -p "8407" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no sanzad@$WORKER_NODE "echo '8407' | sudo -S grep -q '$REGISTRY_HOST' /etc/containerd/config.toml" 2>/dev/null; then
        log_success "Local registry is configured on worker nodes"
        USE_LOCAL_REGISTRY=true
    else
        log_warning "Local registry not configured on worker nodes"
        log_warning "Will use master node deployment"
        USE_LOCAL_REGISTRY=false
    fi
else
    log_warning "No worker nodes found"
    USE_LOCAL_REGISTRY=false
fi

# Create distributed deployment values
log_info "Creating distributed deployment configuration..."

if [ "$USE_LOCAL_REGISTRY" = true ]; then
    cat > distributed-values.yaml << 'EOF'
global:
  imageRegistry: "192.168.1.82:5555"

api:
  replicaCount: 3
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

# Security context
security:
  podSecurityContext:
    runAsUser: 101
    runAsGroup: 101
    fsGroup: 101
    runAsNonRoot: true
  securityContext:
    runAsUser: 101
    runAsGroup: 101
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
      add:
        - CHOWN
        - DAC_OVERRIDE

# Enable monitoring
monitoring:
  enabled: true

# Enable Kafka for real-time messaging
kafka:
  enabled: true
  replicaCount: 3
  resources:
    limits:
      cpu: 500m
      memory: 1Gi
    requests:
      cpu: 200m
      memory: 512Mi

# No node selector - allow scheduling on all nodes
nodeSelector: {}

# No tolerations needed for worker nodes
tolerations: []

# Pod anti-affinity for better distribution
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - tweetstream
        topologyKey: kubernetes.io/hostname

# Ingress configuration
ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
  hosts:
  - host: tweetstream.192.168.1.82.nip.io
    paths:
    - path: /
      pathType: Prefix
      service:
        name: tweetstream-frontend
        port: 80
    - path: /api(/|$)(.*)
      pathType: ImplementationSpecific
      service:
        name: tweetstream-api
        port: 3000
EOF
else
    cat > distributed-values.yaml << 'EOF'
api:
  replicaCount: 2
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

# Security context
security:
  podSecurityContext:
    runAsUser: 101
    runAsGroup: 101
    fsGroup: 101
    runAsNonRoot: true
  securityContext:
    runAsUser: 101
    runAsGroup: 101
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
      add:
        - CHOWN
        - DAC_OVERRIDE

# Enable monitoring
monitoring:
  enabled: true

# Disable Kafka to save resources
kafka:
  enabled: false

# Force to master node where images exist
nodeSelector:
  kubernetes.io/hostname: master-node

tolerations:
- key: "node-role.kubernetes.io/control-plane"
  operator: "Exists"
  effect: "NoSchedule"

# Ingress configuration
ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
  hosts:
  - host: tweetstream.192.168.1.82.nip.io
    paths:
    - path: /
      pathType: Prefix
      service:
        name: tweetstream-frontend
        port: 80
    - path: /api(/|$)(.*)
      pathType: ImplementationSpecific
      service:
        name: tweetstream-api
        port: 3000
EOF
fi

# Deploy the application
log_info "Deploying TweetStream in distributed mode..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Check if deployment exists
if helm list -n $NAMESPACE | grep -q tweetstream; then
    log_info "Upgrading existing deployment..."
    helm upgrade tweetstream $HELM_CHART_PATH -n $NAMESPACE -f distributed-values.yaml
else
    log_info "Installing new deployment..."
    helm install tweetstream $HELM_CHART_PATH -n $NAMESPACE -f distributed-values.yaml
fi

log_success "Deployment command completed"

# Wait for deployment
log_info "Waiting for deployment to be ready..."
sleep 10

# Check deployment status
log_info "Checking deployment status..."
kubectl get pods -n $NAMESPACE -o wide

echo ""
log_info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=tweetstream -n $NAMESPACE --timeout=300s || {
    log_warning "Some pods may not be ready yet"
}

# Show final status
echo ""
log_info "Final deployment status:"
kubectl get pods -n $NAMESPACE -o wide
echo ""
kubectl get svc -n $NAMESPACE
echo ""
kubectl get ingress -n $NAMESPACE

# Test the deployment
echo ""
log_info "Testing deployment..."
MASTER_IP="192.168.1.82"
NODEPORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30080")

if curl -s -f -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/health > /dev/null 2>&1; then
    log_success "API health check passed"
else
    log_warning "API health check failed"
fi

echo ""
log_success "🎉 TweetStream distributed deployment completed!"
echo ""
log_info "Access the application at:"
echo "  URL: http://$MASTER_IP:$NODEPORT/"
echo "  Host header: tweetstream.192.168.1.82.nip.io"
echo ""
log_info "Monitoring:"
echo "  Prometheus: http://$MASTER_IP:$NODEPORT/ (Host: prometheus.192.168.1.82.nip.io)"
echo "  Grafana: http://$MASTER_IP:$NODEPORT/ (Host: grafana.192.168.1.82.nip.io)"
echo ""
log_info "Use './scripts/health-check.sh' to monitor the deployment"

# Cleanup
rm -f distributed-values.yaml

echo ""
if [ "$USE_LOCAL_REGISTRY" = true ]; then
    log_success "✅ Distributed deployment with local registry completed!"
else
    log_warning "⚠️  Limited deployment due to registry access issues"
    log_info "To enable full distributed deployment:"
    echo "  1. Configure worker nodes: ./scripts/configure-worker-nodes.sh"
    echo "  2. Or use GitHub Container Registry"
    echo "  3. Then re-run: ./scripts/deploy-distributed.sh"
fi 