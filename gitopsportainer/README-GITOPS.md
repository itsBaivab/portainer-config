# GitOps Portainer Deployment

This directory contains Kubernetes manifests for deploying the URL Shortener application using GitOps with Portainer.

## Files Overview

### Infrastructure Components
- `00-ingress-nginx-controller.yaml` - NGINX Ingress Controller installation
- `00-namespace.yaml` - Creates the url-shortener namespace
- `00-secrets.yaml` - Database and application secrets

### Database
- `01-postgres-config.yaml` - PostgreSQL initialization script
- `02-postgres.yaml` - PostgreSQL StatefulSet and Service

### Application Services
- `03-link-service.yaml` - Link generation service
- `04-redirect-service.yaml` - URL redirection service  
- `05-stats-service.yaml` - Analytics and statistics service
- `07-frontend.yaml` - Frontend web application

### Networking
- `simple-ingress.yaml` - Ingress configuration for external access
- `08-ingress.yaml` - Advanced ingress with custom routing (alternative)

### Deployment Scripts
- `install-ingress-controller.sh` - Installs NGINX Ingress Controller
- `deploy.sh` - Main deployment script
- `kustomization.yaml` - Kustomize configuration

## Quick Start

### Option 1: Automatic Deployment (Recommended)
```bash
# Run the main deploy script - it will automatically install ingress controller if needed
./deploy.sh
```

### Option 2: Manual Step-by-Step
```bash
# 1. Install ingress controller first
./install-ingress-controller.sh

# 2. Deploy the application
./deploy.sh
```

### Option 3: Using Kustomize
```bash
# Deploy everything with kustomize
kubectl apply -k .
```

## Access Your Application

After deployment, you can access the application via:

### 1. Ingress (Recommended)
```bash
# Get the ingress controller external IP
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Access your application
curl http://<EXTERNAL-IP>/
```

### 2. LoadBalancer Services
```bash
# List available LoadBalancer services
kubectl get svc -n url-shortener | grep LoadBalancer

# Access via LoadBalancer IPs
# Frontend: http://<FRONTEND-LB-IP>:3000
# API Gateway: http://<GATEWAY-LB-IP>:80
```

### 3. Port Forward (Development)
```bash
# Forward frontend to local port
kubectl port-forward svc/frontend 8080:80 -n url-shortener

# Access at http://localhost:8080
```

## Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n url-shortener

# Check services
kubectl get svc -n url-shortener

# Check ingress
kubectl get ingress -n url-shortener

# View logs
kubectl logs -l app=link-service -n url-shortener
```

## Monitoring and Troubleshooting

### Common Commands
```bash
# Check pod status
kubectl describe pods -n url-shortener

# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check database connection
kubectl exec -it postgres-0 -n url-shortener -- psql -U postgres -d urlshortener -c "\dt"
```

### Cleanup
```bash
# Remove application
kubectl delete namespace url-shortener

# Remove ingress controller (optional)
kubectl delete namespace ingress-nginx
```

## Architecture

```
Internet
    ↓
NGINX Ingress Controller (LoadBalancer)
    ↓
Frontend (nginx) → Serves UI + Proxies API calls
    ↓
┌─────────────────────────────────────┐
│  Microservices                      │
│  ├─ Link Service (8001)            │
│  ├─ Redirect Service (8002)        │
│  └─ Stats Service (8003)           │
└─────────────────────────────────────┘
    ↓
PostgreSQL Database (StatefulSet)
```

## Configuration

### Environment Variables
- Database credentials are stored in `00-secrets.yaml`
- Application configuration is in individual service manifests
- Frontend configuration is in `07-frontend.yaml`

### Scaling
```bash
# Scale services
kubectl scale deployment link-service --replicas=5 -n url-shortener
kubectl scale deployment redirect-service --replicas=3 -n url-shortener
kubectl scale deployment stats-service --replicas=2 -n url-shortener
```

### Updates
```bash
# Update image versions in manifests and reapply
kubectl apply -k .

# Rolling restart
kubectl rollout restart deployment/link-service -n url-shortener
```

This setup provides a complete, production-ready deployment with ingress, load balancing, and proper service discovery for your URL shortener application.
