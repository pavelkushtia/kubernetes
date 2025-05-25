#!/bin/bash

# TweetStream Cleanup Script
# Safely removes TweetStream deployment and associated resources

set -e

# Configuration
NAMESPACE="tweetstream"

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

# Show current deployment status
show_current_status() {
    log_info "Current TweetStream deployment status:"
    echo ""
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        echo "Namespace: $NAMESPACE (exists)"
        
        echo ""
        echo "Pods:"
        kubectl get pods -n $NAMESPACE 2>/dev/null || echo "No pods found"
        
        echo ""
        echo "Services:"
        kubectl get svc -n $NAMESPACE 2>/dev/null || echo "No services found"
        
        echo ""
        echo "Persistent Volume Claims:"
        kubectl get pvc -n $NAMESPACE 2>/dev/null || echo "No PVCs found"
        
        echo ""
        echo "Helm releases:"
        helm list -n $NAMESPACE 2>/dev/null || echo "No Helm releases found"
    else
        echo "Namespace: $NAMESPACE (does not exist)"
    fi
    echo ""
}

# Confirm cleanup action
confirm_cleanup() {
    local cleanup_type="$1"
    
    echo ""
    log_warning "⚠️  CLEANUP CONFIRMATION ⚠️"
    echo ""
    
    case $cleanup_type in
        "complete")
            echo "This will COMPLETELY REMOVE the TweetStream application including:"
            echo "  • All pods and deployments"
            echo "  • All services and ingress"
            echo "  • All persistent data (DATABASE WILL BE LOST)"
            echo "  • The entire namespace"
            echo "  • Helm release"
            ;;
        "app-only")
            echo "This will remove the TweetStream application but keep data:"
            echo "  • All pods and deployments"
            echo "  • All services and ingress"
            echo "  • Helm release"
            echo "  • Persistent data will be PRESERVED"
            ;;
        "helm-only")
            echo "This will only remove the Helm release:"
            echo "  • Helm release will be uninstalled"
            echo "  • Kubernetes resources may remain"
            ;;
    esac
    
    echo ""
    read -p "Are you sure you want to proceed? (yes/no): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        log_info "Cleanup cancelled by user"
        exit 0
    fi
}

# Backup database before cleanup
backup_database() {
    log_info "Attempting to backup database..."
    
    # Check if PostgreSQL pod exists and is running
    local postgres_pod=$(kubectl get pods -n $NAMESPACE -l app=postgres --no-headers 2>/dev/null | grep "Running" | head -1 | awk '{print $1}')
    
    if [ -n "$postgres_pod" ]; then
        local backup_file="tweetstream-backup-$(date +%Y%m%d-%H%M%S).sql"
        
        log_info "Creating database backup: $backup_file"
        
        if kubectl exec -n $NAMESPACE "$postgres_pod" -- pg_dump -U tweetuser tweetstream > "$backup_file" 2>/dev/null; then
            log_success "Database backup created: $backup_file"
            echo "Backup location: $(pwd)/$backup_file"
        else
            log_warning "Failed to create database backup"
            read -p "Continue without backup? (yes/no): " continue_without_backup
            if [ "$continue_without_backup" != "yes" ]; then
                log_info "Cleanup cancelled"
                exit 0
            fi
        fi
    else
        log_warning "PostgreSQL pod not found or not running, skipping backup"
    fi
}

# Remove Helm release
remove_helm_release() {
    log_info "Removing Helm release..."
    
    if helm list -n $NAMESPACE 2>/dev/null | grep -q tweetstream; then
        helm uninstall tweetstream -n $NAMESPACE
        log_success "Helm release 'tweetstream' removed"
    else
        log_info "No Helm release 'tweetstream' found"
    fi
}

# Remove persistent volumes
remove_persistent_volumes() {
    log_info "Removing persistent volume claims..."
    
    local pvcs=$(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null | awk '{print $1}')
    
    if [ -n "$pvcs" ]; then
        for pvc in $pvcs; do
            log_info "Removing PVC: $pvc"
            kubectl delete pvc -n $NAMESPACE "$pvc" --timeout=60s
        done
        log_success "All PVCs removed"
    else
        log_info "No PVCs found"
    fi
}

# Remove namespace
remove_namespace() {
    log_info "Removing namespace..."
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        kubectl delete namespace $NAMESPACE --timeout=120s
        log_success "Namespace '$NAMESPACE' removed"
    else
        log_info "Namespace '$NAMESPACE' does not exist"
    fi
}

# Force cleanup stuck resources
force_cleanup() {
    log_warning "Attempting force cleanup of stuck resources..."
    
    # Force delete pods
    local stuck_pods=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -E "(Terminating|Unknown)" | awk '{print $1}')
    if [ -n "$stuck_pods" ]; then
        for pod in $stuck_pods; do
            log_info "Force deleting stuck pod: $pod"
            kubectl delete pod -n $NAMESPACE "$pod" --force --grace-period=0 2>/dev/null || true
        done
    fi
    
    # Force delete PVCs
    local stuck_pvcs=$(kubectl get pvc -n $NAMESPACE --no-headers 2>/dev/null | grep "Terminating" | awk '{print $1}')
    if [ -n "$stuck_pvcs" ]; then
        for pvc in $stuck_pvcs; do
            log_info "Force deleting stuck PVC: $pvc"
            kubectl patch pvc -n $NAMESPACE "$pvc" -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
        done
    fi
    
    # Force delete namespace if stuck
    if kubectl get namespace $NAMESPACE 2>/dev/null | grep -q "Terminating"; then
        log_info "Force deleting stuck namespace"
        kubectl patch namespace $NAMESPACE -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
    fi
}

# Clean up Docker images (optional)
cleanup_docker_images() {
    log_info "Cleaning up Docker images..."
    
    # Remove TweetStream images from Docker
    if sudo docker images | grep -q "tweetstream"; then
        log_info "Removing TweetStream Docker images..."
        sudo docker rmi $(sudo docker images | grep "tweetstream" | awk '{print $3}') 2>/dev/null || true
        log_success "TweetStream Docker images removed"
    else
        log_info "No TweetStream Docker images found"
    fi
    
    # Remove images from containerd
    if sudo ctr -n k8s.io images ls | grep -q "tweetstream"; then
        log_info "Removing TweetStream containerd images..."
        sudo ctr -n k8s.io images rm $(sudo ctr -n k8s.io images ls | grep "tweetstream" | awk '{print $1}') 2>/dev/null || true
        log_success "TweetStream containerd images removed"
    else
        log_info "No TweetStream containerd images found"
    fi
}

# Complete cleanup
complete_cleanup() {
    log_info "Starting complete cleanup..."
    
    backup_database
    remove_helm_release
    
    # Wait a bit for graceful termination
    sleep 5
    
    remove_persistent_volumes
    remove_namespace
    
    # Check if cleanup was successful
    sleep 10
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log_warning "Namespace still exists, attempting force cleanup..."
        force_cleanup
        sleep 5
    fi
    
    log_success "Complete cleanup finished"
}

# App-only cleanup (preserve data)
app_only_cleanup() {
    log_info "Starting application-only cleanup (preserving data)..."
    
    remove_helm_release
    
    # Remove deployments and services but keep PVCs
    log_info "Removing deployments and services..."
    kubectl delete deployments,services,ingress -n $NAMESPACE --all --timeout=60s 2>/dev/null || true
    
    log_success "Application cleanup finished (data preserved)"
}

# Helm-only cleanup
helm_only_cleanup() {
    log_info "Starting Helm-only cleanup..."
    
    remove_helm_release
    
    log_success "Helm cleanup finished"
}

# Show cleanup options
show_cleanup_options() {
    echo ""
    log_info "Choose cleanup option:"
    echo "1) Complete cleanup (removes everything including data)"
    echo "2) Application only (preserves persistent data)"
    echo "3) Helm release only (minimal cleanup)"
    echo "4) Docker images cleanup (removes local images)"
    echo "5) Force cleanup (for stuck resources)"
    echo "6) Cancel"
    echo ""
    
    while true; do
        read -p "Enter your choice (1-6): " choice
        case $choice in
            1)
                confirm_cleanup "complete"
                complete_cleanup
                break
                ;;
            2)
                confirm_cleanup "app-only"
                app_only_cleanup
                break
                ;;
            3)
                confirm_cleanup "helm-only"
                helm_only_cleanup
                break
                ;;
            4)
                echo ""
                log_warning "This will remove all TweetStream Docker and containerd images"
                read -p "Are you sure? (yes/no): " confirm_images
                if [ "$confirm_images" = "yes" ]; then
                    cleanup_docker_images
                fi
                break
                ;;
            5)
                echo ""
                log_warning "This will force delete stuck resources"
                read -p "Are you sure? (yes/no): " confirm_force
                if [ "$confirm_force" = "yes" ]; then
                    force_cleanup
                fi
                break
                ;;
            6)
                log_info "Cleanup cancelled"
                exit 0
                ;;
            *)
                log_error "Invalid choice. Please enter 1-6."
                ;;
        esac
    done
}

# Verify cleanup
verify_cleanup() {
    log_info "Verifying cleanup..."
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log_warning "Namespace still exists"
        kubectl get all -n $NAMESPACE 2>/dev/null || true
    else
        log_success "Namespace successfully removed"
    fi
    
    # Check for remaining resources
    local remaining_pvs=$(kubectl get pv 2>/dev/null | grep "$NAMESPACE" | wc -l)
    if [ $remaining_pvs -gt 0 ]; then
        log_warning "$remaining_pvs persistent volumes may still exist"
        kubectl get pv | grep "$NAMESPACE" 2>/dev/null || true
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --complete      Complete cleanup (removes everything)"
    echo "  --app-only      Application only (preserves data)"
    echo "  --helm-only     Helm release only"
    echo "  --images        Docker images cleanup"
    echo "  --force         Force cleanup stuck resources"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Interactive cleanup"
    echo "  $0 --complete   # Complete cleanup"
    echo "  $0 --app-only   # Preserve data"
    echo "  $0 --force      # Force cleanup"
}

# Main function
main() {
    echo "🧹 TweetStream Cleanup Script"
    echo "============================="
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    show_current_status
    
    # Handle command line arguments
    case "$1" in
        --complete)
            confirm_cleanup "complete"
            complete_cleanup
            ;;
        --app-only)
            confirm_cleanup "app-only"
            app_only_cleanup
            ;;
        --helm-only)
            confirm_cleanup "helm-only"
            helm_only_cleanup
            ;;
        --images)
            echo ""
            log_warning "This will remove all TweetStream Docker and containerd images"
            read -p "Are you sure? (yes/no): " confirm_images
            if [ "$confirm_images" = "yes" ]; then
                cleanup_docker_images
            fi
            ;;
        --force)
            echo ""
            log_warning "This will force delete stuck resources"
            read -p "Are you sure? (yes/no): " confirm_force
            if [ "$confirm_force" = "yes" ]; then
                force_cleanup
            fi
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        "")
            show_cleanup_options
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
    
    verify_cleanup
    
    echo ""
    log_success "🎉 Cleanup completed!"
}

# Run main function
main "$@" 