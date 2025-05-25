# TweetStream Troubleshooting Guide

## 🚨 Common Issues and Solutions

### 1. Pod Scheduling Issues

#### Issue: `ErrImageNeverPull`
```
Status: ErrImageNeverPull
Message: Container image "tweetstream/api:1.0.0" is not present with pull policy of Never
```

**Root Cause**: Images don't exist on the target node

**Solutions**:
```bash
# Option A: Import images to containerd (immediate fix)
sudo docker save tweetstream/api:1.0.0 | sudo ctr -n k8s.io images import -
sudo docker save tweetstream/frontend:1.0.0 | sudo ctr -n k8s.io images import -

# Option B: Change pull policy
# In values.yaml:
api:
  image:
    pullPolicy: IfNotPresent  # Instead of Never

# Option C: Use external registry (recommended)
# See production-setup.md for GitHub Container Registry setup
```

#### Issue: `Insufficient CPU`
```
Events:
  Warning  FailedScheduling  0/6 nodes are available: 1 Insufficient cpu
```

**Root Cause**: Node doesn't have enough CPU resources

**Solutions**:
```bash
# Check node resources
kubectl describe node <node-name> | grep -A 10 "Allocated resources"

# Option A: Reduce resource requests
# In values-minimal.yaml:
api:
  resources:
    requests:
      cpu: 50m      # Very low
      memory: 128Mi

# Option B: Scale down other workloads
kubectl scale deployment <other-deployment> --replicas=0

# Option C: Add more nodes or use different nodes
```

#### Issue: `Node Affinity/Selector Mismatch`
```
Events:
  Warning  FailedScheduling  node(s) didn't match Pod's node affinity/selector
```

**Root Cause**: Pod has nodeSelector that doesn't match available nodes

**Solutions**:
```bash
# Check node labels
kubectl get nodes --show-labels

# Option A: Remove nodeSelector (if using temporary config)
# In values.yaml:
nodeSelector: {}

# Option B: Update nodeSelector to match existing nodes
nodeSelector:
  kubernetes.io/hostname: worker-node-1
```

### 2. Application Runtime Issues

#### Issue: NGINX Permission Denied
```
nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
```

**Root Cause**: Restrictive security context prevents NGINX from creating temp directories

**Solutions**:
```bash
# Option A: Disable security context (temporary)
# In values.yaml:
security:
  podSecurityContext: null
  securityContext: null

# Option B: Use proper NGINX user (production)
security:
  podSecurityContext:
    runAsUser: 101  # nginx user
    runAsGroup: 101
    fsGroup: 101
  securityContext:
    runAsUser: 101
    runAsNonRoot: true
    allowPrivilegeEscalation: false
```

#### Issue: Database Connection Failed
```
Error: connect ECONNREFUSED 127.0.0.1:5432
```

**Root Cause**: API can't connect to PostgreSQL

**Solutions**:
```bash
# Check PostgreSQL pod status
kubectl get pods -n tweetstream -l component=database

# Check PostgreSQL logs
kubectl logs -n tweetstream postgres-primary-0

# Test connectivity from API pod
kubectl exec -n tweetstream <api-pod> -- nc -zv postgres-primary 5432

# Check service DNS resolution
kubectl exec -n tweetstream <api-pod> -- nslookup postgres-primary
```

#### Issue: Redis Connection Failed
```
Error: Redis connection failed: connect ECONNREFUSED 127.0.0.1:6379
```

**Root Cause**: API can't connect to Redis

**Solutions**:
```bash
# Check Redis pod status
kubectl get pods -n tweetstream -l component=redis

# Test Redis connectivity
kubectl exec -n tweetstream <api-pod> -- nc -zv redis 6379

# Check Redis logs
kubectl logs -n tweetstream <redis-pod>
```

### 3. Networking Issues

#### Issue: Ingress Not Working
```
curl: (7) Failed to connect to tweetstream.192.168.1.82.nip.io port 80
```

**Root Cause**: Ingress controller or configuration issues

**Solutions**:
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress configuration
kubectl describe ingress -n tweetstream tweetstream

# Test with NodePort directly
curl -H "Host: tweetstream.192.168.1.82.nip.io" http://192.168.1.82:30080/

# Check ingress controller logs
kubectl logs -n ingress-nginx <ingress-controller-pod>
```

#### Issue: Service Not Accessible
```
curl: (7) Failed to connect to 10.98.90.118 port 3000
```

**Root Cause**: Service endpoints not ready

**Solutions**:
```bash
# Check service endpoints
kubectl get endpoints -n tweetstream

# Check if pods are ready
kubectl get pods -n tweetstream

# Test pod directly
kubectl exec -n tweetstream <api-pod> -- curl localhost:3000/health
```

### 4. Resource Issues

#### Issue: Out of Memory (OOMKilled)
```
Status: Failed
Reason: OOMKilled
```

**Root Cause**: Pod exceeded memory limits

**Solutions**:
```bash
# Check memory usage
kubectl top pods -n tweetstream

# Increase memory limits
# In values.yaml:
api:
  resources:
    limits:
      memory: 512Mi  # Increase from 256Mi

# Check for memory leaks in application logs
kubectl logs -n tweetstream <pod-name> --previous
```

#### Issue: CPU Throttling
```
# High CPU throttling in metrics
```

**Root Cause**: Pod hitting CPU limits

**Solutions**:
```bash
# Check CPU usage
kubectl top pods -n tweetstream

# Increase CPU limits
# In values.yaml:
api:
  resources:
    limits:
      cpu: 500m  # Increase from 200m

# Scale horizontally instead
api:
  replicaCount: 3
```

### 5. Storage Issues

#### Issue: PostgreSQL Pod Stuck in Pending
```
Status: Pending
Events:
  Warning  FailedScheduling  pod has unbound immediate PersistentVolumeClaims
```

**Root Cause**: No available storage or StorageClass issues

**Solutions**:
```bash
# Check PVC status
kubectl get pvc -n tweetstream

# Check StorageClass
kubectl get storageclass

# Check available storage on nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Use different StorageClass
# In values.yaml:
database:
  persistence:
    storageClass: "local-path"  # or "standard"
```

### 6. Image Registry Issues

#### Issue: Local Registry Not Accessible
```
Error: failed to pull image "192.168.1.82:5555/tweetstream/api:1.0.0": failed to resolve reference
```

**Root Cause**: Worker nodes can't access local registry

**Solutions**:
```bash
# Run the registry fix script
cd helm-chart
./fix-local-registry.sh

# Or manually configure each node
sudo tee /etc/docker/daemon.json <<EOF
{
  "insecure-registries": ["192.168.1.82:5555"]
}
EOF
sudo systemctl restart docker
```

## 🔍 Debugging Commands

### Pod Debugging
```bash
# Get detailed pod information
kubectl describe pod -n tweetstream <pod-name>

# Check pod logs
kubectl logs -n tweetstream <pod-name> -f

# Get previous container logs (if crashed)
kubectl logs -n tweetstream <pod-name> --previous

# Execute commands in pod
kubectl exec -n tweetstream <pod-name> -it -- /bin/sh

# Check pod events
kubectl get events -n tweetstream --sort-by='.lastTimestamp'
```

### Network Debugging
```bash
# Test service connectivity
kubectl run debug --image=busybox -it --rm -- sh
# Inside the pod:
nc -zv tweetstream-api.tweetstream.svc.cluster.local 3000

# Check DNS resolution
kubectl exec -n tweetstream <pod> -- nslookup kubernetes.default

# Port forward for local testing
kubectl port-forward -n tweetstream svc/tweetstream-api 3000:3000
```

### Resource Debugging
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n tweetstream

# Check resource quotas
kubectl describe resourcequota -n tweetstream

# Check node capacity
kubectl describe node <node-name>
```

### Image Debugging
```bash
# Check images on node
sudo ctr -n k8s.io images ls | grep tweetstream

# Check Docker images
sudo docker images | grep tweetstream

# Import image manually
sudo docker save tweetstream/api:1.0.0 | sudo ctr -n k8s.io images import -
```

## 🚨 Emergency Procedures

### Complete Application Reset
```bash
# Delete everything
helm uninstall tweetstream -n tweetstream
kubectl delete namespace tweetstream

# Redeploy
kubectl create namespace tweetstream
helm install tweetstream ./helm-chart/tweetstream -n tweetstream -f values-minimal.yaml
```

### Master Node Resource Recovery
```bash
# Scale down non-essential workloads
kubectl scale deployment -n kube-system coredns --replicas=1

# Check what's consuming resources
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Force delete stuck pods
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0
```

### Database Recovery
```bash
# Backup database (if accessible)
kubectl exec -n tweetstream postgres-primary-0 -- pg_dump -U tweetuser tweetstream > backup.sql

# Reset database
kubectl delete statefulset -n tweetstream postgres-primary
kubectl delete pvc -n tweetstream postgres-primary-data-postgres-primary-0

# Redeploy database
helm upgrade tweetstream ./helm-chart/tweetstream -n tweetstream -f values-minimal.yaml
```

## 📞 Getting Help

### Log Collection
```bash
# Collect all logs
mkdir -p tweetstream-logs
kubectl logs -n tweetstream -l component=api > tweetstream-logs/api.log
kubectl logs -n tweetstream -l component=frontend > tweetstream-logs/frontend.log
kubectl logs -n tweetstream postgres-primary-0 > tweetstream-logs/postgres.log
kubectl get events -n tweetstream > tweetstream-logs/events.log
kubectl describe pods -n tweetstream > tweetstream-logs/pod-descriptions.log
```

### System Information
```bash
# Cluster information
kubectl cluster-info
kubectl get nodes -o wide
kubectl version

# Resource information
kubectl top nodes
kubectl describe nodes

# Network information
kubectl get svc --all-namespaces
kubectl get ingress --all-namespaces
```

---

**Remember**: Always check the main README.md for current deployment status and configuration details. 