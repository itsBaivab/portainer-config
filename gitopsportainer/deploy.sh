#!/bin/bash

# URL Shortener GitOps Deployment Script
# This script automatically detects the Kubernetes cluster's external IP and deploys the URL shortener

set -e

NAMESPACE="url-shortener"
DEPLOYMENT_DIR="/home/baivab/repos/golang-url-shortener/k8s/gitopsportainer"

echo "🚀 Starting URL Shortener GitOps Deployment..."

# Function to detect cluster external IP
detect_cluster_ip() {
    echo "🔍 Detecting cluster external IP..."
    
    # Try to get external IP from LoadBalancer services
    EXTERNAL_IP=$(kubectl get svc -A -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].ip}' 2>/dev/null | head -1)
    
    # If no LoadBalancer IP, try NodePort with node IPs
    if [ -z "$EXTERNAL_IP" ]; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
        if [ -z "$NODE_IP" ]; then
            NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
        fi
        EXTERNAL_IP=$NODE_IP
    fi
    
    # Fallback to minikube ip if available
    if [ -z "$EXTERNAL_IP" ] && command -v minikube &> /dev/null; then
        EXTERNAL_IP=$(minikube ip 2>/dev/null || echo "")
    fi
    
    # Final fallback to localhost
    if [ -z "$EXTERNAL_IP" ]; then
        EXTERNAL_IP="localhost"
    fi
    
    echo "✅ Detected cluster IP: $EXTERNAL_IP"
    echo $EXTERNAL_IP
}

# Function to update frontend with dynamic URL
update_frontend_config() {
    local CLUSTER_IP=$1
    echo "🔧 Updating frontend configuration with cluster IP: $CLUSTER_IP"
    
    # Create a temporary script.js with the correct API endpoints
    cat > /tmp/script.js << EOF
// URL Shortener Frontend Application
// Auto-configured for cluster IP: $CLUSTER_IP

const API_BASE_URL = 'http://$CLUSTER_IP:30080'; // nginx-gateway NodePort
const FRONTEND_URL = 'http://$CLUSTER_IP:30081'; // frontend NodePort

const API_ENDPOINTS = {
    generate: \`\${API_BASE_URL}/api/generate\`,
    redirect: \`\${FRONTEND_URL}/r/\`, // Frontend proxy to gateway
    stats: \`\${API_BASE_URL}/api/stats\`,
    delete: \`\${API_BASE_URL}/api/delete\`
};

const elements = {
    urlInput: document.getElementById('urlInput'),
    customSlugInput: document.getElementById('customSlugInput'),
    shortenBtn: document.getElementById('shortenBtn'),
    result: document.getElementById('result'),
    shortUrl: document.getElementById('shortUrl'),
    copyBtn: document.getElementById('copyBtn'),
    copyMessage: document.getElementById('copyMessage'),
    totalUrls: document.getElementById('totalUrls'),
    totalClicks: document.getElementById('totalClicks'),
    todayClicks: document.getElementById('todayClicks'),
    mostPopular: document.getElementById('mostPopular')
};

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 URL Shortener initialized with cluster IP:', '$CLUSTER_IP');
    loadStats();
    setupEventListeners();
});

function setupEventListeners() {
    if (elements.shortenBtn) {
        elements.shortenBtn.addEventListener('click', shortenUrl);
    }
    
    if (elements.copyBtn) {
        elements.copyBtn.addEventListener('click', copyToClipboard);
    }
    
    if (elements.urlInput) {
        elements.urlInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                shortenUrl();
            }
        });
    }
}

async function shortenUrl() {
    const url = elements.urlInput?.value?.trim();
    const customSlug = elements.customSlugInput?.value?.trim();
    
    if (!url) {
        alert('Please enter a URL');
        return;
    }
    
    if (!isValidUrl(url)) {
        alert('Please enter a valid URL');
        return;
    }
    
    if (elements.shortenBtn) {
        elements.shortenBtn.disabled = true;
        elements.shortenBtn.textContent = 'Shortening...';
    }
    
    try {
        const requestBody = { url };
        if (customSlug) {
            requestBody.slug = customSlug;
        }
        
        const response = await fetch(API_ENDPOINTS.generate, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(requestBody)
        });
        
        const data = await response.json();
        
        if (response.ok) {
            const shortUrl = \`\${API_ENDPOINTS.redirect}\${data.slug}\`;
            if (elements.shortUrl) {
                elements.shortUrl.textContent = shortUrl;
                elements.shortUrl.href = shortUrl;
            }
            if (elements.result) {
                elements.result.style.display = 'block';
            }
            loadStats(); // Refresh stats
        } else {
            alert(data.error || 'Failed to shorten URL');
        }
    } catch (error) {
        console.error('Error:', error);
        alert('Failed to shorten URL. Please try again.');
    } finally {
        if (elements.shortenBtn) {
            elements.shortenBtn.disabled = false;
            elements.shortenBtn.textContent = 'Shorten URL';
        }
    }
}

function copyToClipboard() {
    const shortUrl = elements.shortUrl?.textContent;
    if (shortUrl) {
        navigator.clipboard.writeText(shortUrl).then(() => {
            if (elements.copyMessage) {
                elements.copyMessage.style.display = 'inline';
                setTimeout(() => {
                    elements.copyMessage.style.display = 'none';
                }, 2000);
            }
        });
    }
}

async function loadStats() {
    try {
        const response = await fetch(API_ENDPOINTS.stats);
        const stats = await response.json();
        
        if (response.ok) {
            if (elements.totalUrls) elements.totalUrls.textContent = stats.total_urls || 0;
            if (elements.totalClicks) elements.totalClicks.textContent = stats.total_clicks || 0;
            if (elements.todayClicks) elements.todayClicks.textContent = stats.today_clicks || 0;
            if (elements.mostPopular) elements.mostPopular.textContent = stats.most_popular || 'N/A';
        }
    } catch (error) {
        console.error('Failed to load stats:', error);
    }
}

function isValidUrl(string) {
    try {
        new URL(string);
        return true;
    } catch (_) {
        return false;
    }
}

// Auto-refresh stats every 30 seconds
setInterval(loadStats, 30000);
EOF
    
    # Update the frontend ConfigMap with the new script
    echo "📝 Creating ConfigMap with auto-configured frontend..."
}

# Function to wait for pods to be ready
wait_for_pods() {
    echo "⏳ Waiting for all application pods to be ready..."
    
    echo "  🔗 Waiting for Link Service..."
    kubectl wait --for=condition=ready pod -l app=link-service -n $NAMESPACE --timeout=120s
    
    echo "  ➡️  Waiting for Redirect Service..."
    kubectl wait --for=condition=ready pod -l app=redirect-service -n $NAMESPACE --timeout=120s
    
    echo "  📊 Waiting for Stats Service..."
    kubectl wait --for=condition=ready pod -l app=stats-service -n $NAMESPACE --timeout=120s
    
    echo "  🌐 Waiting for Nginx Gateway..."
    kubectl wait --for=condition=ready pod -l app=nginx-gateway -n $NAMESPACE --timeout=120s
    
    echo "  🎨 Waiting for Frontend..."
    kubectl wait --for=condition=ready pod -l app=frontend -n $NAMESPACE --timeout=120s
    
    echo "✅ All pods are ready!"
}

# Function to display access information
display_access_info() {
    local CLUSTER_IP=$1
    echo ""
    echo "🎉 Deployment completed successfully!"
    echo ""
    echo "📋 Access Information:"
    echo "🌐 Frontend URL: http://$CLUSTER_IP:30081"
    echo "🔗 API Gateway: http://$CLUSTER_IP:30080"
    echo "📊 Short URL format: http://$CLUSTER_IP:30081/r/{slug}"
    echo ""
    echo "🔍 Useful Commands:"
    echo "kubectl get pods -n $NAMESPACE"
    echo "kubectl get svc -n $NAMESPACE"
    echo "kubectl logs -f deployment/frontend -n $NAMESPACE"
    echo "kubectl describe svc url-shortener-loadbalancer -n $NAMESPACE"
    echo ""
    echo "🧪 Test the API:"
    echo "curl -X POST http://$CLUSTER_IP:30080/api/generate \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"url\":\"https://www.google.com\"}'"
    echo ""
}

# Main deployment flow
main() {
    echo "🏗️  Applying Kubernetes manifests..."
    
    # Apply manifests one by one in order
    echo "📦 Creating namespace..."
    kubectl apply -f $DEPLOYMENT_DIR/00-namespace.yaml
    
    echo "🗄️  Setting up database configuration..."
    kubectl apply -f $DEPLOYMENT_DIR/01-postgres-config.yaml
    
    echo "🐘 Deploying PostgreSQL..."
    kubectl apply -f $DEPLOYMENT_DIR/02-postgres.yaml
    
    echo "⏳ Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=120s
    
    echo "🔗 Deploying Link Service..."
    kubectl apply -f $DEPLOYMENT_DIR/03-link-service.yaml
    
    echo "➡️  Deploying Redirect Service..."
    kubectl apply -f $DEPLOYMENT_DIR/04-redirect-service.yaml
    
    echo "📊 Deploying Stats Service..."
    kubectl apply -f $DEPLOYMENT_DIR/05-stats-service.yaml
    
    echo "🌐 Deploying Nginx Gateway..."
    kubectl apply -f $DEPLOYMENT_DIR/06-nginx-gateway.yaml
    
    echo "🎨 Deploying Frontend..."
    kubectl apply -f $DEPLOYMENT_DIR/07-frontend.yaml
    
    echo "⚖️  Creating LoadBalancer services..."
    kubectl apply -f $DEPLOYMENT_DIR/08-loadbalancer.yaml
    
    # Wait for deployment
    echo "⏳ Waiting for all services to be deployed..."
    sleep 15
    
    # Detect cluster IP
    CLUSTER_IP=$(detect_cluster_ip)
    
    # Update frontend configuration
    update_frontend_config $CLUSTER_IP
    
    # Wait for pods to be ready
    wait_for_pods
    
    # Display access information
    display_access_info $CLUSTER_IP
    
    echo "🚀 URL Shortener is now running on Kubernetes!"
}

# Run the deployment
main
