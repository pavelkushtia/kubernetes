# TweetStream Production Setup Guide

## 🎯 Overview

This guide covers the complete production deployment of TweetStream, moving from the current temporary setup to a robust, scalable production environment.

## 📋 Prerequisites

### Infrastructure Requirements
- **Kubernetes Cluster**: 6+ nodes (1 master + 5+ workers)
- **CPU**: Minimum 8 cores total across workers
- **Memory**: Minimum 16GB total across workers
- **Storage**: 100GB+ available for persistent volumes
- **Network**: Stable connectivity between all nodes

### Software Requirements
- **Kubernetes**: v1.28+ 
- **Helm**: v3.8+
- **Docker**: v20.10+ (for image building)
- **kubectl**: Latest version
- **Git**: For version control (optional)

### Access Requirements
- **Cluster Admin**: Full access to Kubernetes cluster
- **Registry Access**: GitHub account or local registry setup
- **SSH Access**: To all worker nodes (for manual distribution)

## 🚀 Production Deployment Options

### Option 1: GitHub Container Registry (Recommended)

**Best for**: Production environments, CI/CD pipelines, multi-environment deployments

#### Step 1: Setup GitHub Container Registry

```bash
# 1. Create GitHub Personal Access Token
# Go to: GitHub Settings > Developer settings > Personal access tokens > Tokens (classic)
# Create token with 'write:packages' scope

# 2. Login to GitHub Container Registry
export GITHUB_USERNAME="your-github-username"
export GITHUB_TOKEN="your-personal-access-token"
echo $GITHUB_TOKEN | sudo docker login ghcr.io -u $GITHUB_USERNAME --password-stdin
```

#### Step 2: Push Images to GHCR

```bash
# Navigate to TweetStream directory
cd /home/sanzad/kubernetes/tweetstream-app

# Run the automated deployment script
chmod +x scripts/deploy-production.sh
./scripts/deploy-production.sh

# Select option 1 (GitHub Container Registry)
# Enter your GitHub username when prompted
```

#### Step 3: Production Configuration

The script will automatically create a production values file:

```yaml
# production-values.yaml (auto-generated)
global:
  imageRegistry: "ghcr.io/your-username"

api:
  replicaCount: 3
  image:
    repository: tweetstream-api
    tag: "1.0.0"
    pullPolicy: IfNotPresent
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70

frontend:
  replicaCount: 2
  image:
    repository: tweetstream-frontend
    tag: "1.0.0"
    pullPolicy: IfNotPresent
  resources:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 100m
      memory: 64Mi
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilizationPercentage: 70

# Security context restored
security:
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 1001
    fsGroup: 1001
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: false
    runAsNonRoot: true
    runAsUser: 1001

# Enable monitoring and Kafka
monitoring:
  enabled: true
kafka:
  enabled: true
```

### Option 2: Local Registry Setup

**Best for**: On-premise deployments, air-gapped environments

#### Step 1: Fix Local Registry Configuration

```bash
# Run the local registry fix script
cd /home/sanzad/kubernetes/tweetstream-app
chmod +x helm-chart/fix-local-registry.sh
./helm-chart/fix-local-registry.sh
```

This script will:
- Configure Docker daemon on all nodes
- Add insecure registry configuration
- Test image pulls from worker nodes
- Restart Docker service as needed

#### Step 2: Deploy with Local Registry

```bash
# Run the deployment script
./scripts/deploy-production.sh

# Select option 2 (Fix Local Registry)
```

### Option 3: Manual Image Distribution

**Best for**: Quick fixes, testing environments

#### Step 1: Distribute Images Manually

```bash
# Get list of worker nodes
kubectl get nodes --no-headers -o custom-columns=":metadata.name" | grep -v master

# Copy images to each worker node
for node in sanzad-ubuntu-21 sanzad-ubuntu-22 sanzad-ubuntu-23 sanzad-ubuntu-94 sanzad-ubuntu-95; do
    echo "Copying images to $node..."
    sudo docker save tweetstream/api:1.0.0 | ssh $node 'sudo ctr -n k8s.io images import -'
    sudo docker save tweetstream/frontend:1.0.0 | ssh $node 'sudo ctr -n k8s.io images import -'
done
```

#### Step 2: Deploy with Manual Distribution

```bash
# Run the deployment script
./scripts/deploy-production.sh

# Select option 3 (Manual Image Distribution)
```

## 🔧 Production Configuration Details

### High Availability Setup

```yaml
# HA Configuration
api:
  replicaCount: 3
  podDisruptionBudget:
    enabled: true
    minAvailable: 2

frontend:
  replicaCount: 2
  podDisruptionBudget:
    enabled: true
    minAvailable: 1

database:
  persistence:
    enabled: true
    size: 50Gi
    storageClass: "fast-ssd"  # Use appropriate storage class
  
  # Database backup configuration
  backup:
    enabled: true
    schedule: "0 2 * * *"  # Daily at 2 AM
    retention: "7d"

redis:
  persistence:
    enabled: true
    size: 10Gi
  
  # Redis clustering for HA
  cluster:
    enabled: true
    nodes: 3
```

### Resource Optimization

```yaml
# Production Resource Allocation
resources:
  api:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi
  
  frontend:
    limits:
      cpu: 500m
      memory: 256Mi
    requests:
      cpu: 200m
      memory: 128Mi
  
  database:
    limits:
      cpu: 2000m
      memory: 4Gi
    requests:
      cpu: 1000m
      memory: 2Gi
  
  redis:
    limits:
      cpu: 500m
      memory: 1Gi
    requests:
      cpu: 200m
      memory: 512Mi
```

### Security Hardening

```yaml
# Production Security Configuration
security:
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 1001
    fsGroup: 1001
    seccompProfile:
      type: RuntimeDefault
  
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 1001

# Network Policies
networkPolicy:
  enabled: true
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: ingress-nginx
      ports:
      - protocol: TCP
        port: 80
      - protocol: TCP
        port: 3000

# Pod Security Standards
podSecurityStandards:
  enforce: "restricted"
  audit: "restricted"
  warn: "restricted"
```

## 📊 Monitoring Setup

### Prometheus Configuration

```yaml
monitoring:
  enabled: true
  
  prometheus:
    enabled: true
    retention: "30d"
    storage: "100Gi"
    
    # Custom metrics
    additionalScrapeConfigs:
      - job_name: 'tweetstream-api'
        static_configs:
          - targets: ['tweetstream-api:3000']
        metrics_path: '/metrics'
        scrape_interval: 30s
  
  grafana:
    enabled: true
    persistence:
      enabled: true
      size: "10Gi"
    
    # Pre-configured dashboards
    dashboards:
      - name: "TweetStream Overview"
        url: "https://raw.githubusercontent.com/..."
      - name: "API Performance"
        url: "https://raw.githubusercontent.com/..."

  alertmanager:
    enabled: true
    config:
      global:
        smtp_smarthost: 'localhost:587'
        smtp_from: 'alerts@tweetstream.local'
      
      route:
        group_by: ['alertname']
        group_wait: 10s
        group_interval: 10s
        repeat_interval: 1h
        receiver: 'web.hook'
      
      receivers:
      - name: 'web.hook'
        email_configs:
        - to: 'admin@tweetstream.local'
          subject: 'TweetStream Alert: {{ .GroupLabels.alertname }}'
```

### Custom Alerts

```yaml
# Production Alerts
prometheusRules:
  enabled: true
  rules:
    - alert: TweetStreamAPIDown
      expr: up{job="tweetstream-api"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "TweetStream API is down"
        description: "TweetStream API has been down for more than 1 minute"
    
    - alert: HighResponseTime
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High response time detected"
        description: "95th percentile response time is above 1 second"
    
    - alert: DatabaseConnectionsHigh
      expr: pg_stat_database_numbackends > 80
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High database connections"
        description: "Database has more than 80 active connections"
```

## 🔄 CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy TweetStream

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Login to GitHub Container Registry
      uses: docker/login-action@v2
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Build and push images
      run: |
        docker build -t ghcr.io/${{ github.repository }}/api:${{ github.sha }} ./api
        docker build -t ghcr.io/${{ github.repository }}/frontend:${{ github.sha }} ./frontend
        docker push ghcr.io/${{ github.repository }}/api:${{ github.sha }}
        docker push ghcr.io/${{ github.repository }}/frontend:${{ github.sha }}
    
    - name: Deploy to Kubernetes
      run: |
        helm upgrade tweetstream ./helm-chart/tweetstream \
          --set api.image.tag=${{ github.sha }} \
          --set frontend.image.tag=${{ github.sha }} \
          --namespace tweetstream
```

### ArgoCD GitOps

```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tweetstream
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-username/tweetstream
    targetRevision: HEAD
    path: helm-chart/tweetstream
    helm:
      valueFiles:
      - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: tweetstream
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

## 🧪 Testing and Validation

### Health Checks

```bash
# Run comprehensive health check
./scripts/health-check.sh --detailed

# Expected output:
# ✓ Namespace 'tweetstream' exists
# ✓ API pods: 3/3 ready
# ✓ Frontend pods: 2/2 ready
# ✓ Database pods: 1/1 ready
# ✓ Redis pods: 1/1 ready
# ✓ All services have endpoints
# ✓ Ingress 'tweetstream' exists
# ✓ API health endpoint responding
# ✓ Frontend responding
# 🎉 Overall health: HEALTHY
```

### Load Testing

```bash
# Install k6 for load testing
sudo apt-get install k6

# Create load test script
cat > load-test.js << 'EOF'
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '5m', target: 200 },
    { duration: '2m', target: 0 },
  ],
};

export default function () {
  let response = http.get('http://192.168.1.82:30080/', {
    headers: { 'Host': 'tweetstream.192.168.1.82.nip.io' },
  });
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
}
EOF

# Run load test
k6 run load-test.js
```

### Database Performance

```bash
# Connect to database and run performance tests
kubectl exec -n tweetstream postgres-primary-0 -- psql -U tweetuser -d tweetstream -c "
  EXPLAIN ANALYZE SELECT * FROM tweets 
  WHERE user_id = 1 
  ORDER BY created_at DESC 
  LIMIT 10;
"

# Check database metrics
kubectl exec -n tweetstream postgres-primary-0 -- psql -U tweetuser -d tweetstream -c "
  SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes
  FROM pg_stat_user_tables;
"
```

## 🔒 Backup and Recovery

### Database Backup

```bash
# Manual backup
kubectl exec -n tweetstream postgres-primary-0 -- pg_dump -U tweetuser tweetstream > backup-$(date +%Y%m%d).sql

# Automated backup with CronJob
kubectl apply -f - << 'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: tweetstream
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: postgres-backup
            image: postgres:15-alpine
            command:
            - /bin/bash
            - -c
            - |
              pg_dump -h postgres-primary -U tweetuser tweetstream > /backup/backup-$(date +%Y%m%d-%H%M%S).sql
              find /backup -name "backup-*.sql" -mtime +7 -delete
            env:
            - name: PGPASSWORD
              value: "tweetpass123"
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure
EOF
```

### Disaster Recovery

```bash
# Create disaster recovery script
cat > scripts/disaster-recovery.sh << 'EOF'
#!/bin/bash

# TweetStream Disaster Recovery Script

BACKUP_FILE="$1"
NAMESPACE="tweetstream"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup-file.sql>"
    exit 1
fi

echo "Starting disaster recovery..."

# Scale down application
kubectl scale deployment -n $NAMESPACE tweetstream-api --replicas=0
kubectl scale deployment -n $NAMESPACE tweetstream-frontend --replicas=0

# Wait for pods to terminate
kubectl wait --for=delete pod -l component=api -n $NAMESPACE --timeout=60s
kubectl wait --for=delete pod -l component=frontend -n $NAMESPACE --timeout=60s

# Restore database
kubectl exec -n $NAMESPACE postgres-primary-0 -- psql -U tweetuser -d tweetstream -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
kubectl exec -i -n $NAMESPACE postgres-primary-0 -- psql -U tweetuser tweetstream < "$BACKUP_FILE"

# Scale up application
kubectl scale deployment -n $NAMESPACE tweetstream-api --replicas=3
kubectl scale deployment -n $NAMESPACE tweetstream-frontend --replicas=2

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l component=api -n $NAMESPACE --timeout=300s
kubectl wait --for=condition=ready pod -l component=frontend -n $NAMESPACE --timeout=300s

echo "Disaster recovery completed!"
EOF

chmod +x scripts/disaster-recovery.sh
```

## 📈 Performance Optimization

### Database Optimization

```sql
-- Connect to database and run optimization queries
-- kubectl exec -n tweetstream postgres-primary-0 -- psql -U tweetuser -d tweetstream

-- Create indexes for better performance
CREATE INDEX CONCURRENTLY idx_tweets_user_id_created_at ON tweets(user_id, created_at DESC);
CREATE INDEX CONCURRENTLY idx_tweets_created_at ON tweets(created_at DESC);
CREATE INDEX CONCURRENTLY idx_follows_follower_id ON follows(follower_id);
CREATE INDEX CONCURRENTLY idx_follows_following_id ON follows(following_id);
CREATE INDEX CONCURRENTLY idx_likes_tweet_id ON likes(tweet_id);
CREATE INDEX CONCURRENTLY idx_likes_user_id ON likes(user_id);

-- Analyze tables for query optimization
ANALYZE tweets;
ANALYZE users;
ANALYZE follows;
ANALYZE likes;

-- Configure PostgreSQL for better performance
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;

-- Reload configuration
SELECT pg_reload_conf();
```

### Redis Optimization

```bash
# Configure Redis for production
kubectl exec -n tweetstream redis-xxx -- redis-cli CONFIG SET maxmemory 512mb
kubectl exec -n tweetstream redis-xxx -- redis-cli CONFIG SET maxmemory-policy allkeys-lru
kubectl exec -n tweetstream redis-xxx -- redis-cli CONFIG SET save "900 1 300 10 60 10000"
```

## 🎯 Next Steps

1. **Choose and implement** one of the production deployment options
2. **Configure monitoring** and alerting
3. **Set up automated backups**
4. **Implement CI/CD pipeline**
5. **Perform load testing**
6. **Document operational procedures**
7. **Train team on monitoring and troubleshooting**

## 📞 Support and Maintenance

### Regular Maintenance Tasks

```bash
# Weekly maintenance script
cat > scripts/weekly-maintenance.sh << 'EOF'
#!/bin/bash

echo "Starting weekly maintenance..."

# Check cluster health
./scripts/health-check.sh --detailed

# Update Helm charts
helm repo update

# Check for security updates
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' | grep -E "(postgres|redis|nginx)" | sort | uniq

# Clean up old backups
find /backups -name "backup-*.sql" -mtime +30 -delete

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu

echo "Weekly maintenance completed!"
EOF

chmod +x scripts/weekly-maintenance.sh
```

### Emergency Contacts and Procedures

1. **Application Issues**: Check logs, restart pods, scale resources
2. **Database Issues**: Check connections, review slow queries, consider failover
3. **Network Issues**: Verify ingress, check DNS, test connectivity
4. **Resource Issues**: Scale nodes, optimize resource requests, check limits

---

**Remember**: Always test changes in a staging environment before applying to production! 