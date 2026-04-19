#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# deploy-kubernetes.sh  (FIXED — SSL/TLS compliance resolved)
# Deploy fraud-detection stack to Minikube (local Kubernetes).
# Requires: Docker image already pushed to Docker Hub by Jenkins.
# ─────────────────────────────────────────────────────────────────
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[→]${NC} $1"; }

command -v kubectl  >/dev/null 2>&1 || err "kubectl not installed. Install: https://kubernetes.io/docs/tasks/tools/"
command -v minikube >/dev/null 2>&1 || err "minikube not installed. Install: https://minikube.sigs.k8s.io/docs/start/"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K8S_DIR="$PROJECT_ROOT/kubernetes"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║      FRAUD DETECTION — KUBERNETES DEPLOYMENT (FIXED)        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── FIX 1: Delete broken/stale Minikube cluster first ───────────
# This clears any SSL certificate mismatch from old cluster state
MINIKUBE_STATUS=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "Stopped")
if [ "$MINIKUBE_STATUS" = "Running" ]; then
  warn "Checking for SSL/certificate issues in existing cluster..."
  # Test if kubectl can actually communicate (SSL compliance check)
  if ! kubectl cluster-info >/dev/null 2>&1; then
    warn "SSL/API communication broken. Deleting and recreating cluster..."
    minikube delete
    MINIKUBE_STATUS="Stopped"
  else
    log "Existing Minikube cluster is healthy"
  fi
fi

# ── FIX 2: Start Minikube with correct SSL & driver options ──────
if [ "$MINIKUBE_STATUS" != "Running" ]; then
  info "Starting Minikube with SSL-safe configuration..."

  # Detect OS for correct driver
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    DRIVER="docker"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    DRIVER="docker"
  else
    DRIVER="docker"
  fi

  minikube start \
    --driver=$DRIVER \
    --cpus=2 \
    --memory=3072 \
    --embed-certs \
    --wait=all \
    --wait-timeout=3m

  log "Minikube started with embedded certs (SSL fixed)"
fi

# ── FIX 3: Regenerate kubeconfig to fix kubectl SSL errors ───────
info "Refreshing kubectl context and SSL certificates..."
minikube update-context
log "kubectl context updated"

# ── Verify kubectl can reach the API server ───────────────────────
info "Verifying kubectl SSL connection to API server..."
for i in $(seq 1 5); do
  if kubectl cluster-info >/dev/null 2>&1; then
    log "kubectl SSL connection verified — API server reachable"
    break
  fi
  warn "Attempt $i/5 — waiting for API server..."
  sleep 6
done
kubectl cluster-info || err "kubectl still cannot reach API server. Try: minikube delete && minikube start"

# ── Apply manifests ───────────────────────────────────────────────
info "Applying Kubernetes manifests..."
kubectl apply -f "$K8S_DIR/namespace.yml"
kubectl apply -f "$K8S_DIR/fraud-api-deployment.yml"
kubectl apply -f "$K8S_DIR/fraud-api-service.yml"
kubectl apply -f "$K8S_DIR/prometheus-deployment.yml"
kubectl apply -f "$K8S_DIR/prometheus-service.yml"
kubectl apply -f "$K8S_DIR/grafana-deployment.yml"
kubectl apply -f "$K8S_DIR/grafana-service.yml"
kubectl apply -f "$K8S_DIR/portainer-deployment.yml"
log "All manifests applied"

# ── Wait for pods ─────────────────────────────────────────────────
info "Waiting for fraud-api pod to be ready (up to 3 minutes)..."
kubectl rollout status deployment/fraud-api -n fraud-detection --timeout=180s
log "fraud-api deployment is ready"

# ── Get Minikube URLs ─────────────────────────────────────────────
MINIKUBE_IP=$(minikube ip)
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              KUBERNETES SERVICES LIVE                       ║"
echo "╠═══════════════════════════════════╦══════════════════════════╣"
echo "║  Service           NodePort       ║  Full URL                ║"
echo "╠═══════════════════════════════════╬══════════════════════════╣"
echo "║  🔍 Fraud API      30500          ║  http://$MINIKUBE_IP:30500  ║"
echo "║  📈 Prometheus     30909          ║  http://$MINIKUBE_IP:30909  ║"
echo "║  📊 Grafana        30300          ║  http://$MINIKUBE_IP:30300  ║"
echo "║  🐳 Portainer      30900          ║  http://$MINIKUBE_IP:30900  ║"
echo "╚═══════════════════════════════════╩══════════════════════════╝"
echo ""
echo "  Useful commands:"
echo "  kubectl get pods -n fraud-detection"
echo "  kubectl get services -n fraud-detection"
echo "  kubectl logs -f deployment/fraud-api -n fraud-detection"
echo ""
log "Kubernetes deployment complete!"
