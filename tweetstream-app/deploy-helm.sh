#!/bin/bash

# TweetStream Helm Chart Deployment Script
# This script deploys the TweetStream application using Helm

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="tweetstream"
RELEASE_NAME="tweetstream"
ENVIRONMENT="development"
CHART_PATH="./helm-chart/tweetstream"
VALUES_FILE=""
DRY_RUN=false
UPGRADE=false
FORCE=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
TweetStream Helm Deployment Script

Usage: $0 [OPTIONS]

OPTIONS:
    -e, --environment ENV    Environment to deploy (development|staging|production) [default: development]
    -n, --namespace NS       Kubernetes namespace [default: tweetstream]
    -r, --release NAME       Helm release name [default: tweetstream]
    -f, --values FILE        Additional values file
    -u, --upgrade            Upgrade existing release
    --dry-run               Perform a dry run
    --force                 Force upgrade/install
    -h, --help              Show this help message

EXAMPLES:
    # Deploy development environment
    $0 -e development

    # Deploy to production with custom values
    $0 -e production

    # Upgrade existing release
    $0 -u -e staging

    # Dry run for production
    $0 -e production --dry-run

ENVIRONMENTS:
    development    - Local development with minimal resources
    staging        - Staging environment with moderate resources
    production     - Production environment with full resources and HA

CHART STRUCTURE:
    tweetstream-app/
    ├── helm-chart/
    │   └── tweetstream/
    │       ├── Chart.yaml
    │       ├── values.yaml (default)
    │       ├── values-dev.yaml
    │       ├── values-staging.yaml
    │       ├── values-prod.yaml
    │       ├── templates/
    │       ├── sql/
    │       └── app-code/
    ├── argocd-setup.yaml
    ├── tweetstream-argocd-app.yaml
    └── deploy-helm.sh (this script)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -f|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        -u|--upgrade)
            UPGRADE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    print_error "Valid environments: development, staging, production"
    exit 1
fi

# Set values file based on environment if not specified
if [[ -z "$VALUES_FILE" ]]; then
    case $ENVIRONMENT in
        development)
            VALUES_FILE="values-dev.yaml"
            ;;
        staging)
            VALUES_FILE="values-staging.yaml"
            ;;
        production)
            VALUES_FILE="values-prod.yaml"
            ;;
    esac
fi

print_status "Starting TweetStream deployment..."
print_status "Environment: $ENVIRONMENT"
print_status "Namespace: $NAMESPACE"
print_status "Release: $RELEASE_NAME"
print_status "Chart: $CHART_PATH"
print_status "Values file: $VALUES_FILE"

# Check if we're in the right directory
if [[ ! -f "deploy-helm.sh" ]]; then
    print_error "Please run this script from the tweetstream-app directory"
    print_error "Current directory: $(pwd)"
    exit 1
fi

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed. Please install Helm first."
    print_error "Installation: https://helm.sh/docs/intro/install/"
    exit 1
fi

# Check if kubectl is installed and configured
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

# Check if chart directory exists
if [[ ! -d "$CHART_PATH" ]]; then
    print_error "Chart directory not found: $CHART_PATH"
    print_error "Expected structure:"
    print_error "  tweetstream-app/"
    print_error "  └── helm-chart/"
    print_error "      └── tweetstream/"
    exit 1
fi

# Check if Chart.yaml exists
if [[ ! -f "$CHART_PATH/Chart.yaml" ]]; then
    print_error "Chart.yaml not found in: $CHART_PATH"
    exit 1
fi

# Check if values file exists
if [[ -n "$VALUES_FILE" && ! -f "$CHART_PATH/$VALUES_FILE" ]]; then
    print_warning "Values file not found: $CHART_PATH/$VALUES_FILE"
    print_warning "Available values files:"
    ls -la "$CHART_PATH"/values*.yaml 2>/dev/null || echo "  No values files found"
    print_warning "Proceeding with default values..."
    VALUES_FILE=""
fi

# Create namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    print_status "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
else
    print_status "Namespace $NAMESPACE already exists"
fi

# Check if release already exists
RELEASE_EXISTS=false
if helm list -n "$NAMESPACE" | grep -q "^$RELEASE_NAME"; then
    RELEASE_EXISTS=true
    print_status "Release $RELEASE_NAME already exists"
fi

# Prepare Helm command
HELM_CMD="helm"
if [[ "$RELEASE_EXISTS" == "true" && "$UPGRADE" == "true" ]]; then
    HELM_CMD="$HELM_CMD upgrade"
    print_status "Upgrading existing release..."
elif [[ "$RELEASE_EXISTS" == "true" && "$UPGRADE" == "false" ]]; then
    print_error "Release $RELEASE_NAME already exists. Use --upgrade to upgrade it."
    exit 1
else
    HELM_CMD="$HELM_CMD install"
    print_status "Installing new release..."
fi

# Add common options
HELM_CMD="$HELM_CMD $RELEASE_NAME $CHART_PATH"
HELM_CMD="$HELM_CMD --namespace $NAMESPACE"
HELM_CMD="$HELM_CMD --create-namespace"

# Add values file if specified
if [[ -n "$VALUES_FILE" ]]; then
    HELM_CMD="$HELM_CMD --values $CHART_PATH/$VALUES_FILE"
fi

# Add environment-specific overrides
case $ENVIRONMENT in
    development)
        HELM_CMD="$HELM_CMD --set global.environment=development"
        HELM_CMD="$HELM_CMD --set api.replicaCount=1"
        HELM_CMD="$HELM_CMD --set frontend.replicaCount=1"
        HELM_CMD="$HELM_CMD --set api.autoscaling.enabled=false"
        HELM_CMD="$HELM_CMD --set frontend.autoscaling.enabled=false"
        HELM_CMD="$HELM_CMD --set monitoring.enabled=false"
        ;;
    staging)
        HELM_CMD="$HELM_CMD --set global.environment=staging"
        HELM_CMD="$HELM_CMD --set api.replicaCount=2"
        HELM_CMD="$HELM_CMD --set frontend.replicaCount=2"
        HELM_CMD="$HELM_CMD --set monitoring.enabled=true"
        ;;
    production)
        HELM_CMD="$HELM_CMD --set global.environment=production"
        HELM_CMD="$HELM_CMD --set api.replicaCount=3"
        HELM_CMD="$HELM_CMD --set frontend.replicaCount=3"
        HELM_CMD="$HELM_CMD --set monitoring.enabled=true"
        HELM_CMD="$HELM_CMD --set networkPolicy.enabled=true"
        ;;
esac

# Add dry-run if specified
if [[ "$DRY_RUN" == "true" ]]; then
    HELM_CMD="$HELM_CMD --dry-run --debug"
    print_status "Performing dry run..."
fi

# Add force if specified
if [[ "$FORCE" == "true" ]]; then
    HELM_CMD="$HELM_CMD --force"
fi

# Add timeout
HELM_CMD="$HELM_CMD --timeout 10m"

# Add wait
if [[ "$DRY_RUN" == "false" ]]; then
    HELM_CMD="$HELM_CMD --wait"
fi

print_status "Executing: $HELM_CMD"

# Execute Helm command
if eval "$HELM_CMD"; then
    if [[ "$DRY_RUN" == "false" ]]; then
        print_success "TweetStream deployed successfully!"
        
        # Show deployment status
        print_status "Checking deployment status..."
        kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"
        
        # Show services
        print_status "Services:"
        kubectl get services -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"
        
        # Show ingress
        if kubectl get ingress -n "$NAMESPACE" &> /dev/null; then
            print_status "Ingress:"
            kubectl get ingress -n "$NAMESPACE"
        fi
        
        # Show access information
        print_success "Deployment completed!"
        print_status "Access URLs:"
        
        # Get ingress host
        INGRESS_HOST=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "")
        if [[ -n "$INGRESS_HOST" ]]; then
            echo "  TweetStream App: http://$INGRESS_HOST"
            echo "  API Documentation: http://$INGRESS_HOST/api"
            echo "  Health Check: http://$INGRESS_HOST/health"
            echo "  Metrics: http://$INGRESS_HOST/metrics"
        else
            print_warning "Ingress not configured. Use port-forward to access services:"
            echo "  kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME-frontend 8080:80"
            echo "  kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME-api 3000:3000"
        fi
        
        # Show useful commands
        print_status "Useful commands:"
        echo "  # Check pod status"
        echo "  kubectl get pods -n $NAMESPACE"
        echo ""
        echo "  # View API logs"
        echo "  kubectl logs -n $NAMESPACE -l component=api -f"
        echo ""
        echo "  # View frontend logs"
        echo "  kubectl logs -n $NAMESPACE -l component=frontend -f"
        echo ""
        echo "  # Upgrade deployment"
        echo "  $0 --upgrade -e $ENVIRONMENT"
        echo ""
        echo "  # Uninstall"
        echo "  helm uninstall $RELEASE_NAME -n $NAMESPACE"
        echo ""
        echo "  # Check Helm releases"
        echo "  helm list -n $NAMESPACE"
        
    else
        print_success "Dry run completed successfully!"
    fi
else
    print_error "Deployment failed!"
    exit 1
fi 