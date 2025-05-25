# TweetStream Deployment Guide

## 📋 Overview

TweetStream is a Twitter-like application deployed on Kubernetes with the following architecture:

- **Frontend**: NGINX serving React-like UI
- **API**: Node.js Express server
- **Database**: PostgreSQL 15 with Twitter-like schema
- **Cache**: Redis for session management
- **Message Queue**: Apache Kafka (optional)
- **Monitoring**: Prometheus + Grafana (optional)

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   NGINX Ingress │    │   TweetStream   │    │   TweetStream   │
│   Controller    │───▶│   Frontend      │───▶│   API Server    │
│   (Port 30080)  │    │   (NGINX)       │    │   (Node.js)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                       ┌─────────────────┐             │
                       │     Redis       │◀────────────┤
                       │     Cache       │             │
                       └─────────────────┘             │
                                                        │
                       ┌─────────────────┐             │
                       │   PostgreSQL    │◀────────────┘
                       │   Database      │
                       └─────────────────┘
```

## 🚀 Quick Start (Current Deployment)

### Prerequisites
- Kubernetes cluster with 6 nodes (1 master + 5 workers)
- NGINX Ingress Controller installed
- Helm 3.x installed
- Docker images built locally on master node

### Current Status ✅
```bash
# Check deployment status
kubectl get pods -n tweetstream -o wide
kubectl get svc -n tweetstream
kubectl get ingress -n tweetstream

# Access application
curl -H "Host: tweetstream.192.168.1.82.nip.io" http://192.168.1.82:30080/
```

**Application URL**: `http://192.168.1.82:30080/` (with Host header: `tweetstream.192.168.1.82.nip.io`)

## ⚠️ Current Temporary Workaround

The current deployment uses a **temporary workaround** due to Docker image distribution issues:

### Issues Addressed:
1. **Image Availability**: Custom images only exist on master node
2. **Resource Constraints**: Master node at 95% CPU allocation
3. **Security Context**: NGINX permission issues with restrictive security

### Temporary Solutions Applied:
- ✅ **Node Selector**: Forces application pods to master node only
- ✅ **Tolerations**: Allows scheduling on master node (control plane)
- ✅ **Minimal Resources**: Ultra-low CPU/memory requests (50m CPU, 128Mi RAM)
- ✅ **Disabled Security Context**: Allows NGINX to create temp directories
- ✅ **Image Import**: Imported Docker images into containerd manually

### Current Configuration:
```yaml
# From values-minimal.yaml
nodeSelector:
  kubernetes.io/hostname: master-node

tolerations:
- key: node-role.kubernetes.io/control-plane
  operator: Exists
  effect: NoSchedule

security:
  podSecurityContext: null
  securityContext: null

resources:
  api:
    requests:
      cpu: 50m
      memory: 128Mi
  frontend:
    requests:
      cpu: 25m
      memory: 32Mi
```

## 🏭 Production Solutions

### Option 1: GitHub Container Registry (Recommended)

**Benefits**: Free, reliable, global CDN, proper versioning

```bash
# 1. Setup GitHub Container Registry
cd helm-chart
chmod +x push-to-ghcr.sh

# 2. Edit script with your GitHub username
vim push-to-ghcr.sh  # Set GITHUB_USERNAME

# 3. Create GitHub Personal Access Token
# - Go to GitHub Settings > Developer settings > Personal access tokens
# - Create token with 'write:packages' scope

# 4. Login and push images
echo $GITHUB_TOKEN | sudo docker login ghcr.io -u YOUR_USERNAME --password-stdin
./push-to-ghcr.sh

# 5. Update values.yaml
global:
  imageRegistry: "ghcr.io/YOUR_USERNAME"

api:
  image:
    repository: tweetstream-api
    pullPolicy: IfNotPresent

frontend:
  image:
    repository: tweetstream-frontend
    pullPolicy: IfNotPresent

# 6. Remove temporary workarounds
nodeSelector: {}
tolerations: []
security:
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 1001
    fsGroup: 1001
```

### Option 2: Fix Local Registry

**Benefits**: No external dependencies, faster pulls

```bash
# Configure all nodes to trust local registry
cd helm-chart
chmod +x fix-local-registry.sh
./fix-local-registry.sh

# This will:
# - Configure Docker daemon on all nodes
# - Add insecure registry configuration
# - Test image pulls from worker nodes
# - Restart Docker service as needed
```

### Option 3: Manual Image Distribution

**Benefits**: Simple, immediate solution

```bash
# Copy images to all worker nodes
for node in sanzad-ubuntu-21 sanzad-ubuntu-22 sanzad-ubuntu-23 sanzad-ubuntu-94 sanzad-ubuntu-95; do
    echo "Copying images to $node..."
    sudo docker save tweetstream/api:1.0.0 | ssh $node 'sudo ctr -n k8s.io images import -'
    sudo docker save tweetstream/frontend:1.0.0 | ssh $node 'sudo ctr -n k8s.io images import -'
done
```

## 📁 File Structure

```
tweetstream-app/
├── helm-chart/
│   ├── tweetstream/
│   │   ├── templates/          # Kubernetes manifests
│   │   ├── values.yaml         # Default configuration
│   │   ├── values-minimal.yaml # Current temporary config
│   │   └── values-master-only.yaml # Master node only config
│   ├── push-to-ghcr.sh        # GitHub Container Registry script
│   └── fix-local-registry.sh   # Local registry fix script
├── docs/
│   └── deployment-guides/
│       ├── README.md           # This file
│       ├── troubleshooting.md  # Common issues and solutions
│       ├── production-setup.md # Production deployment guide
│       └── monitoring-setup.md # Monitoring configuration
└── scripts/
    ├── deploy-production.sh    # Production deployment script
    ├── cleanup.sh             # Cleanup script
    └── health-check.sh        # Health check script
```

## 🔧 Configuration Files

### Current Deployment (Temporary)
- **File**: `helm-chart/tweetstream/values-minimal.yaml`
- **Purpose**: Ultra-low resources for master node deployment
- **Status**: ✅ Working but temporary

### Production Ready
- **File**: `helm-chart/tweetstream/values.yaml`
- **Purpose**: Full production configuration with HA, monitoring, security
- **Status**: ⏳ Requires image distribution solution

### Master Node Only
- **File**: `helm-chart/tweetstream/values-master-only.yaml`
- **Purpose**: Intermediate configuration for master node with normal resources
- **Status**: 📋 Alternative to minimal config

## 🚨 Known Issues & Solutions

### Issue 1: ErrImageNeverPull
**Cause**: Images don't exist on worker nodes
**Solution**: Use one of the production solutions above

### Issue 2: Insufficient CPU
**Cause**: Master node resource constraints
**Solution**: Use minimal resources or distribute to worker nodes

### Issue 3: NGINX Permission Denied
**Cause**: Restrictive security context
**Solution**: Temporarily disabled security context (not production-ready)

### Issue 4: Pod Scheduling Failures
**Cause**: Node affinity/selector restrictions
**Solution**: Remove nodeSelector after fixing image distribution

## 📊 Resource Usage

### Current (Minimal Configuration)
```
Component    CPU Request  Memory Request  CPU Limit   Memory Limit
---------    -----------  --------------  ---------   ------------
API          50m          128Mi          100m        256Mi
Frontend     25m          32Mi           50m         64Mi
PostgreSQL   100m         256Mi          500m        512Mi
Redis        50m          64Mi           100m        128Mi
Total        225m         480Mi          750m        960Mi
```

### Production (Recommended)
```
Component    CPU Request  Memory Request  CPU Limit   Memory Limit
---------    -----------  --------------  ---------   ------------
API (3x)     600m         768Mi          1500m       1536Mi
Frontend(2x) 200m         128Mi          400m        256Mi
PostgreSQL   500m         512Mi          1000m       1Gi
Redis        100m         128Mi          200m        256Mi
Kafka        500m         512Mi          1000m       1Gi
Monitoring   300m         384Mi          600m        768Mi
Total        2200m        2432Mi         4700m       5632Mi
```

## 🔍 Monitoring & Health Checks

### Health Endpoints
- **API Health**: `http://192.168.1.82:30080/api/health`
- **API Ready**: `http://192.168.1.82:30080/api/ready`
- **Frontend**: `http://192.168.1.82:30080/`

### Useful Commands
```bash
# Check pod status
kubectl get pods -n tweetstream -o wide

# Check logs
kubectl logs -n tweetstream -l component=api
kubectl logs -n tweetstream -l component=frontend

# Check resource usage
kubectl top pods -n tweetstream
kubectl top nodes

# Port forward for debugging
kubectl port-forward -n tweetstream svc/tweetstream-api 3000:3000
kubectl port-forward -n tweetstream svc/tweetstream-frontend 8080:80
```

## 🎯 Next Steps

1. **Choose Production Solution**: Select GitHub Container Registry, local registry fix, or manual distribution
2. **Implement Image Distribution**: Run the appropriate script
3. **Update Configuration**: Switch from `values-minimal.yaml` to `values.yaml`
4. **Enable Security**: Restore proper security contexts
5. **Add Monitoring**: Enable Prometheus and Grafana
6. **Add Kafka**: Enable message queue for real-time features
7. **Setup CI/CD**: Implement GitOps with ArgoCD

## 📞 Support

For issues or questions:
1. Check `troubleshooting.md` for common problems
2. Review pod logs: `kubectl logs -n tweetstream <pod-name>`
3. Check resource usage: `kubectl describe node <node-name>`
4. Verify image availability: `sudo ctr -n k8s.io images ls | grep tweetstream`

---

**Status**: ✅ Application running with temporary workaround
**Next Action**: Implement production image distribution solution 