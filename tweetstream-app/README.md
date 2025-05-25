# 🐦 TweetStream - Twitter Clone on Kubernetes

A complete Twitter-like social media application designed for Kubernetes with comprehensive monitoring and high availability features.

## 🏗️ Architecture Overview

TweetStream is a modern, scalable social media platform that includes:

### Core Components
- **PostgreSQL 15** - Primary database with Twitter-like schema
- **Redis 7** - Caching layer and session management
- **Apache Kafka 7.4.0** - Real-time message streaming
- **Node.js API** - RESTful backend with Express.js
- **NGINX Frontend** - Modern dark-themed UI

### Monitoring Stack
- **Prometheus** - Metrics collection and alerting
- **Grafana** - Comprehensive dashboards
- **Custom Exporters** - PostgreSQL, Redis, and Kafka metrics
- **AlertManager** - Critical system alerts

### High Availability Features
- **Horizontal Pod Autoscaling** - Auto-scaling based on CPU/Memory
- **Health Checks** - Liveness and readiness probes
- **Resource Management** - Proper limits and requests
- **Persistent Storage** - Database persistence with local-path

## 📋 Prerequisites

- Kubernetes cluster (v1.28+) with 3+ nodes
- NGINX Ingress Controller installed
- Prometheus and Grafana monitoring stack
- `kubectl` configured to access your cluster
- At least 4GB RAM and 2 CPU cores available

## 🚀 Deployment Options

### Option 1: GitOps with ArgoCD (Recommended for Production)

ArgoCD provides continuous deployment, drift detection, and rollback capabilities.

#### Benefits of ArgoCD:
- ✅ **GitOps Workflow** - Declarative deployments from Git
- ✅ **Automatic Synchronization** - Changes in Git automatically deployed
- ✅ **Rollback Capabilities** - Easy rollbacks to previous versions
- ✅ **Multi-environment Support** - Dev, staging, production
- ✅ **Security** - RBAC and audit trails
- ✅ **Drift Detection** - Alerts when cluster state differs from Git

#### Setup ArgoCD:
```bash
# 1. Make the ArgoCD setup script executable
chmod +x setup-argocd.sh

# 2. Install and configure ArgoCD
./setup-argocd.sh

# 3. Create a Git repository and push your code
git init
git add .
git commit -m "Initial TweetStream application"
git remote add origin https://github.com/YOUR_USERNAME/kubernetes-tweetstream.git
git push -u origin main

# 4. Update the Git repository URL in tweetstream-argocd-app.yaml
# Edit the repoURL field with your actual repository

# 5. Deploy the ArgoCD application
kubectl apply -f tweetstream-argocd-app.yaml
```

#### Access ArgoCD:
- **ArgoCD UI**: http://argocd.192.168.1.82.nip.io:30080
- **Username**: admin
- **Password**: (provided by setup script)

### Option 2: Direct Deployment (Good for Development/Testing)

The deploy script is useful for quick testing and development environments.

#### Benefits of Direct Deployment:
- ✅ **Quick Setup** - Fast deployment for testing
- ✅ **Simple** - No additional tools required
- ✅ **Learning** - Good for understanding Kubernetes resources

#### Limitations:
- ❌ **No GitOps** - Manual deployment process
- ❌ **No Drift Detection** - Manual monitoring required
- ❌ **No Rollback** - Manual rollback process
- ❌ **No Audit Trail** - Limited deployment history

#### Quick Start:
```bash
# Make the deployment script executable
chmod +x deploy.sh

# Run the automated deployment
./deploy.sh
```

## 🌐 Access URLs (After Deployment)
- **TweetStream App**: http://tweetstream.192.168.1.82.nip.io:30080
- **Grafana Dashboard**: http://grafana.192.168.1.82.nip.io:30080
- **Prometheus**: http://prometheus.192.168.1.82.nip.io:30080
- **ArgoCD UI**: http://argocd.192.168.1.82.nip.io:30080 (if using ArgoCD)

## 📁 File Structure

```
tweetstream-app/
├── tweetstream-app.yaml         # Main application deployment
├── monitoring-exporters.yaml    # PostgreSQL, Redis, Kafka exporters
├── grafana-dashboard.yaml       # Custom Grafana dashboard
├── deploy.sh                    # Direct deployment script
├── setup-argocd.sh             # ArgoCD installation script
├── argocd-setup.yaml           # ArgoCD installation manifests
├── argocd-rbac.yaml            # ArgoCD RBAC configuration
├── tweetstream-argocd-app.yaml # ArgoCD application definition
└── README.md                   # This file
```

## 🔄 GitOps Workflow with ArgoCD

### 1. Development Workflow
```bash
# Make changes to your application
vim tweetstream-app.yaml

# Commit and push changes
git add .
git commit -m "Update API replicas to 5"
git push origin main

# ArgoCD automatically detects changes and syncs
# Check ArgoCD UI for deployment status
```

### 2. Environment Management
```bash
# Create different branches for environments
git checkout -b staging
git checkout -b production

# Use different ArgoCD applications for each environment
# Point to different branches in tweetstream-argocd-app.yaml
```

### 3. Rollback Process
```bash
# Via ArgoCD UI: Click "History and Rollback"
# Via CLI:
argocd app rollback tweetstream --revision 2
```

## 🗄️ Database Schema

### Users Table
- User profiles with followers/following counts
- Authentication and bio information
- Tweet statistics tracking

### Tweets Table
- Tweet content with engagement metrics
- Reply threading support
- Timestamp tracking

### Relationships
- Follows table for user connections
- Likes table for tweet interactions
- Proper indexing for performance

## 🔧 Manual Deployment

If you prefer manual deployment:

```bash
# Deploy main application
kubectl apply -f tweetstream-app.yaml

# Deploy monitoring exporters
kubectl apply -f monitoring-exporters.yaml

# Deploy Grafana dashboard
kubectl apply -f grafana-dashboard.yaml
```

## 📊 Monitoring Features

### Custom Metrics
- `tweetstream_active_users_total` - Active user count
- `tweetstream_tweets_total` - Total tweets created
- `tweetstream_likes_total` - Total likes given
- `http_request_duration_seconds` - API response times

### Grafana Dashboard Panels
1. **Application Overview** - Key statistics
2. **Tweet Activity** - Real-time tweet/like rates
3. **Active Users Trend** - User engagement over time
4. **API Performance** - Response time percentiles
5. **HTTP Request Rates** - Traffic patterns
6. **Resource Usage** - CPU/Memory consumption
7. **Database Metrics** - Connection and query stats
8. **Cache Performance** - Redis hit/miss rates
9. **Message Throughput** - Kafka metrics
10. **Network I/O** - Traffic monitoring
11. **Pod Health** - Container status
12. **System Alerts** - Critical notifications

### Alerting Rules
- API service down
- High response times (>2s)
- High error rates (>5%)
- Database connectivity issues
- Redis/Kafka service failures
- High resource usage (>80%)

## 🔍 Troubleshooting

### ArgoCD Issues
```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD applications
kubectl get applications -n argocd

# View ArgoCD application details
kubectl describe application tweetstream -n argocd

# Check ArgoCD logs
kubectl logs -f deployment/argocd-server -n argocd
```

### Application Issues
```bash
# Check pod status
kubectl get pods -n tweetstream

# View logs
kubectl logs -f deployment/tweetstream-api -n tweetstream

# Port forward for debugging
kubectl port-forward svc/tweetstream-frontend 8080:80 -n tweetstream
```

### Scale Services
```bash
# Scale API replicas
kubectl scale deployment tweetstream-api --replicas=5 -n tweetstream

# Scale frontend replicas
kubectl scale deployment tweetstream-frontend --replicas=3 -n tweetstream
```

## 🧪 Testing the Application

### 1. Create Sample Tweets
- Access the web interface
- Select a user from the dropdown
- Post tweets and interact with existing content

### 2. Load Testing
```bash
# Generate API load
kubectl run load-test --image=busybox --rm -it --restart=Never -- \
  sh -c 'while true; do wget -q -O- http://tweetstream-api:3000/api/tweets; sleep 1; done'
```

### 3. Monitor Auto-scaling
```bash
# Watch HPA status
kubectl get hpa -n tweetstream -w

# Monitor pod scaling
kubectl get pods -n tweetstream -w
```

## 🔧 Configuration

### Environment Variables
The API supports these environment variables:
- `NODE_ENV` - Runtime environment (production/development)
- `DB_HOST` - PostgreSQL host (default: postgres-primary)
- `REDIS_HOST` - Redis host (default: redis)
- `KAFKA_BROKERS` - Kafka broker list (default: kafka:9092)

### Resource Limits
Current resource allocations:
- **PostgreSQL**: 256Mi-512Mi RAM, 250m-500m CPU
- **Redis**: 128Mi-256Mi RAM, 100m-200m CPU
- **Kafka**: 512Mi-1Gi RAM, 500m-1000m CPU
- **API**: 256Mi-512Mi RAM, 250m-500m CPU
- **Frontend**: 64Mi-128Mi RAM, 50m-100m CPU

## 🔒 Security Features

- **Helmet.js** - Security headers
- **Rate Limiting** - 100 requests per 15 minutes per IP
- **CORS** - Cross-origin request handling
- **Input Validation** - SQL injection prevention
- **Health Checks** - Service availability monitoring

## 🚀 Performance Optimizations

- **Redis Caching** - 60-second tweet cache
- **Database Indexing** - Optimized queries
- **Connection Pooling** - PostgreSQL connection management
- **GZIP Compression** - Frontend asset compression
- **CDN Ready** - Static asset optimization

## 📈 Scaling Guidelines

### Horizontal Scaling
- **API**: 3-10 replicas based on CPU (70%) and Memory (80%)
- **Frontend**: 2-5 replicas based on CPU (70%)
- **Database**: Single instance with persistent storage
- **Cache/Message Queue**: Single instance for development

### Vertical Scaling
Increase resource limits in the YAML files:
```yaml
resources:
  limits:
    memory: "1Gi"    # Increase from 512Mi
    cpu: "1000m"     # Increase from 500m
```

## 🛠️ Development

### Local Development Setup
```bash
# Port forward services
kubectl port-forward svc/postgres-primary 5432:5432 -n tweetstream &
kubectl port-forward svc/redis 6379:6379 -n tweetstream &
kubectl port-forward svc/kafka 9092:9092 -n tweetstream &

# Run API locally
cd api/
npm install
npm start
```

### Database Access
```bash
# Connect to PostgreSQL
kubectl exec -it statefulset/postgres-primary -n tweetstream -- \
  psql -U tweetuser -d tweetstream

# Connect to Redis
kubectl exec -it deployment/redis -n tweetstream -- redis-cli
```

## 🔄 Backup and Recovery

### Database Backup
```bash
# Create backup
kubectl exec statefulset/postgres-primary -n tweetstream -- \
  pg_dump -U tweetuser tweetstream > tweetstream-backup.sql

# Restore backup
kubectl exec -i statefulset/postgres-primary -n tweetstream -- \
  psql -U tweetuser tweetstream < tweetstream-backup.sql
```

## 📞 Support

### Common Issues
1. **Pods not starting** - Check resource availability
2. **Database connection errors** - Verify PostgreSQL is running
3. **API timeouts** - Check network policies and service discovery
4. **Monitoring not working** - Ensure ServiceMonitors are created
5. **ArgoCD sync issues** - Check Git repository access and YAML syntax

### Useful Commands
```bash
# Check cluster resources
kubectl top nodes
kubectl top pods -n tweetstream

# Describe problematic pods
kubectl describe pod <pod-name> -n tweetstream

# Check events
kubectl get events -n tweetstream --sort-by='.lastTimestamp'

# ArgoCD CLI commands
argocd app list
argocd app sync tweetstream
argocd app history tweetstream
```

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 🎯 Roadmap

- [ ] User authentication and authorization
- [ ] Real-time notifications via WebSockets
- [ ] Image upload and media support
- [ ] Advanced search functionality
- [ ] Mobile-responsive improvements
- [ ] Multi-language support
- [ ] Advanced analytics dashboard
- [ ] Multi-cluster ArgoCD setup
- [ ] Helm chart packaging
- [ ] Kustomize overlays for environments

---

**TweetStream** - A production-ready Twitter clone for Kubernetes with GitOps! 🚀 