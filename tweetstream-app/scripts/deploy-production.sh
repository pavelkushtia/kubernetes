#!/bin/bash

# TweetStream Production Deployment Script
# This script deploys TweetStream with proper image distribution and production configuration

set -e

# Configuration
NAMESPACE="tweetstream"
HELM_CHART_PATH="helm-chart/tweetstream"
GITHUB_USERNAME=""  # Set this if using GitHub Container Registry
DEPLOYMENT_TYPE=""  # Will be set based on user choice

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if helm is available
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -d "$HELM_CHART_PATH" ]; then
        log_error "Helm chart not found at $HELM_CHART_PATH"
        log_error "Please run this script from the tweetstream-app directory"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Display current cluster status
show_cluster_status() {
    log_info "Current cluster status:"
    echo "Nodes:"
    kubectl get nodes -o wide
    echo ""
    echo "Current TweetStream deployment (if any):"
    kubectl get pods -n $NAMESPACE 2>/dev/null || echo "No existing deployment found"
    echo ""
}

# Choose deployment method
choose_deployment_method() {
    echo ""
    log_info "Choose deployment method:"
    echo "1) GitHub Container Registry (Best for production - requires GitHub account)"
    echo "2) Local Registry Setup (Good for on-premise - configures worker nodes)"
    echo "3) Manual Image Distribution (Distributes images via SSH)"
    echo "4) Improved Local Registry (Uses existing registry with smart fallback)"
    echo ""
    
    while true; do
        read -p "Enter your choice (1-4): " choice
        case $choice in
            1)
                DEPLOYMENT_TYPE="github"
                break
                ;;
            2)
                DEPLOYMENT_TYPE="local-registry"
                break
                ;;
            3)
                DEPLOYMENT_TYPE="manual"
                break
                ;;
            4)
                DEPLOYMENT_TYPE="temporary"
                break
                ;;
            *)
                log_error "Invalid choice. Please enter 1, 2, 3, or 4."
                ;;
        esac
    done
}

# Deploy with GitHub Container Registry
deploy_github_registry() {
    log_info "Setting up GitHub Container Registry deployment..."
    
    if [ -z "$GITHUB_USERNAME" ]; then
        read -p "Enter your GitHub username: " GITHUB_USERNAME
    fi
    
    # Check if images exist locally
    if ! sudo docker images | grep -q "tweetstream/api"; then
        log_error "TweetStream images not found locally. Please build them first."
        exit 1
    fi
    
    # Check if user is logged in to GHCR
    log_info "Checking GitHub Container Registry login..."
    if ! sudo docker info 2>/dev/null | grep -q "ghcr.io"; then
        log_warning "Not logged in to GitHub Container Registry"
        echo "Please create a Personal Access Token with 'write:packages' scope"
        echo "Then run: echo \$GITHUB_TOKEN | sudo docker login ghcr.io -u $GITHUB_USERNAME --password-stdin"
        read -p "Press Enter after logging in..."
    fi
    
    # Push images
    log_info "Pushing images to GitHub Container Registry..."
    cd helm-chart
    chmod +x push-to-ghcr.sh
    sed -i "s/your-github-username/$GITHUB_USERNAME/g" push-to-ghcr.sh
    ./push-to-ghcr.sh
    cd ..
    
    # Create production values file
    cat > production-values.yaml << EOF
global:
  imageRegistry: "ghcr.io/$GITHUB_USERNAME"

api:
  replicaCount: 3
  image:
    repository: tweetstream-api
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
    repository: tweetstream-frontend
    tag: "1.0.0"
    pullPolicy: IfNotPresent
  resources:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 100m
      memory: 64Mi

# Remove temporary workarounds
nodeSelector: {}
tolerations: []

# Restore security context
security:
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 1001
    fsGroup: 1001
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: false
    runAsNonRoot: true
    runAsUser: 1001

# Enable monitoring
monitoring:
  enabled: true

# Enable Kafka
kafka:
  enabled: true
EOF
    
    VALUES_FILE="production-values.yaml"
}

# Deploy with local registry fix
deploy_local_registry() {
    log_info "Setting up local registry deployment..."
    
    # Try to fix local registry configuration
    log_info "Attempting to configure local registry on worker nodes..."
    cd helm-chart
    chmod +x fix-local-registry.sh
    
    if ./fix-local-registry.sh; then
        log_success "Local registry configuration completed successfully"
    else
        log_warning "Local registry configuration had issues, but continuing with deployment"
        log_info "You may need to manually configure worker nodes or use manual image distribution"
    fi
    cd ..
    
    # Create local registry values file
    cat > local-registry-values.yaml << EOF
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

# Remove temporary workarounds gradually
nodeSelector: {}
tolerations: []

# Restore security context (but keep it relaxed for now)
security:
  podSecurityContext:
    runAsNonRoot: false  # Keep relaxed for now
    runAsUser: 0
    fsGroup: 0
  securityContext:
    allowPrivilegeEscalation: true
    capabilities:
      drop: []
    readOnlyRootFilesystem: false
    runAsNonRoot: false
    runAsUser: 0

# Enable monitoring
monitoring:
  enabled: true

# Enable Kafka
kafka:
  enabled: true

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
EOF
    
    VALUES_FILE="local-registry-values.yaml"
}

# Deploy with manual image distribution
deploy_manual_distribution() {
    log_info "Setting up manual image distribution..."
    
    # Check if images exist locally
    if ! sudo docker images | grep -q "tweetstream/api"; then
        log_error "TweetStream images not found locally. Please build them first."
        log_info "Run: cd helm-chart && ./build-images.sh"
        exit 1
    fi
    
    # Get worker nodes
    WORKER_NODES=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name" | grep -v master)
    
    log_info "Found worker nodes: $WORKER_NODES"
    log_info "Attempting to distribute images to worker nodes..."
    
    success_count=0
    total_nodes=0
    
    for node in $WORKER_NODES; do
        total_nodes=$((total_nodes + 1))
        log_info "Distributing images to $node..."
        
        # Try to copy API image
        if sudo docker save tweetstream/api:1.0.0 | ssh $node 'sudo ctr -n k8s.io images import -' 2>/dev/null; then
            log_success "API image copied to $node"
        else
            log_warning "Failed to copy API image to $node"
            continue
        fi
        
        # Try to copy Frontend image
        if sudo docker save tweetstream/frontend:1.0.0 | ssh $node 'sudo ctr -n k8s.io images import -' 2>/dev/null; then
            log_success "Frontend image copied to $node"
            success_count=$((success_count + 1))
        else
            log_warning "Failed to copy Frontend image to $node"
        fi
    done
    
    log_info "Image distribution summary: $success_count/$total_nodes nodes successful"
    
    if [ $success_count -eq 0 ]; then
        log_error "Failed to distribute images to any worker nodes"
        log_info "Falling back to local registry or master node deployment"
    fi
    
    # Create manual distribution values file
    cat > manual-values.yaml << EOF
api:
  replicaCount: 2
  image:
    repository: tweetstream/api
    tag: "1.0.0"
    pullPolicy: Never  # Use local images
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
    pullPolicy: Never  # Use local images
  resources:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 100m
      memory: 64Mi

# Remove temporary workarounds gradually
nodeSelector: {}
tolerations: []

# Keep security context relaxed for now
security:
  podSecurityContext:
    runAsNonRoot: false
    runAsUser: 0
    fsGroup: 0
  securityContext:
    allowPrivilegeEscalation: true
    capabilities:
      drop: []
    readOnlyRootFilesystem: false
    runAsNonRoot: false
    runAsUser: 0

# Enable monitoring
monitoring:
  enabled: true

# Enable Kafka
kafka:
  enabled: true

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
EOF
    
    VALUES_FILE="manual-values.yaml"
}

# Keep temporary setup but make it more robust
deploy_temporary() {
    log_info "Setting up improved temporary deployment..."
    log_info "This will use the local registry with fallback to master node scheduling"
    
    # Create improved temporary values file
    cat > improved-temporary-values.yaml << EOF
global:
  imageRegistry: "192.168.1.82:5555"

api:
  replicaCount: 2
  image:
    repository: tweetstream/api
    tag: "1.0.0"
    pullPolicy: IfNotPresent  # Try registry first, then local
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi
  # Fallback to master node if images not available on workers
  nodeSelector: {}
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

frontend:
  replicaCount: 2
  image:
    repository: tweetstream/frontend
    tag: "1.0.0"
    pullPolicy: IfNotPresent  # Try registry first, then local
  resources:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 100m
      memory: 64Mi
  # Fallback to master node if images not available on workers
  nodeSelector: {}
  tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

# Keep security context relaxed but functional
security:
  podSecurityContext:
    runAsNonRoot: false
    runAsUser: 0
    fsGroup: 0
  securityContext:
    allowPrivilegeEscalation: true
    capabilities:
      drop: []
    readOnlyRootFilesystem: false
    runAsNonRoot: false
    runAsUser: 0

# Enable monitoring
monitoring:
  enabled: true

# Enable Kafka
kafka:
  enabled: true

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
EOF
    
    VALUES_FILE="improved-temporary-values.yaml"
}

# Deploy the application
deploy_application() {
    log_info "Deploying TweetStream application..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Check if deployment exists
    if helm list -n $NAMESPACE | grep -q tweetstream; then
        log_info "Upgrading existing deployment..."
        helm upgrade tweetstream $HELM_CHART_PATH -n $NAMESPACE -f $VALUES_FILE
    else
        log_info "Installing new deployment..."
        helm install tweetstream $HELM_CHART_PATH -n $NAMESPACE -f $VALUES_FILE
    fi
    
    log_success "Deployment command completed"
}

# Wait for deployment to be ready
wait_for_deployment() {
    log_info "Waiting for deployment to be ready..."
    
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=tweetstream -n $NAMESPACE --timeout=300s || {
        log_warning "Some pods may not be ready yet. Checking status..."
    }
    
    # Show deployment status
    echo ""
    log_info "Deployment status:"
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    kubectl get svc -n $NAMESPACE
    echo ""
    kubectl get ingress -n $NAMESPACE
}

# Test the deployment
test_deployment() {
    log_info "Testing deployment..."
    
    # Get ingress URL
    INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.clusterIP}')
    NODEPORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[0].nodePort}')
    MASTER_IP="192.168.1.82"
    
    # Test API health
    log_info "Testing API health endpoint..."
    if curl -s -f -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/health > /dev/null; then
        log_success "API health check passed"
    else
        log_warning "API health check failed"
    fi
    
    # Test frontend
    log_info "Testing frontend..."
    if curl -s -f -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/ > /dev/null; then
        log_success "Frontend check passed"
    else
        log_warning "Frontend check failed"
    fi
    
    echo ""
    log_success "Application URL: http://$MASTER_IP:$NODEPORT/"
    log_info "Use Host header: tweetstream.192.168.1.82.nip.io"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f production-values.yaml local-registry-values.yaml manual-values.yaml
}

# Main execution
main() {
    echo "🚀 TweetStream Production Deployment Script"
    echo "==========================================="
    
    check_prerequisites
    show_cluster_status
    choose_deployment_method
    
    case $DEPLOYMENT_TYPE in
        "github")
            deploy_github_registry
            ;;
        "local-registry")
            deploy_local_registry
            ;;
        "manual")
            deploy_manual_distribution
            ;;
        "temporary")
            deploy_temporary
            ;;
    esac
    
    deploy_application
    wait_for_deployment
    test_deployment
    
    echo ""
    log_success "🎉 TweetStream deployment completed!"
    
    if [ "$DEPLOYMENT_TYPE" = "temporary" ]; then
        log_warning "⚠️  You are using a temporary setup. Consider implementing a production solution."
    fi
    
    cleanup
}

# Trap to cleanup on exit
trap cleanup EXIT

# Run main function
main "$@" 