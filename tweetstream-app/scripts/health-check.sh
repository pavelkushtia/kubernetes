#!/bin/bash

# TweetStream Health Check Script
# Comprehensive monitoring and health checking for TweetStream deployment

set -e

# Configuration
NAMESPACE="tweetstream"
MASTER_IP="192.168.1.82"
NODEPORT="30080"

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
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if namespace exists
check_namespace() {
    log_info "Checking namespace..."
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log_success "Namespace '$NAMESPACE' exists"
        return 0
    else
        log_error "Namespace '$NAMESPACE' not found"
        return 1
    fi
}

# Check pod status
check_pods() {
    log_info "Checking pod status..."
    
    # Get all pods in namespace
    if ! kubectl get pods -n $NAMESPACE &> /dev/null; then
        log_error "No pods found in namespace $NAMESPACE"
        return 1
    fi
    
    # Check each component
    local all_healthy=true
    
    # API pods
    local api_pods=$(kubectl get pods -n $NAMESPACE -l component=api --no-headers 2>/dev/null | wc -l)
    local api_ready=$(kubectl get pods -n $NAMESPACE -l component=api --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l)
    
    if [ $api_pods -gt 0 ]; then
        if [ $api_ready -eq $api_pods ]; then
            log_success "API pods: $api_ready/$api_pods ready"
        else
            log_warning "API pods: $api_ready/$api_pods ready"
            all_healthy=false
        fi
    else
        log_error "No API pods found"
        all_healthy=false
    fi
    
    # Frontend pods
    local frontend_pods=$(kubectl get pods -n $NAMESPACE -l component=frontend --no-headers 2>/dev/null | wc -l)
    local frontend_ready=$(kubectl get pods -n $NAMESPACE -l component=frontend --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l)
    
    if [ $frontend_pods -gt 0 ]; then
        if [ $frontend_ready -eq $frontend_pods ]; then
            log_success "Frontend pods: $frontend_ready/$frontend_pods ready"
        else
            log_warning "Frontend pods: $frontend_ready/$frontend_pods ready"
            all_healthy=false
        fi
    else
        log_error "No Frontend pods found"
        all_healthy=false
    fi
    
    # Database pods
    local db_pods=$(kubectl get pods -n $NAMESPACE -l app=postgres --no-headers 2>/dev/null | wc -l)
    local db_ready=$(kubectl get pods -n $NAMESPACE -l app=postgres --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l)
    
    if [ $db_pods -gt 0 ]; then
        if [ $db_ready -eq $db_pods ]; then
            log_success "Database pods: $db_ready/$db_pods ready"
        else
            log_warning "Database pods: $db_ready/$db_pods ready"
            all_healthy=false
        fi
    else
        log_error "No Database pods found"
        all_healthy=false
    fi
    
    # Redis pods
    local redis_pods=$(kubectl get pods -n $NAMESPACE -l app=redis --no-headers 2>/dev/null | wc -l)
    local redis_ready=$(kubectl get pods -n $NAMESPACE -l app=redis --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l)
    
    if [ $redis_pods -gt 0 ]; then
        if [ $redis_ready -eq $redis_pods ]; then
            log_success "Redis pods: $redis_ready/$redis_pods ready"
        else
            log_warning "Redis pods: $redis_ready/$redis_pods ready"
            all_healthy=false
        fi
    else
        log_error "No Redis pods found"
        all_healthy=false
    fi
    
    if $all_healthy; then
        return 0
    else
        return 1
    fi
}

# Check services
check_services() {
    log_info "Checking services..."
    
    local services=("tweetstream-api" "tweetstream-frontend" "postgres-primary" "redis")
    local all_healthy=true
    
    for service in "${services[@]}"; do
        if kubectl get svc -n $NAMESPACE $service &> /dev/null; then
            local endpoints=$(kubectl get endpoints -n $NAMESPACE $service -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
            if [ $endpoints -gt 0 ]; then
                log_success "Service '$service': $endpoints endpoints"
            else
                log_warning "Service '$service': no endpoints"
                all_healthy=false
            fi
        else
            log_error "Service '$service' not found"
            all_healthy=false
        fi
    done
    
    if $all_healthy; then
        return 0
    else
        return 1
    fi
}

# Check ingress
check_ingress() {
    log_info "Checking ingress..."
    
    if kubectl get ingress -n $NAMESPACE tweetstream &> /dev/null; then
        local ingress_ip=$(kubectl get ingress -n $NAMESPACE tweetstream -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        local ingress_class=$(kubectl get ingress -n $NAMESPACE tweetstream -o jsonpath='{.spec.ingressClassName}' 2>/dev/null)
        
        log_success "Ingress 'tweetstream' exists (class: $ingress_class)"
        
        # Check ingress controller
        if kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx &> /dev/null; then
            local controller_ready=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --no-headers | grep "1/1.*Running" | wc -l)
            if [ $controller_ready -gt 0 ]; then
                log_success "Ingress controller is running"
                return 0
            else
                log_warning "Ingress controller not ready"
                return 1
            fi
        else
            log_error "Ingress controller not found"
            return 1
        fi
    else
        log_error "Ingress 'tweetstream' not found"
        return 1
    fi
}

# Test application endpoints
test_endpoints() {
    log_info "Testing application endpoints..."
    
    local all_healthy=true
    
    # Test API health endpoint
    log_info "Testing API health endpoint..."
    if curl -s -f -m 10 -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/health > /dev/null 2>&1; then
        log_success "API health endpoint responding"
    else
        log_error "API health endpoint not responding"
        all_healthy=false
    fi
    
    # Test API ready endpoint
    log_info "Testing API ready endpoint..."
    if curl -s -f -m 10 -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/api/ready > /dev/null 2>&1; then
        log_success "API ready endpoint responding"
    else
        log_warning "API ready endpoint not responding"
        all_healthy=false
    fi
    
    # Test frontend
    log_info "Testing frontend..."
    if curl -s -f -m 10 -H "Host: tweetstream.192.168.1.82.nip.io" http://$MASTER_IP:$NODEPORT/ > /dev/null 2>&1; then
        log_success "Frontend responding"
    else
        log_error "Frontend not responding"
        all_healthy=false
    fi
    
    if $all_healthy; then
        return 0
    else
        return 1
    fi
}

# Check resource usage
check_resources() {
    log_info "Checking resource usage..."
    
    # Check if metrics-server is available
    if ! kubectl top nodes &> /dev/null; then
        log_warning "Metrics server not available, skipping resource checks"
        return 0
    fi
    
    # Node resource usage
    log_info "Node resource usage:"
    kubectl top nodes 2>/dev/null || log_warning "Could not get node metrics"
    
    echo ""
    
    # Pod resource usage
    log_info "Pod resource usage:"
    kubectl top pods -n $NAMESPACE 2>/dev/null || log_warning "Could not get pod metrics"
    
    return 0
}

# Check persistent volumes
check_storage() {
    log_info "Checking storage..."
    
    local pvcs=$(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    if [ $pvcs -gt 0 ]; then
        local bound_pvcs=$(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null | grep "Bound" | wc -l)
        if [ $bound_pvcs -eq $pvcs ]; then
            log_success "Persistent volumes: $bound_pvcs/$pvcs bound"
            return 0
        else
            log_warning "Persistent volumes: $bound_pvcs/$pvcs bound"
            return 1
        fi
    else
        log_info "No persistent volume claims found"
        return 0
    fi
}

# Show detailed status
show_detailed_status() {
    echo ""
    log_info "=== Detailed Status ==="
    
    echo ""
    echo "Pods:"
    kubectl get pods -n $NAMESPACE -o wide 2>/dev/null || echo "No pods found"
    
    echo ""
    echo "Services:"
    kubectl get svc -n $NAMESPACE 2>/dev/null || echo "No services found"
    
    echo ""
    echo "Ingress:"
    kubectl get ingress -n $NAMESPACE 2>/dev/null || echo "No ingress found"
    
    echo ""
    echo "Persistent Volume Claims:"
    kubectl get pvc -n $NAMESPACE 2>/dev/null || echo "No PVCs found"
    
    echo ""
    echo "Recent Events:"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10 2>/dev/null || echo "No events found"
}

# Show troubleshooting info
show_troubleshooting() {
    echo ""
    log_info "=== Troubleshooting Information ==="
    
    # Check for common issues
    local failed_pods=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -v "1/1.*Running" | grep -v "Completed")
    
    if [ -n "$failed_pods" ]; then
        echo ""
        log_warning "Failed/Pending pods found:"
        echo "$failed_pods"
        
        echo ""
        log_info "Pod descriptions for failed pods:"
        while IFS= read -r line; do
            local pod_name=$(echo "$line" | awk '{print $1}')
            echo "--- $pod_name ---"
            kubectl describe pod -n $NAMESPACE "$pod_name" | grep -A 10 "Events:" 2>/dev/null || echo "No events"
        done <<< "$failed_pods"
    fi
    
    echo ""
    log_info "Application URLs:"
    echo "Frontend: http://$MASTER_IP:$NODEPORT/ (Host: tweetstream.192.168.1.82.nip.io)"
    echo "API Health: http://$MASTER_IP:$NODEPORT/api/health (Host: tweetstream.192.168.1.82.nip.io)"
    echo "API Ready: http://$MASTER_IP:$NODEPORT/api/ready (Host: tweetstream.192.168.1.82.nip.io)"
    
    echo ""
    log_info "Useful commands:"
    echo "kubectl logs -n $NAMESPACE -l component=api"
    echo "kubectl logs -n $NAMESPACE -l component=frontend"
    echo "kubectl describe pods -n $NAMESPACE"
    echo "kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
}

# Main health check function
main() {
    echo "🏥 TweetStream Health Check"
    echo "=========================="
    
    local overall_health=true
    
    # Run all checks
    check_namespace || overall_health=false
    echo ""
    
    check_pods || overall_health=false
    echo ""
    
    check_services || overall_health=false
    echo ""
    
    check_ingress || overall_health=false
    echo ""
    
    test_endpoints || overall_health=false
    echo ""
    
    check_storage || overall_health=false
    echo ""
    
    check_resources
    
    # Show detailed status if requested
    if [ "$1" = "--detailed" ] || [ "$1" = "-d" ]; then
        show_detailed_status
    fi
    
    # Show troubleshooting info if there are issues
    if ! $overall_health || [ "$1" = "--troubleshoot" ] || [ "$1" = "-t" ]; then
        show_troubleshooting
    fi
    
    echo ""
    echo "=========================="
    if $overall_health; then
        log_success "🎉 Overall health: HEALTHY"
        exit 0
    else
        log_error "💥 Overall health: UNHEALTHY"
        echo ""
        log_info "Run with --troubleshoot for more details"
        exit 1
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --detailed, -d      Show detailed status information"
    echo "  --troubleshoot, -t  Show troubleshooting information"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                  # Basic health check"
    echo "  $0 --detailed       # Health check with detailed status"
    echo "  $0 --troubleshoot   # Health check with troubleshooting info"
}

# Handle command line arguments
case "$1" in
    --help|-h)
        show_usage
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac 