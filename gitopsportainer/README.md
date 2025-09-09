# URL Shortener GitOps Deployment

This folder contains Kubernetes manifests for deploying the URL shortener application using both nginx-gateway and Kubernetes Ingress routing solutions.

## 🏗️ Architecture

The deployment consists of a modern microservices architecture with two routing options:

### Core Services
- **PostgreSQL Database**: StatefulSet with persistent storage and initialization scripts
- **Link Service**: Handles URL generation and management (PUT `/generate`, DELETE `/delete`)
- **Redirect Service**: Handles URL redirections and click tracking (GET `/redirect/{id}`)
- **Stats Service**: Provides analytics and statistics (GET `/stats`)
- **Frontend**: React-based web interface with nginx static file serving

### Routing Solutions
1. **nginx-gateway**: Custom API gateway with centralized routing
2. **Kubernetes Ingress**: Cloud-native routing with nginx-ingress-controller

## 📁 Files Structure

```
gitopsportainer/
├── 00-namespace.yaml           # Kubernetes namespace
├── 01-postgres-config.yaml     # Database initialization ConfigMap
├── 02-postgres.yaml           # PostgreSQL StatefulSet and Service
├── 03-link-service.yaml       # Link service Deployment and Service
├── 04-redirect-service.yaml   # Redirect service Deployment and Service
├── 05-stats-service.yaml      # Stats service Deployment and Service
├── 06-nginx-gateway.yaml      # [OPTIONAL] API gateway Deployment and Service
├── 07-frontend.yaml           # Frontend Deployment and Service
├── 08-loadbalancer.yaml       # [OPTIONAL] LoadBalancer services for nginx-gateway
├── 09-ingress-alternative.yaml # [MAIN] Kubernetes Ingress routing (4 ingresses)
├── 10-ingress-config.yaml     # Ingress controller global configuration
├── deploy.sh                  # Automated deployment script
├── kustomization.yaml         # Kustomize configuration
└── README.md                  # This documentation
```

## 🚀 Quick Deployment

### Prerequisites

1. **Kubernetes cluster** with LoadBalancer support (AKS, EKS, GKE, etc.)
2. **nginx-ingress-controller** installed:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
   ```

### Option 1: Full Deployment (Recommended)

```bash
# Deploy all services including both routing solutions
./deploy.sh

# Or manually:
kubectl apply -f .
```

### Option 2: Ingress-Only Deployment

```bash
# Deploy core services + Ingress only (modern approach)
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-postgres-config.yaml
kubectl apply -f 02-postgres.yaml
kubectl apply -f 03-link-service.yaml
kubectl apply -f 04-redirect-service.yaml
kubectl apply -f 05-stats-service.yaml
kubectl apply -f 07-frontend.yaml
kubectl apply -f 09-ingress-alternative.yaml
kubectl apply -f 10-ingress-config.yaml
```

## 🌐 Access URLs

### Primary Access (Ingress - Recommended)
```bash
# Get Ingress IP
kubectl get ingress -n url-shortener

# Access points:
# Frontend:     http://<INGRESS-IP>/
# API:          http://<INGRESS-IP>/api/generate
# Redirects:    http://<INGRESS-IP>/r/{id}
# Health:       http://<INGRESS-IP>/api/stats/health
```

### Secondary Access (LoadBalancer - Optional)
```bash
# Get LoadBalancer IPs
kubectl get svc -n url-shortener

# nginx-gateway:     http://<LB-IP>:80
# frontend-only:     http://<FRONTEND-LB-IP>:80
```

## 🔧 Ingress Configuration Details

### 09-ingress-alternative.yaml (4 Separate Ingresses)

1. **Health Ingress** (`url-shortener-health-ingress`)
   - **Path**: `/api/stats/health` → `/health` (stats-service)
   - **Purpose**: Health checks without path rewriting conflicts

2. **API Ingress** (`url-shortener-ingress`)
   - **Paths**: 
     - `/api/(generate)` → `/generate` (link-service)
     - `/api/(delete)` → `/delete` (link-service) 
     - `/api/(stats)` → `/stats` (stats-service)
   - **Features**: CORS, rate limiting (100 req/min), regex path rewriting

3. **Frontend Ingress** (`url-shortener-frontend-ingress`)
   - **Path**: `/` (prefix) → frontend service
   - **Purpose**: Static file serving (HTML, CSS, JS) without rewriting

4. **Redirect Ingress** (`url-shortener-redirect-ingress`)
   - **Path**: `/r/(.+)` → `/redirect/$1` (redirect-service)
   - **Features**: High throughput rate limiting (200 req/min)

### 10-ingress-config.yaml (Global Configuration)

```yaml
# nginx-ingress-controller ConfigMap settings:
allow-snippet-annotations: "true"     # Enable custom nginx snippets
http-snippet: |                       # Global rate limiting zones
  limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
  limit_req_zone $binary_remote_addr zone=redirect:10m rate=100r/s;
custom-http-errors: "404,503"          # Custom error pages
```

## 🧪 Testing and Usage

### Health Checks
```bash
# Check all services
kubectl get pods -n url-shortener

# Test Ingress health endpoint
curl http://<INGRESS-IP>/api/stats/health
# Expected: {"status":"healthy"}

# Test frontend
curl -I http://<INGRESS-IP>/
# Expected: 200 OK with text/html
```

### Create and Test Short URLs
```bash
# 1. Create a short URL
curl -X PUT http://<INGRESS-IP>/api/generate \
  -H 'Content-Type: application/json' \
  -d '{"long":"https://www.google.com"}'
# Expected: {"id":"abc123","original_url":"https://www.google.com","created_at":"..."}

# 2. Test redirect
curl -L http://<INGRESS-IP>/r/abc123
# Expected: Redirect to https://www.google.com

# 3. Get statistics
curl http://<INGRESS-IP>/api/stats
# Expected: JSON array of all URLs with click stats

# 4. Delete URL
curl -X DELETE http://<INGRESS-IP>/api/delete \
  -H 'Content-Type: application/json' \
  -d '{"id":"abc123"}'
```

### Frontend Web Interface
1. Open `http://<INGRESS-IP>/` in browser
2. Enter a long URL in the form
3. Click "Shorten" - you'll get full URLs like `http://<INGRESS-IP>/r/abc123`
4. View URL management and statistics in real-time

## 📊 Monitoring and Debugging

### View Logs
```bash
# Application services
kubectl logs -f deployment/link-service -n url-shortener
kubectl logs -f deployment/redirect-service -n url-shortener 
kubectl logs -f deployment/stats-service -n url-shortener
kubectl logs -f deployment/frontend -n url-shortener

# Database
kubectl logs -f statefulset/postgres -n url-shortener

# Ingress controller (for routing issues)
kubectl logs -f deployment/ingress-nginx-controller -n ingress-nginx
```

### Debug Ingress Issues
```bash
# Check ingress status
kubectl describe ingress -n url-shortener

# Check ingress controller configuration
kubectl get configmap ingress-nginx-controller -n ingress-nginx -o yaml

# Test specific paths
curl -v http://<INGRESS-IP>/api/generate  # Should work
curl -v http://<INGRESS-IP>/script.js     # Should return JS file
curl -v http://<INGRESS-IP>/r/test123     # Should return 404 or redirect
```

### Database Access
```bash
# Connect to PostgreSQL
kubectl exec -it postgres-0 -n url-shortener -- psql -U postgres urlshortener

# View tables
\dt

# Query URLs
SELECT * FROM links LIMIT 10;
SELECT * FROM stats LIMIT 10;
```

## 🔄 Updates and Maintenance

### Update Docker Images
```bash
# Update to new versions (using itsbaivab registry)
kubectl set image deployment/link-service link-service=itsbaivab/url-shortener-link:latest -n url-shortener
kubectl set image deployment/redirect-service redirect-service=itsbaivab/url-shortener-redirect:latest -n url-shortener  
kubectl set image deployment/stats-service stats-service=itsbaivab/url-shortener-stats:latest -n url-shortener
kubectl set image deployment/frontend frontend=itsbaivab/url-shortener-frontend:latest -n url-shortener

# Check rollout status
kubectl rollout status deployment/link-service -n url-shortener
```

### Scale Services
```bash
# Scale for high traffic
kubectl scale deployment/link-service --replicas=3 -n url-shortener
kubectl scale deployment/redirect-service --replicas=5 -n url-shortener  # Redirects get most traffic
kubectl scale deployment/stats-service --replicas=2 -n url-shortener
kubectl scale deployment/frontend --replicas=3 -n url-shortener
```

### Configuration Updates
```bash
# Update ingress configuration
kubectl apply -f 09-ingress-alternative.yaml

# Update ingress controller settings
kubectl apply -f 10-ingress-config.yaml

# Restart ingress controller to pick up config changes
kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx
```

## 🔒 Security Features

### Implemented Security
- **Rate Limiting**: API (100/min), Redirects (200/min) via Ingress annotations
- **CORS**: Configured for cross-origin requests
- **Input Validation**: URL length checks, SQL injection protection
- **Health Checks**: Kubernetes liveness/readiness probes
- **Network Isolation**: Services communicate via Kubernetes DNS

### Production Security Recommendations
```bash
# 1. Use Kubernetes Secrets for database credentials
kubectl create secret generic postgres-secret \
  --from-literal=username=postgres \
  --from-literal=password=secure-random-password \
  -n url-shortener

# 2. Enable TLS/HTTPS
# Add to ingress annotations:
# cert-manager.io/cluster-issuer: "letsencrypt-prod"
# nginx.ingress.kubernetes.io/ssl-redirect: "true"

# 3. Network Policies (example)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: url-shortener
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

## 🛠️ Customization Options

### Modify Rate Limiting
```yaml
# In 09-ingress-alternative.yaml, adjust:
nginx.ingress.kubernetes.io/rate-limit: "200"           # requests per minute
nginx.ingress.kubernetes.io/rate-limit-window: "1m"     # time window
```

### Add Custom Domains
```yaml
# In 09-ingress-alternative.yaml, add:
spec:
  rules:
  - host: short.yourdomain.com
    http:
      paths: [...]
```

### Database Configuration
```yaml
# Modify 01-postgres-config.yaml to add:
# - Additional database schemas
# - Custom initialization scripts  
# - Performance tuning parameters
```

### Frontend Customization
```bash
# Build custom frontend image:
cd frontend/
docker build -t yourusername/url-shortener-frontend:custom .
docker push yourusername/url-shortener-frontend:custom

# Update 07-frontend.yaml image reference
```

## 🗑️ Cleanup

### Remove Everything
```bash
# Quick cleanup
kubectl delete namespace url-shortener

# Remove ingress controller (if needed)
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```

### Selective Cleanup
```bash
# Remove only nginx-gateway setup (keep Ingress)
kubectl delete -f 06-nginx-gateway.yaml
kubectl delete -f 08-loadbalancer.yaml

# Remove only Ingress setup (keep nginx-gateway)  
kubectl delete -f 09-ingress-alternative.yaml
kubectl delete -f 10-ingress-config.yaml
```

## 📋 Troubleshooting Guide

### Common Issues

1. **Ingress shows no ADDRESS**
   ```bash
   # Check ingress controller
   kubectl get pods -n ingress-nginx
   # Install if missing: see Prerequisites section
   ```

2. **404 errors on API calls**
   ```bash
   # Check path rewriting in ingress logs
   kubectl logs -f deployment/ingress-nginx-controller -n ingress-nginx
   ```

3. **Static files (JS/CSS) not loading**
   ```bash
   # Verify frontend ingress has no rewrite rules
   kubectl describe ingress url-shortener-frontend-ingress -n url-shortener
   ```

4. **Database connection failures**
   ```bash
   # Check PostgreSQL readiness
   kubectl get pods -n url-shortener | grep postgres
   kubectl logs postgres-0 -n url-shortener
   ```

5. **CORS errors in browser**
   ```bash
   # Verify CORS headers in API responses
   curl -H "Origin: http://localhost" -v http://<INGRESS-IP>/api/stats
   ```

## 🎯 Performance Tuning

### High Traffic Configuration
```yaml
# Recommended for production:
# 1. Scale replicas based on traffic patterns
link-service: 2-3 replicas      # Medium load
redirect-service: 5-10 replicas # Highest load (redirects)
stats-service: 2-3 replicas     # Medium load  
frontend: 3-5 replicas          # Static files, can handle high load

# 2. Increase database resources
postgres:
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi" 
      cpu: "1000m"

# 3. Optimize ingress controller
# Add to 10-ingress-config.yaml:
worker-processes: "auto"
worker-connections: "65536"
keepalive-requests: "100"
```

## 📈 Metrics and Observability

### Built-in Metrics
```bash
# Service health endpoints
curl http://<INGRESS-IP>/api/stats/health

# Kubernetes metrics
kubectl top pods -n url-shortener
kubectl top nodes

# Database queries for analytics
kubectl exec -it postgres-0 -n url-shortener -- psql -U postgres urlshortener -c "
  SELECT COUNT(*) as total_links FROM links;
  SELECT COUNT(*) as total_clicks FROM stats;
"
```

### Integration with Monitoring Tools
```yaml
# Add Prometheus monitoring (example)
# ServiceMonitor for link-service:
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: link-service-metrics
  namespace: url-shortener
spec:
  selector:
    matchLabels:
      app: link-service
  endpoints:
  - port: http
    path: /metrics
```

## 🤝 Contributing

To contribute to this deployment:

1. **Test in development cluster first**
2. **Follow Kubernetes best practices**  
3. **Update this README for any changes**
4. **Ensure backward compatibility**
5. **Test both nginx-gateway and Ingress setups**

## 🏷️ Version History

- **v1.0**: Initial nginx-gateway setup
- **v2.0**: Added Kubernetes Ingress alternative
- **v2.1**: Improved documentation and cleanup scripts
- **v2.2**: Production security and performance recommendations

---

**🎉 Your URL shortener is now running with modern Kubernetes Ingress routing!**

**Primary Access**: `http://<INGRESS-IP>/`  
**API Endpoint**: `http://<INGRESS-IP>/api/generate`  
**Short URLs**: `http://<INGRESS-IP>/r/{id}`

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
