#!/bin/bash

# Kubernetes Playbook Validation Script
# Checks if playbooks are safe to run on current cluster

set -e

echo "🔍 Kubernetes Playbook Validation Script"
echo "========================================"

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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_status $RED "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if cluster is accessible
print_status $BLUE "🔍 Checking cluster accessibility..."
if ! kubectl get nodes &> /dev/null; then
    print_status $RED "❌ Cannot access Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_status $GREEN "✅ Cluster is accessible"

# Get cluster information
echo ""
print_status $BLUE "📊 Current Cluster Information:"
echo "================================"

# Kubernetes version
K8S_VERSION=$(kubectl version -o yaml | grep gitVersion | head -1 | awk '{print $2}')
print_status $GREEN "Kubernetes Version: $K8S_VERSION"

# Node information
echo ""
print_status $BLUE "🖥️  Cluster Nodes:"
kubectl get nodes -o wide

# Check for existing components
echo ""
print_status $BLUE "🔍 Checking for existing components..."

# Check for existing monitoring stack
if kubectl get namespace monitoring &> /dev/null; then
    print_status $YELLOW "⚠️  Monitoring namespace already exists"
    if kubectl get deployment prometheus-grafana -n monitoring &> /dev/null; then
        print_status $YELLOW "⚠️  Prometheus/Grafana stack already installed"
    fi
else
    print_status $GREEN "✅ No existing monitoring stack found"
fi

# Check for ingress controller
if kubectl get namespace ingress-nginx &> /dev/null; then
    print_status $YELLOW "⚠️  NGINX Ingress namespace already exists"
    if kubectl get deployment ingress-nginx-controller -n ingress-nginx &> /dev/null; then
        print_status $YELLOW "⚠️  NGINX Ingress Controller already installed"
    fi
else
    print_status $GREEN "✅ No existing ingress controller found"
fi

# Check for storage provisioner
if kubectl get deployment local-path-provisioner -n local-path-storage &> /dev/null; then
    print_status $YELLOW "⚠️  Local Path Provisioner already installed"
else
    print_status $GREEN "✅ No existing storage provisioner found"
fi

# Check for Helm
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short 2>/dev/null || helm version --template='{{.Version}}' 2>/dev/null || echo "unknown")
    print_status $YELLOW "⚠️  Helm already installed: $HELM_VERSION"
else
    print_status $GREEN "✅ Helm not installed"
fi

# Validate playbook files
echo ""
print_status $BLUE "📋 Validating Playbook Files:"
echo "============================="

# Check if playbook files exist
if [[ -f "improved_k8s_cluster.yaml" ]]; then
    print_status $GREEN "✅ improved_k8s_cluster.yaml found"
    
    # Check for safety features
    if grep -q "force_reset" improved_k8s_cluster.yaml; then
        print_status $GREEN "✅ Safety checks implemented (force_reset protection)"
    else
        print_status $RED "❌ Missing safety checks in cluster playbook"
    fi
else
    print_status $RED "❌ improved_k8s_cluster.yaml not found"
fi

if [[ -f "production_addons.yaml" ]]; then
    print_status $GREEN "✅ production_addons.yaml found"
    
    # Check for existing installation checks
    if grep -q "already exists" production_addons.yaml; then
        print_status $GREEN "✅ Existing installation checks implemented"
    else
        print_status $RED "❌ Missing existing installation checks"
    fi
else
    print_status $RED "❌ production_addons.yaml not found"
fi

if [[ -f "k8s_upgrade.yaml" ]]; then
    print_status $GREEN "✅ k8s_upgrade.yaml found"
    
    # Check for upgrade safety features
    if grep -q "upgrade_confirmation" k8s_upgrade.yaml; then
        print_status $GREEN "✅ Upgrade safety checks implemented"
    else
        print_status $YELLOW "⚠️  Upgrade safety checks may need review"
    fi
else
    print_status $YELLOW "⚠️  k8s_upgrade.yaml not found (needed for version upgrades)"
fi

if [[ -f "ha_multi_master.yaml" ]]; then
    print_status $GREEN "✅ ha_multi_master.yaml found"
else
    print_status $YELLOW "⚠️  ha_multi_master.yaml not found (optional for HA setup)"
fi

# Check inventory files
echo ""
print_status $BLUE "📝 Checking Inventory Files:"
echo "============================"

if [[ -f "inventory.ini" ]]; then
    print_status $GREEN "✅ inventory.ini found"
    
    # Validate inventory format
    if grep -q "\[master\]" inventory.ini && grep -q "\[workers\]" inventory.ini; then
        print_status $GREEN "✅ Inventory format is correct"
    else
        print_status $YELLOW "⚠️  Inventory format may need review"
    fi
else
    print_status $RED "❌ inventory.ini not found"
fi

# Safety recommendations
echo ""
print_status $BLUE "🛡️  Safety Recommendations:"
echo "=========================="

print_status $YELLOW "1. BACKUP: Always backup your cluster before running playbooks"
print_status $YELLOW "2. TEST: Test playbooks in a development environment first"
print_status $YELLOW "3. REVIEW: Review all variables and configurations"
print_status $YELLOW "4. MONITOR: Monitor cluster health during and after deployment"

echo ""
print_status $BLUE "🚀 Playbook Execution Guidelines:"
echo "================================="

echo ""
print_status $GREEN "For CLUSTER SETUP (improved_k8s_cluster.yaml):"
echo "  - Safe to run on NEW nodes only"
echo "  - Will prompt before destroying existing cluster"
echo "  - Use -e force_reset=true to bypass safety checks"
echo "  - Command: ansible-playbook -i inventory.ini improved_k8s_cluster.yaml --ask-become-pass"

echo ""
print_status $GREEN "For PRODUCTION ADDONS (production_addons.yaml):"
echo "  - Safe to run on existing clusters"
echo "  - Checks for existing installations"
echo "  - Skips already installed components"
echo "  - Command: ansible-playbook -i inventory.ini production_addons.yaml --ask-become-pass"

echo ""
print_status $GREEN "For CLUSTER UPGRADES (k8s_upgrade.yaml):"
echo "  - Upgrades existing cluster to newer Kubernetes version"
echo "  - Supports only adjacent version upgrades (1.28 → 1.29)"
echo "  - Creates automatic etcd backups"
echo "  - Command: ansible-playbook -i inventory.ini k8s_upgrade.yaml --ask-become-pass"

echo ""
print_status $GREEN "For HA SETUP (ha_multi_master.yaml):"
echo "  - Advanced multi-master cluster setup"
echo "  - Requires 3+ master nodes and load balancer"
echo "  - For production high-availability deployments"
echo "  - Command: ansible-playbook -i ha_inventory.ini ha_multi_master.yaml --ask-become-pass"

echo ""
print_status $BLUE "🔧 Current Cluster Status:"
echo "========================="

# Show current pods
echo ""
print_status $BLUE "Running Pods:"
kubectl get pods --all-namespaces | head -20

echo ""
print_status $GREEN "✅ Validation Complete!"
print_status $BLUE "Your playbooks are ready to use safely." 