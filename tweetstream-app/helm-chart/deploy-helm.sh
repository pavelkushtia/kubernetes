#!/bin/bash

# TweetStream Helm Chart Deployment Script
# This script builds Docker images and deploys TweetStream using Helm

set -e

# Configuration
NAMESPACE="tweetstream"
RELEASE_NAME="tweetstream"
CHART_PATH="./tweetstream"
DOCKER_REGISTRY="localhost:5000"  # Change this to your registry
BUILD_IMAGES=${BUILD_IMAGES:-true}
PUSH_IMAGES=${PUSH_IMAGES:-false}

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
    
    # Check if docker is available (if building images)
    if [ "$BUILD_IMAGES" = true ] && ! command -v docker &> /dev/null; then
        log_error "docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Build Docker images
build_images() {
    if [ "$BUILD_IMAGES" != true ]; then
        log_info "Skipping image build (BUILD_IMAGES=false)"
        return
    fi
    
    log_info "Building Docker images..."
    
    # Build API image
    log_info "Building API image..."
    cd tweetstream/app-code/api
    docker build -t tweetstream/api:1.0.0 .
    if [ "$PUSH_IMAGES" = true ]; then
        docker tag tweetstream/api:1.0.0 ${DOCKER_REGISTRY}/tweetstream/api:1.0.0
        docker push ${DOCKER_REGISTRY}/tweetstream/api:1.0.0
    fi
    cd ../../..
    
    # Build Frontend image
    log_info "Building Frontend image..."
    cd tweetstream/app-code/frontend
    docker build -t tweetstream/frontend:1.0.0 .
    if [ "$PUSH_IMAGES" = true ]; then
        docker tag tweetstream/frontend:1.0.0 ${DOCKER_REGISTRY}/tweetstream/frontend:1.0.0
        docker push ${DOCKER_REGISTRY}/tweetstream/frontend:1.0.0
    fi
    cd ../../..
    
    log_success "Docker images built successfully"
}

# Create namespace
create_namespace() {
    log_info "Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    log_success "Namespace $NAMESPACE ready"
}

# Deploy with Helm
deploy_helm() {
    log_info "Deploying TweetStream with Helm..."
    
    # Update Helm dependencies
    log_info "Updating Helm dependencies..."
    helm dependency update $CHART_PATH
    
    # Deploy or upgrade
    if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
        log_info "Upgrading existing release: $RELEASE_NAME"
        helm upgrade $RELEASE_NAME $CHART_PATH \
            --namespace $NAMESPACE \
            --timeout 10m \
            --wait \
            --values $CHART_PATH/values.yaml
    else
        log_info "Installing new release: $RELEASE_NAME"
        helm install $RELEASE_NAME $CHART_PATH \
            --namespace $NAMESPACE \
            --create-namespace \
            --timeout 10m \
            --wait \
            --values $CHART_PATH/values.yaml
    fi
    
    log_success "Helm deployment completed"
}

# Wait for pods to be ready
wait_for_pods() {
    log_info "Waiting for pods to be ready..."
    
    # Wait for database
    kubectl wait --for=condition=ready pod -l component=database -n $NAMESPACE --timeout=300s
    
    # Wait for Redis
    kubectl wait --for=condition=ready pod -l component=redis -n $NAMESPACE --timeout=300s
    
    # Wait for Kafka
    kubectl wait --for=condition=ready pod -l component=kafka -n $NAMESPACE --timeout=300s
    
    # Wait for API
    kubectl wait --for=condition=ready pod -l component=api -n $NAMESPACE --timeout=300s
    
    # Wait for Frontend
    kubectl wait --for=condition=ready pod -l component=frontend -n $NAMESPACE --timeout=300s
    
    log_success "All pods are ready"
}

# Display deployment status
show_status() {
    log_info "Deployment Status:"
    echo
    
    # Show pods
    echo "Pods:"
    kubectl get pods -n $NAMESPACE -o wide
    echo
    
    # Show services
    echo "Services:"
    kubectl get services -n $NAMESPACE
    echo
    
    # Show ingress
    echo "Ingress:"
    kubectl get ingress -n $NAMESPACE
    echo
    
    # Show HPA
    echo "Horizontal Pod Autoscalers:"
    kubectl get hpa -n $NAMESPACE
    echo
    
    # Get ingress URL
    INGRESS_HOST=$(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "")
    if [ -n "$INGRESS_HOST" ]; then
        log_success "TweetStream is available at: http://$INGRESS_HOST"
        log_info "API documentation: http://$INGRESS_HOST/api"
        log_info "Health check: http://$INGRESS_HOST/api/health"
    fi
}

# Cleanup function
cleanup() {
    if [ "$1" = "uninstall" ]; then
        log_warning "Uninstalling TweetStream..."
        helm uninstall $RELEASE_NAME -n $NAMESPACE || true
        kubectl delete namespace $NAMESPACE || true
        log_success "TweetStream uninstalled"
        exit 0
    fi
}

# Main execution
main() {
    log_info "Starting TweetStream Helm deployment..."
    
    # Handle cleanup
    if [ "$1" = "uninstall" ] || [ "$1" = "cleanup" ]; then
        cleanup uninstall
    fi
    
    # Run deployment steps
    check_prerequisites
    build_images
    create_namespace
    deploy_helm
    wait_for_pods
    show_status
    
    log_success "TweetStream deployment completed successfully!"
    echo
    log_info "To monitor the deployment:"
    echo "  kubectl get pods -n $NAMESPACE -w"
    echo
    log_info "To view logs:"
    echo "  kubectl logs -f deployment/tweetstream-api -n $NAMESPACE"
    echo "  kubectl logs -f deployment/tweetstream-frontend -n $NAMESPACE"
    echo
    log_info "To uninstall:"
    echo "  $0 uninstall"
}

# Run main function with all arguments
main "$@" 