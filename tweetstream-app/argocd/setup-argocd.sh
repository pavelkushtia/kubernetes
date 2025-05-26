#!/bin/bash

# ArgoCD Setup Script for TweetStream GitOps
# This script installs ArgoCD and configures it for continuous deployment

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

print_status $BLUE "🚀 Setting up ArgoCD for TweetStream GitOps"
print_status $BLUE "============================================="

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

# Install ArgoCD
print_status $BLUE "📦 Installing ArgoCD..."
kubectl apply -f argocd-setup.yaml

print_status $BLUE "🔐 Applying RBAC configuration..."
kubectl apply -f argocd-rbac.yaml

# Wait for ArgoCD pods to be ready
print_status $BLUE "⏳ Waiting for ArgoCD pods to be ready..."

# Function to wait for pods
wait_for_pods() {
    local namespace=$1
    local app=$2
    local timeout=${3:-300}
    
    print_status $BLUE "⏳ Waiting for $app pods to be ready in namespace $namespace..."
    
    if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=$app -n $namespace --timeout=${timeout}s; then
        print_status $GREEN "✅ $app pods are ready!"
    else
        print_status $RED "❌ Timeout waiting for $app pods to be ready"
        return 1
    fi
}

# Wait for ArgoCD components
wait_for_pods "argocd" "argocd-server" 180
wait_for_pods "argocd" "argocd-application-controller" 180
wait_for_pods "argocd" "argocd-repo-server" 120
wait_for_pods "argocd" "argocd-redis" 120

# Get ArgoCD admin password
print_status $BLUE "🔑 Retrieving ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")

if [ -z "$ARGOCD_PASSWORD" ]; then
    print_status $YELLOW "⚠️  ArgoCD admin secret not found. Creating default admin user..."
    # Create a default admin password
    ARGOCD_PASSWORD="admin123"
    kubectl -n argocd patch secret argocd-secret \
        -p '{"stringData": {"admin.password": "'$(echo -n $ARGOCD_PASSWORD | htpasswd -bnBC 10 "" | tr -d ':\n')'", "admin.passwordMtime": "'$(date +%FT%T%Z)'"}}'
fi

# Check ingress
print_status $BLUE "🌐 Checking ArgoCD ingress..."
if kubectl get ingress argocd-server-ingress -n argocd &> /dev/null; then
    ARGOCD_URL="http://argocd.192.168.1.82.nip.io:30080"
    print_status $GREEN "✅ ArgoCD ingress configured: $ARGOCD_URL"
else
    print_status $RED "❌ ArgoCD ingress not found"
fi

# Display ArgoCD information
print_status $GREEN "🎉 ArgoCD Installation Complete!"
print_status $GREEN "================================="
echo ""
print_status $BLUE "🌐 Access Information:"
print_status $GREEN "  • ArgoCD UI: $ARGOCD_URL"
print_status $GREEN "  • Username: admin"
print_status $GREEN "  • Password: $ARGOCD_PASSWORD"
echo ""

print_status $BLUE "📋 ArgoCD Status:"
echo "=================="
kubectl get pods -n argocd

print_status $BLUE "🔧 Next Steps:"
echo "==============="
echo "1. Access ArgoCD UI at: $ARGOCD_URL"
echo "2. Login with admin/$ARGOCD_PASSWORD"
echo "3. Create a Git repository with your TweetStream files"
echo "4. Update tweetstream-argocd-app.yaml with your Git repo URL"
echo "5. Apply the ArgoCD application:"
echo "   kubectl apply -f tweetstream-argocd-app.yaml"
echo ""

print_status $YELLOW "💡 Git Repository Setup:"
echo "========================="
echo "1. Create a new GitHub repository (e.g., kubernetes-tweetstream)"
echo "2. Push your tweetstream-app directory to the repository:"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial TweetStream application'"
echo "   git branch -M main"
echo "   git remote add origin https://github.com/YOUR_USERNAME/kubernetes-tweetstream.git"
echo "   git push -u origin main"
echo ""
echo "3. Update the repoURL in tweetstream-argocd-app.yaml"
echo "4. Apply the ArgoCD application configuration"
echo ""

print_status $BLUE "🔍 Useful Commands:"
echo "==================="
echo "# Check ArgoCD pods"
echo "kubectl get pods -n argocd"
echo ""
echo "# Port forward ArgoCD (if ingress not working)"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "# Get ArgoCD admin password"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "# Apply TweetStream application"
echo "kubectl apply -f tweetstream-argocd-app.yaml"
echo ""
echo "# Watch ArgoCD applications"
echo "kubectl get applications -n argocd -w"
echo ""

print_status $GREEN "🚀 ArgoCD is ready for GitOps deployment!"

# Optional: Install ArgoCD CLI
print_status $BLUE "📥 ArgoCD CLI Installation (Optional):"
echo "======================================"
echo "# Download and install ArgoCD CLI"
echo "curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
echo "sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd"
echo "rm argocd-linux-amd64"
echo ""
echo "# Login to ArgoCD CLI"
echo "argocd login argocd.192.168.1.82.nip.io:30080 --username admin --password $ARGOCD_PASSWORD --insecure"
echo ""

print_status $YELLOW "⚠️  Security Note:"
echo "=================="
echo "This setup uses insecure mode for development. For production:"
echo "1. Enable TLS/SSL"
echo "2. Use proper authentication (OIDC, LDAP, etc.)"
echo "3. Configure RBAC properly"
echo "4. Use secrets management for sensitive data" 