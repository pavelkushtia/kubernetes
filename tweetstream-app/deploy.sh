#!/bin/bash

# TweetStream Deployment Script
# Deploys a complete Twitter-like application with monitoring

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local app=$2
    local timeout=${3:-300}
    
    print_status $BLUE "⏳ Waiting for $app pods to be ready in namespace $namespace..."
    
    if kubectl wait --for=condition=ready pod -l app=$app -n $namespace --timeout=${timeout}s; then
        print_status $GREEN "✅ $app pods are ready!"
    else
        print_status $RED "❌ Timeout waiting for $app pods to be ready"
        return 1
    fi
}

# Function to check if namespace exists
check_namespace() {
    local namespace=$1
    if kubectl get namespace $namespace &> /dev/null; then
        print_status $YELLOW "⚠️  Namespace $namespace already exists"
        return 0
    else
        return 1
    fi
}

print_status $BLUE "🚀 Starting TweetStream Deployment"
print_status $BLUE "=================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_status $RED "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check cluster connectivity
print_status $BLUE "🔍 Checking Kubernetes cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_status $RED "❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_status $GREEN "✅ Connected to Kubernetes cluster"

# Check if monitoring namespace exists
if ! kubectl get namespace monitoring &> /dev/null; then
    print_status $RED "❌ Monitoring namespace not found. Please deploy Prometheus/Grafana first."
    print_status $YELLOW "💡 Run: kubectl apply -f ../ansile_k8s_install/production_addons.yaml"
    exit 1
fi

print_status $GREEN "✅ Monitoring namespace found"

# Deploy TweetStream application
print_status $BLUE "📦 Deploying TweetStream application..."
kubectl apply -f tweetstream-app.yaml

# Wait for database to be ready
wait_for_pods "tweetstream" "postgres" 180

# Wait for Redis to be ready
wait_for_pods "tweetstream" "redis" 120

# Wait for Zookeeper to be ready
wait_for_pods "tweetstream" "zookeeper" 120

# Wait for Kafka to be ready
wait_for_pods "tweetstream" "kafka" 180

# Deploy monitoring exporters
print_status $BLUE "📊 Deploying monitoring exporters..."
kubectl apply -f monitoring-exporters.yaml

# Wait for exporters to be ready
wait_for_pods "tweetstream" "postgres-exporter" 60
wait_for_pods "tweetstream" "redis-exporter" 60
wait_for_pods "tweetstream" "kafka-exporter" 60

# Wait for API to be ready
wait_for_pods "tweetstream" "tweetstream-api" 180

# Wait for frontend to be ready
wait_for_pods "tweetstream" "tweetstream-frontend" 120

# Deploy Grafana dashboard
print_status $BLUE "📈 Deploying Grafana dashboard..."
kubectl apply -f grafana-dashboard.yaml

# Check ingress
print_status $BLUE "🌐 Checking ingress configuration..."
if kubectl get ingress tweetstream-ingress -n tweetstream &> /dev/null; then
    INGRESS_HOST=$(kubectl get ingress tweetstream-ingress -n tweetstream -o jsonpath='{.spec.rules[0].host}')
    print_status $GREEN "✅ Ingress configured: http://$INGRESS_HOST:30080"
else
    print_status $RED "❌ Ingress not found"
fi

# Get service information
print_status $BLUE "📋 Service Information:"
echo "========================"
kubectl get services -n tweetstream

print_status $BLUE "📋 Pod Status:"
echo "==============="
kubectl get pods -n tweetstream

# Check HPA status
print_status $BLUE "📊 Horizontal Pod Autoscaler Status:"
echo "====================================="
kubectl get hpa -n tweetstream

# Final status check
print_status $BLUE "🔍 Final Health Check..."

# Check if all pods are running
NOT_RUNNING=$(kubectl get pods -n tweetstream --no-headers | grep -v Running | wc -l)
if [ "$NOT_RUNNING" -eq 0 ]; then
    print_status $GREEN "✅ All pods are running!"
else
    print_status $YELLOW "⚠️  $NOT_RUNNING pods are not in Running state"
    kubectl get pods -n tweetstream | grep -v Running
fi

# Display access information
print_status $GREEN "🎉 TweetStream Deployment Complete!"
print_status $GREEN "===================================="
echo ""
print_status $BLUE "📱 Application Access:"
print_status $GREEN "  • TweetStream App: http://tweetstream.192.168.1.82.nip.io:30080"
print_status $GREEN "  • Grafana Dashboard: http://grafana.192.168.1.82.nip.io:30080"
print_status $GREEN "  • Prometheus: http://prometheus.192.168.1.82.nip.io:30080"
echo ""
print_status $BLUE "🔧 Useful Commands:"
echo "  • View pods: kubectl get pods -n tweetstream"
echo "  • View logs: kubectl logs -f deployment/tweetstream-api -n tweetstream"
echo "  • Scale API: kubectl scale deployment tweetstream-api --replicas=5 -n tweetstream"
echo "  • Port forward: kubectl port-forward svc/tweetstream-frontend 8080:80 -n tweetstream"
echo ""
print_status $BLUE "📊 Monitoring:"
echo "  • Custom metrics available in Prometheus"
echo "  • TweetStream dashboard imported to Grafana"
echo "  • Alerts configured for critical components"
echo ""
print_status $YELLOW "💡 Next Steps:"
echo "  1. Access the application and create some tweets"
echo "  2. Check Grafana dashboard for metrics"
echo "  3. Test auto-scaling by generating load"
echo "  4. Monitor alerts in AlertManager"

# Test API health
print_status $BLUE "🏥 Testing API Health..."
if kubectl exec -n tweetstream deployment/tweetstream-api -- wget -q -O- http://localhost:3000/health &> /dev/null; then
    print_status $GREEN "✅ API health check passed"
else
    print_status $YELLOW "⚠️  API health check failed - may still be starting"
fi

print_status $GREEN "🚀 TweetStream is ready to use!" 