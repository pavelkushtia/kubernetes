#!/bin/bash

# TweetStream Health Check Script
# Provides comprehensive status of the TweetStream deployment

set -e

NAMESPACE="tweetstream"
MASTER_IP="192.168.1.82"
NODEPORT="30080"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_header() {
    echo -e "${CYAN}$1${NC}"
}

echo "🔍 TweetStream Health Check"
echo "=========================="
echo ""

# Check cluster connectivity
log_header "📡 Cluster Connectivity"
if kubectl cluster-info &> /dev/null; then
    log_success "Kubernetes cluster is accessible"
else
    log_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check namespace
if kubectl get namespace $NAMESPACE &> /dev/null; then
    log_success "TweetStream namespace exists"
else
    log_error "TweetStream namespace not found"
    exit 1
fi

echo ""

# Check pod status
log_header "🚀 Pod Status"
kubectl get pods -n $NAMESPACE -o wide

echo ""

# Check services
log_header "🌐 Services"
kubectl get svc -n $NAMESPACE

echo ""

# Check ingress
log_header "🔗 Ingress"
kubectl get ingress -n $NAMESPACE

echo ""

# Test API endpoints
log_header "🧪 API Health Tests"

# Test health endpoint
log_info "Testing API health endpoint..."
if curl -s -f -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/health > /dev/null; then
    log_success "API health endpoint is working"
    
    # Get health details
    HEALTH_RESPONSE=$(curl -s -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/health)
    echo "   Health details: $HEALTH_RESPONSE"
else
    log_error "API health endpoint is not accessible"
fi

# Test API documentation
log_info "Testing API documentation endpoint..."
if curl -s -f -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/api > /dev/null; then
    log_success "API documentation is accessible"
else
    log_warning "API documentation is not accessible"
fi

# Test tweets endpoint
log_info "Testing tweets endpoint..."
if curl -s -f -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/api/tweets > /dev/null; then
    log_success "Tweets endpoint is working"
    
    # Get tweet count
    TWEET_COUNT=$(curl -s -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/api/tweets | jq '.tweets | length' 2>/dev/null || echo "unknown")
    echo "   Available tweets: $TWEET_COUNT"
else
    log_warning "Tweets endpoint is not accessible"
fi

echo ""

# Test monitoring
log_header "📊 Monitoring Status"

# Check ServiceMonitor
if kubectl get servicemonitor -n $NAMESPACE &> /dev/null; then
    log_success "ServiceMonitor is configured"
    kubectl get servicemonitor -n $NAMESPACE
else
    log_warning "ServiceMonitor not found"
fi

# Test metrics endpoint
log_info "Testing metrics endpoint..."
if curl -s -f -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/metrics > /dev/null; then
    log_success "Metrics endpoint is working"
    
    # Get some key metrics
    ACTIVE_USERS=$(curl -s -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/metrics | grep "tweetstream_active_users_total" | awk '{print $2}' || echo "unknown")
    TOTAL_TWEETS=$(curl -s -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/metrics | grep "tweetstream_tweets_total" | awk '{print $2}' || echo "unknown")
    TOTAL_LIKES=$(curl -s -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/metrics | grep "tweetstream_likes_total" | awk '{print $2}' || echo "unknown")
    
    echo "   Active users: $ACTIVE_USERS"
    echo "   Total tweets: $TOTAL_TWEETS"
    echo "   Total likes: $TOTAL_LIKES"
else
    log_warning "Metrics endpoint is not accessible"
fi

echo ""

# Check external monitoring
log_header "🔍 External Monitoring"

# Check Prometheus
log_info "Testing Prometheus access..."
if curl -s -f -H "Host: prometheus.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/ > /dev/null; then
    log_success "Prometheus is accessible at http://$MASTER_IP:$NODEPORT/ (Host: prometheus.192.168.1.82.nip.io)"
else
    log_warning "Prometheus is not accessible"
fi

# Check Grafana
log_info "Testing Grafana access..."
if curl -s -f -H "Host: grafana.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/ > /dev/null; then
    log_success "Grafana is accessible at http://$MASTER_IP:$NODEPORT/ (Host: grafana.192.168.1.82.nip.io)"
else
    log_warning "Grafana is not accessible"
fi

echo ""

# Resource usage
log_header "💾 Resource Usage"
log_info "Node resource usage:"
kubectl top nodes 2>/dev/null || log_warning "Metrics server not available"

echo ""
log_info "Pod resource usage:"
kubectl top pods -n $NAMESPACE 2>/dev/null || log_warning "Metrics server not available"

echo ""

# Summary
log_header "📋 Access Information"
echo ""
echo "🌐 TweetStream API:"
echo "   URL: http://$MASTER_IP:$NODEPORT/api/health"
echo "   Host header: tweetstream.192.168.1.82.nip.io"
echo "   Documentation: http://$MASTER_IP:$NODEPORT/api/api"
echo ""
echo "📊 Monitoring:"
echo "   Prometheus: http://$MASTER_IP:$NODEPORT/ (Host: prometheus.192.168.1.82.nip.io)"
echo "   Grafana: http://$MASTER_IP:$NODEPORT/ (Host: grafana.192.168.1.82.nip.io)"
echo "   Metrics: http://$MASTER_IP:$NODEPORT/api/metrics"
echo ""
echo "🔧 Commands:"
echo "   Watch pods: kubectl get pods -n $NAMESPACE -w"
echo "   View logs: kubectl logs -n $NAMESPACE -l component=api -f"
echo "   Port forward API: kubectl port-forward -n $NAMESPACE svc/tweetstream-api 3000:3000"
echo ""

# Check for issues
ISSUES=0

# Count non-running pods
NON_RUNNING=$(kubectl get pods -n $NAMESPACE --no-headers | grep -v "Running" | grep -v "Completed" | wc -l)
if [ $NON_RUNNING -gt 0 ]; then
    log_warning "Found $NON_RUNNING non-running pods"
    ISSUES=$((ISSUES + 1))
fi

# Check if API is accessible
if ! curl -s -f -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/health > /dev/null; then
    log_error "API is not accessible"
    ISSUES=$((ISSUES + 1))
fi

echo ""
if [ $ISSUES -eq 0 ]; then
    log_success "🎉 TweetStream is healthy and operational!"
else
    log_warning "⚠️  Found $ISSUES issues that may need attention"
fi

echo ""
log_info "Run this script again with: ./scripts/health-check.sh" 