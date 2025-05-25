# TweetStream - Twitter-like Social Media Platform

A production-ready, Twitter-like social media platform built for Kubernetes with comprehensive monitoring, high availability, and GitOps deployment using Helm and ArgoCD.

## 🏗️ Architecture Overview

TweetStream is a modern, cloud-native social media platform featuring:

- **Node.js API** - RESTful backend with Express.js
- **NGINX Frontend** - Modern, responsive web interface
- **PostgreSQL 15** - Primary database with Twitter-like schema
- **Redis 7** - Caching and session management
- **Apache Kafka** - Real-time tweet streaming (KRaft mode)
- **Prometheus + Grafana** - Comprehensive monitoring and alerting
- **ArgoCD** - GitOps continuous deployment

## 📁 Project Structure

```
tweetstream-app/
├── helm-chart/                    # Helm chart for TweetStream
│   └── tweetstream/
│       ├── Chart.yaml             # Helm chart metadata
│       ├── values.yaml            # Default configuration
│       ├── values-dev.yaml        # Development environment
│       ├── values-staging.yaml    # Staging environment
│       ├── values-prod.yaml       # Production environment
│       ├── templates/             # Kubernetes manifests
│       │   ├── api/              # API service templates
│       │   ├── frontend/         # Frontend service templates
│       │   ├── database/         # PostgreSQL templates
│       │   ├── redis/            # Redis templates
│       │   ├── kafka/            # Kafka templates
│       │   ├── monitoring/       # Monitoring templates
│       │   ├── ingress/          # Ingress templates
│       │   └── _helpers.tpl      # Template helpers
│       ├── sql/                  # Database schema and sample data
│       │   ├── 01-schema.sql     # Database schema
│       │   └── 02-sample-data.sql # Sample data
│       └── app-code/             # Application source code
│           └── api/              # Node.js API source
├── argocd-setup.yaml             # ArgoCD installation
├── argocd-rbac.yaml              # ArgoCD RBAC configuration
├── tweetstream-argocd-app.yaml   # ArgoCD application definitions
├── setup-argocd.sh               # ArgoCD setup script
├── deploy-helm.sh                # Helm deployment script
└── README.md                     # This file
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (1.24+)
- Helm 3.8+
- kubectl configured
- NGINX Ingress Controller
- Prometheus + Grafana (optional, for monitoring)

### 1. Clone and Navigate

```bash
git clone https://github.com/pavelkushtia/kubernetes.git
cd kubernetes/tweetstream-app
```

### 2. Deploy with Helm

#### Development Environment
```bash
./deploy-helm.sh -e development
```

#### Staging Environment
```bash
./deploy-helm.sh -e staging
```

#### Production Environment
```bash
./deploy-helm.sh -e production
```

### 3. Access the Application

After deployment, access TweetStream at:
- **Development**: http://tweetstream-dev.192.168.1.82.nip.io
- **Staging**: http://tweetstream-staging.192.168.1.82.nip.io
- **Production**: http://tweetstream.192.168.1.82.nip.io

## 🔧 Configuration

### Environment-Specific Configurations

| Environment | Replicas | Resources | Monitoring | Auto-scaling |
|-------------|----------|-----------|------------|--------------|
| Development | API: 1, Frontend: 1 | Minimal | Disabled | Disabled |
| Staging | API: 2, Frontend: 2 | Moderate | Enabled | Enabled |
| Production | API: 3, Frontend: 3 | Full | Enabled | Enabled |

### Custom Values

Create your own values file or override specific values:

```bash
# Using custom values file
./deploy-helm.sh -e production -f my-values.yaml

# Override specific values
helm upgrade tweetstream ./helm-chart/tweetstream \
  --set api.replicaCount=5 \
  --set database.persistence.size=50Gi
```

## 🔄 GitOps with ArgoCD

### Setup ArgoCD

```bash
# Install ArgoCD
./setup-argocd.sh

# Apply TweetStream application
kubectl apply -f tweetstream-argocd-app.yaml
```

### ArgoCD Features

- **Automated Sync** - Changes in Git automatically deployed
- **Drift Detection** - Alerts when cluster state differs from Git
- **Easy Rollbacks** - One-click rollback to previous versions
- **Multi-environment** - Separate applications for dev/staging/prod

### Access ArgoCD

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at: https://localhost:8080
# Username: admin
# Password: (from above command)
```

## 📊 Monitoring & Observability

### Grafana Dashboard

TweetStream includes a comprehensive Grafana dashboard with:

- **Application Metrics**: Active users, tweets, likes
- **Performance Metrics**: API response times, request rates
- **Infrastructure Metrics**: CPU, memory, network I/O
- **Database Metrics**: Connection pools, query performance
- **Cache Metrics**: Redis hit rates, memory usage
- **Message Queue**: Kafka throughput and lag

### Prometheus Alerts

Pre-configured alerts for:
- API service down or high error rate
- Database connection issues
- High resource usage
- Kafka message lag

### Access Monitoring

```bash
# Port forward to Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80

# Access at: http://localhost:3000
# Default credentials: admin/admin
```

## 🗄️ Database Schema

TweetStream uses a Twitter-like database schema:

- **users** - User profiles and authentication
- **tweets** - Tweet content and metadata
- **follows** - User relationships
- **likes** - Tweet engagement
- **notifications** - User notifications
- **user_sessions** - Session management

Sample data is automatically loaded for development and testing.

## 🔧 Development

### Local Development

```bash
# Deploy development environment
./deploy-helm.sh -e development

# Port forward for local access
kubectl port-forward svc/tweetstream-api -n tweetstream 3000:3000
kubectl port-forward svc/tweetstream-frontend -n tweetstream 8080:80
```

### API Endpoints

- `GET /api` - API documentation
- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `GET /api/tweets` - Get tweet feed
- `POST /api/tweets` - Create tweet

## 🛠️ Operations

### Useful Commands

```bash
# Check deployment status
kubectl get pods -n tweetstream

# View API logs
kubectl logs -n tweetstream -l component=api -f

# View frontend logs
kubectl logs -n tweetstream -l component=frontend -f

# Scale API replicas
kubectl scale deployment tweetstream-api -n tweetstream --replicas=5

# Check Helm releases
helm list -n tweetstream

# Upgrade deployment
./deploy-helm.sh --upgrade -e production

# Uninstall
helm uninstall tweetstream -n tweetstream
```

### Troubleshooting

#### Common Issues

1. **Pods not starting**: Check resource limits and node capacity
2. **Database connection errors**: Verify PostgreSQL pod is running
3. **Ingress not working**: Ensure NGINX Ingress Controller is installed
4. **Kafka issues**: Check KRaft configuration and storage

#### Debug Commands

```bash
# Check pod events
kubectl describe pod <pod-name> -n tweetstream

# Check service endpoints
kubectl get endpoints -n tweetstream

# Check ingress status
kubectl describe ingress -n tweetstream

# Check persistent volumes
kubectl get pv,pvc -n tweetstream
```

## 🔒 Security

### Production Security Features

- **Pod Security Context** - Non-root user execution
- **Security Context** - Dropped capabilities
- **Network Policies** - Traffic isolation (production only)
- **Resource Limits** - Prevent resource exhaustion
- **Health Checks** - Liveness and readiness probes

### Secrets Management

Sensitive data is stored in Kubernetes secrets:
- Database passwords
- JWT secrets
- API keys

## 📈 Scaling

### Horizontal Pod Autoscaling

TweetStream automatically scales based on:
- CPU utilization (70% threshold)
- Memory utilization (80% threshold)

### Manual Scaling

```bash
# Scale API
kubectl scale deployment tweetstream-api --replicas=10

# Scale frontend
kubectl scale deployment tweetstream-frontend --replicas=5
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with development environment
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## 🆘 Support

For support and questions:
- Create an issue in the GitHub repository
- Check the troubleshooting section above
- Review Kubernetes and Helm documentation

---

**TweetStream** - Built with ❤️ for the cloud-native community 