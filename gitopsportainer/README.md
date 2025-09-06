# URL Shortener GitOps Deployment

This folder contains Kubernetes manifests for deploying the URL shortener application in a GitOps-ready format that works seamlessly wit# Update specific deployment
kubectl set image deployment/link-service link-service=itsbaivab/url-shortener-link:v2.0 -n url-shortener
kubectl set image deployment/redirect-service redirect-service=itsbaivab/url-shortener-redirect:v2.0 -n url-shortener
kubectl set image deployment/stats-service stats-service=itsbaivab/url-shortener-stats:v2.0 -n url-shortenerrtainer.

## 🏗️ Architecture

The deployment consists of the following components:

- **PostgreSQL Database**: StatefulSet with persistent storage and initialization scripts
- **Link Service**: Handles URL generation and management
- **Redirect Service**: Handles URL redirections and click tracking
- **Stats Service**: Provides analytics and statistics
- **Nginx Gateway**: API gateway with rate limiting and CORS support
- **Frontend**: React-based web interface with nginx proxy
- **LoadBalancer**: External access to services

## 📁 Files Structure

```
gitopsportainer/
├── 00-namespace.yaml          # Kubernetes namespace
├── 01-postgres-config.yaml    # Database initialization ConfigMap
├── 02-postgres.yaml          # PostgreSQL StatefulSet and Service
├── 03-link-service.yaml      # Link service Deployment and Service
├── 04-redirect-service.yaml  # Redirect service Deployment and Service
├── 05-stats-service.yaml     # Stats service Deployment and Service
├── 06-nginx-gateway.yaml     # API gateway Deployment and Service
├── 07-frontend.yaml          # Frontend Deployment and Service
├── 08-loadbalancer.yaml      # LoadBalancer services
├── deploy.sh                 # Automated deployment script
└── README.md                 # This file
```

## 🚀 Quick Deployment

### Option 1: Automated Deployment (Recommended)

```bash
# Run the automated deployment script
./deploy.sh
```

This script will:
- Detect your cluster's external IP automatically
- Deploy all services with proper configuration
- Wait for all pods to be ready
- Display access URLs and testing commands

### Option 2: Manual Deployment

```bash
# Apply manifests in order
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-postgres-config.yaml
kubectl apply -f 02-postgres.yaml
kubectl apply -f 03-link-service.yaml
kubectl apply -f 04-redirect-service.yaml
kubectl apply -f 05-stats-service.yaml
kubectl apply -f 06-nginx-gateway.yaml
kubectl apply -f 07-frontend.yaml
kubectl apply -f 08-loadbalancer.yaml

# Check deployment status
kubectl get pods -n url-shortener

# Get external access URLs
kubectl get svc -n url-shortener
```

## 🌐 Access URLs

After deployment, the application will be accessible at:

- **Frontend**: `http://<CLUSTER-IP>:30081`
- **API Gateway**: `http://<CLUSTER-IP>:30080`
- **Short URLs**: `http://<CLUSTER-IP>:30081/r/{slug}`

## 🔧 Configuration

### Automatic URL Detection

The deployment script automatically detects your cluster's external IP using the following methods:

1. LoadBalancer external IP
2. Node external IP
3. Node internal IP (for local clusters)
4. Minikube IP (if using Minikube)
5. Localhost fallback

### Environment Variables

Key environment variables configured in the services:

- `DB_HOST`: PostgreSQL service DNS name
- `DB_PORT`: Database port (5432)
- `DB_NAME`: Database name (urlshortener)
- `DB_USER`: Database user (postgres)
- `DB_PASSWORD`: Database password (postgres)

### Resource Limits

All services have configured resource requests and limits:

- **PostgreSQL**: 256Mi-512Mi memory, 250m-500m CPU
- **Backend Services**: 128Mi-256Mi memory, 100m-200m CPU
- **Frontend/Gateway**: 64Mi-256Mi memory, 50m-200m CPU

## 🧪 Testing

### Health Checks

```bash
# Check all service health
kubectl get pods -n url-shortener

# Test API gateway health
curl http://<CLUSTER-IP>:30080/health

# Test frontend health
curl http://<CLUSTER-IP>:30081/health
```

### Create Short URL

```bash
# Generate a short URL
curl -X POST http://<CLUSTER-IP>:30080/api/generate \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://www.google.com"}'

# Test redirect
curl -L http://<CLUSTER-IP>:30081/r/{slug}

# Get statistics
curl http://<CLUSTER-IP>:30080/api/stats
```

## 📊 Monitoring

### View Logs

```bash
# View logs for specific service
kubectl logs -f deployment/link-service -n url-shortener
kubectl logs -f deployment/redirect-service -n url-shortener
kubectl logs -f deployment/stats-service -n url-shortener
kubectl logs -f deployment/nginx-gateway -n url-shortener
kubectl logs -f deployment/frontend -n url-shortener

# View PostgreSQL logs
kubectl logs -f statefulset/postgres -n url-shortener
```

### Port Forwarding (for local testing)

```bash
# Forward frontend port
kubectl port-forward svc/frontend 3000:80 -n url-shortener

# Forward API gateway port
kubectl port-forward svc/nginx-gateway 8080:80 -n url-shortener

# Forward database port
kubectl port-forward svc/postgres 5432:5432 -n url-shortener
```

## 🔄 Updates and Maintenance

### Update Images

```bash
# Update specific deployment
kubectl set image deployment/link-service link-service=baivab85/url-shortener-link:v2.0 -n url-shortener
kubectl set image deployment/redirect-service redirect-service=baivab85/url-shortener-redirect:v2.0 -n url-shortener
kubectl set image deployment/stats-service stats-service=baivab85/url-shortener-stats:v2.0 -n url-shortener
```

### Scale Services

```bash
# Scale services up/down
kubectl scale deployment/link-service --replicas=3 -n url-shortener
kubectl scale deployment/redirect-service --replicas=3 -n url-shortener
```

### Database Backup

```bash
# Create database backup
kubectl exec -it postgres-0 -n url-shortener -- pg_dump -U postgres urlshortener > backup.sql

# Restore database
kubectl exec -i postgres-0 -n url-shortener -- psql -U postgres urlshortener < backup.sql
```

## 🗑️ Cleanup

```bash
# Delete the entire deployment
kubectl delete namespace url-shortener

# Or delete specific resources in reverse order
kubectl delete -f 08-loadbalancer.yaml
kubectl delete -f 07-frontend.yaml
kubectl delete -f 06-nginx-gateway.yaml
kubectl delete -f 05-stats-service.yaml
kubectl delete -f 04-redirect-service.yaml
kubectl delete -f 03-link-service.yaml
kubectl delete -f 02-postgres.yaml
kubectl delete -f 01-postgres-config.yaml
kubectl delete -f 00-namespace.yaml
```

## 🔒 Security Considerations

1. **Database Credentials**: Consider using Kubernetes Secrets for production
2. **TLS/HTTPS**: Add TLS termination at LoadBalancer or Ingress level
3. **Network Policies**: Implement network policies for service isolation
4. **RBAC**: Configure appropriate RBAC for service accounts

## 🛠️ Customization

### Database Configuration

Modify `01-postgres-config.yaml` to:
- Change database schema
- Add additional initialization scripts
- Configure database parameters

### Service Configuration

Modify individual service YAML files to:
- Change resource limits
- Add environment variables
- Configure health checks
- Adjust replica counts

### Gateway Configuration

Modify `06-nginx-gateway.yaml` to:
- Change rate limiting rules
- Add new API endpoints
- Configure CORS policies
- Add SSL/TLS settings

## 📝 Notes

- All services use init containers to wait for PostgreSQL availability
- Health checks are configured for all services
- CORS is enabled for cross-origin requests
- Rate limiting is applied to API endpoints
- Persistent storage is configured for PostgreSQL data
- Services use Kubernetes DNS for internal communication

## 🤝 Contributing

To contribute to this deployment configuration:

1. Test changes in a development cluster
2. Update documentation if needed
3. Ensure backward compatibility
4. Follow Kubernetes best practices
