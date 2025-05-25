# TweetStream Helm Chart

A production-ready Twitter-like social media platform for Kubernetes, packaged as a Helm chart.

## Overview

TweetStream is a comprehensive social media application that includes:

- **Node.js API** - RESTful backend with Express.js
- **NGINX Frontend** - Modern web interface with real-time updates
- **PostgreSQL Database** - Persistent data storage with Twitter-like schema
- **Redis Cache** - Session management and caching
- **Apache Kafka** - Real-time message streaming (KRaft mode)
- **Prometheus Monitoring** - Custom metrics and health monitoring
- **Grafana Integration** - Pre-configured dashboards
- **Auto-scaling** - HPA for API and frontend components

## Prerequisites

- Kubernetes 1.20+
- Helm 3.8+
- Docker (for building images)
- kubectl configured to access your cluster

### Required Kubernetes Resources

- **Storage Class**: `local-path` (or configure custom storage class)
- **Ingress Controller**: NGINX Ingress Controller
- **Monitoring Stack**: Prometheus and Grafana (optional but recommended)

## Quick Start

### 1. Clone and Navigate

```bash
git clone <repository-url>
cd tweetstream-app/helm-chart
```

### 2. Build and Deploy

```bash
# Build Docker images and deploy with Helm
./deploy-helm.sh
```

### 3. Access the Application

The deployment script will show you the access URL:

```
TweetStream is available at: http://tweetstream.192.168.1.82.nip.io
API documentation: http://tweetstream.192.168.1.82.nip.io/api
Health check: http://tweetstream.192.168.1.82.nip.io/api/health
```

## Manual Installation

### 1. Build Docker Images

```bash
# Build API image
cd tweetstream/app-code/api
docker build -t tweetstream/api:1.0.0 .

# Build Frontend image
cd ../frontend
docker build -t tweetstream/frontend:1.0.0 .
cd ../../..
```

### 2. Install with Helm

```bash
# Create namespace
kubectl create namespace tweetstream

# Install the chart
helm install tweetstream ./tweetstream \
  --namespace tweetstream \
  --create-namespace \
  --wait \
  --timeout 10m
```

### 3. Verify Installation

```bash
# Check pods
kubectl get pods -n tweetstream

# Check services
kubectl get services -n tweetstream

# Check ingress
kubectl get ingress -n tweetstream
```

## Configuration

### Values File

The chart can be configured through `values.yaml`. Key configuration sections:

#### API Configuration

```yaml
api:
  enabled: true
  replicaCount: 3
  image:
    repository: tweetstream/api
    tag: "1.0.0"
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
```

#### Database Configuration

```yaml
database:
  enabled: true
  auth:
    database: tweetstream
    username: tweetuser
    password: tweetpass123
  persistence:
    size: 10Gi
    storageClass: "local-path"
```

#### Ingress Configuration

```yaml
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: tweetstream.example.com
      paths:
        - path: /
          service:
            name: tweetstream-frontend
            port: 80
        - path: /api
          service:
            name: tweetstream-api
            port: 3000
```

### Custom Values

Create a custom values file:

```bash
# Create custom-values.yaml
cat > custom-values.yaml << EOF
ingress:
  hosts:
    - host: my-tweetstream.example.com

database:
  auth:
    password: my-secure-password

api:
  replicaCount: 5
EOF

# Deploy with custom values
helm install tweetstream ./tweetstream \
  --namespace tweetstream \
  --values custom-values.yaml
```

## Architecture

### Components

1. **API Service** (Node.js)
   - RESTful endpoints for tweets, users, likes
   - PostgreSQL integration
   - Redis caching
   - Prometheus metrics
   - Health checks

2. **Frontend Service** (NGINX)
   - Modern Twitter-like UI
   - Real-time updates
   - Responsive design
   - API proxy configuration

3. **Database** (PostgreSQL 15)
   - Twitter-like schema (users, tweets, follows, likes)
   - Persistent storage
   - Performance indexes
   - Sample data included

4. **Cache** (Redis 7)
   - Session management
   - API response caching
   - Real-time data

5. **Message Queue** (Kafka 7.4)
   - KRaft mode (no Zookeeper)
   - Tweet streaming
   - Real-time notifications

### Monitoring

- **Custom Metrics**: Active users, tweet counts, API performance
- **Health Checks**: Liveness and readiness probes
- **Auto-scaling**: CPU and memory-based HPA
- **Exporters**: PostgreSQL, Redis, and Kafka exporters

## API Endpoints

### Health & Monitoring

- `GET /health` - Health check
- `GET /ready` - Readiness check
- `GET /metrics` - Prometheus metrics
- `GET /api` - API documentation

### Tweets

- `GET /api/tweets` - Get tweet feed
- `POST /api/tweets` - Create new tweet
- `GET /api/tweets/:id` - Get specific tweet

### Users

- `GET /api/users` - Get all users
- `GET /api/users/:id` - Get user profile
- `GET /api/users/:id/tweets` - Get user's tweets

## Monitoring & Observability

### Prometheus Metrics

The application exposes custom metrics:

- `tweetstream_active_users_total` - Number of active users
- `tweetstream_tweets_total` - Total number of tweets
- `tweetstream_likes_total` - Total number of likes
- `http_requests_total` - HTTP request counter
- `http_request_duration_seconds` - HTTP request duration

### Grafana Dashboard

A pre-configured Grafana dashboard is available with:

- Application overview stats
- Tweet activity over time
- API performance metrics
- Resource usage monitoring
- Database and cache metrics

### Alerts

Prometheus alerts are configured for:

- API service down
- High response times
- High error rates
- Database connectivity issues
- High resource usage

## Scaling

### Horizontal Pod Autoscaling

The chart includes HPA for:

- **API**: 3-10 replicas based on CPU/Memory
- **Frontend**: 2-5 replicas based on CPU

### Manual Scaling

```bash
# Scale API
kubectl scale deployment tweetstream-api --replicas=5 -n tweetstream

# Scale Frontend
kubectl scale deployment tweetstream-frontend --replicas=3 -n tweetstream
```

## Troubleshooting

### Common Issues

1. **Pods not starting**
   ```bash
   kubectl describe pods -n tweetstream
   kubectl logs -f deployment/tweetstream-api -n tweetstream
   ```

2. **Database connection issues**
   ```bash
   kubectl exec -it deployment/postgres-primary -n tweetstream -- psql -U tweetuser -d tweetstream
   ```

3. **Ingress not working**
   ```bash
   kubectl get ingress -n tweetstream
   kubectl describe ingress -n tweetstream
   ```

### Debug Commands

```bash
# Check all resources
kubectl get all -n tweetstream

# Check events
kubectl get events -n tweetstream --sort-by='.lastTimestamp'

# Check logs
kubectl logs -f deployment/tweetstream-api -n tweetstream
kubectl logs -f deployment/tweetstream-frontend -n tweetstream

# Port forward for local access
kubectl port-forward service/tweetstream-api 3000:3000 -n tweetstream
kubectl port-forward service/tweetstream-frontend 8080:80 -n tweetstream
```

## Upgrading

### Helm Upgrade

```bash
# Upgrade to new version
helm upgrade tweetstream ./tweetstream \
  --namespace tweetstream \
  --wait \
  --timeout 10m

# Check upgrade status
helm status tweetstream -n tweetstream
```

### Rolling Back

```bash
# List releases
helm history tweetstream -n tweetstream

# Rollback to previous version
helm rollback tweetstream 1 -n tweetstream
```

## Uninstalling

### Using the Script

```bash
./deploy-helm.sh uninstall
```

### Manual Uninstall

```bash
# Uninstall Helm release
helm uninstall tweetstream -n tweetstream

# Delete namespace (optional)
kubectl delete namespace tweetstream
```

## Development

### Local Development

1. **Run components locally**:
   ```bash
   # Start database
   docker run -d --name postgres \
     -e POSTGRES_DB=tweetstream \
     -e POSTGRES_USER=tweetuser \
     -e POSTGRES_PASSWORD=tweetpass123 \
     -p 5432:5432 postgres:15-alpine

   # Start Redis
   docker run -d --name redis -p 6379:6379 redis:7-alpine

   # Run API
   cd tweetstream/app-code/api
   npm install
   npm start

   # Serve frontend
   cd ../frontend
   python3 -m http.server 8080
   ```

2. **Test API**:
   ```bash
   curl http://localhost:3000/health
   curl http://localhost:3000/api/tweets
   ```

### Building Custom Images

```bash
# Build with custom tags
docker build -t my-registry/tweetstream/api:custom ./tweetstream/app-code/api
docker build -t my-registry/tweetstream/frontend:custom ./tweetstream/app-code/frontend

# Update values.yaml
api:
  image:
    repository: my-registry/tweetstream/api
    tag: custom
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:

- Create an issue in the repository
- Check the troubleshooting section
- Review Kubernetes and Helm documentation

## Changelog

### v1.0.0
- Initial release
- Complete Twitter-like functionality
- Kubernetes-native deployment
- Comprehensive monitoring
- Auto-scaling capabilities 