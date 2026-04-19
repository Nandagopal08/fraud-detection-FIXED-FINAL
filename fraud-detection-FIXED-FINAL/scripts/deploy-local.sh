#!/bin/bash
# deploy-local.sh — WINDOWS/WSL2 FINAL FIXED VERSION
# Fixes: cAdvisor WSL2 volume mounts, Jenkins password wait, docker binary path
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[→]${NC} $1"; }

if ! command -v docker >/dev/null 2>&1 && command -v docker.exe >/dev/null 2>&1; then
  warn "WSL detected — using docker.exe from Windows host"
  alias docker='docker.exe'
  alias docker-compose='docker-compose.exe'
fi

if ! docker info >/dev/null 2>&1; then
  err "Docker not reachable. Make sure Docker Desktop is running and WSL Integration is enabled."
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  err "No docker compose found. Install Docker Desktop."
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -f "creditcard.csv" ]; then
  err "creditcard.csv not found!\nDownload from: https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud\nPlace it in: $PROJECT_ROOT/"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║      FRAUD DETECTION — LOCAL DEPLOYMENT (Windows Fixed)     ║"
echo "║  Docker + Prometheus + Grafana + Portainer + cAdvisor        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Pre-clean: remove any conflicting containers ──────────────────
info "Pre-clean — removing any leftover containers..."
for c in fraud-api prometheus grafana portainer cadvisor jenkins; do
  docker rm -f "$c" 2>/dev/null && echo "  Removed old: $c" || true
done
log "Pre-clean done"

# ── Step 1: Build ─────────────────────────────────────────────────
info "Step 1/5 — Building Docker image (trains ML model inside)..."
docker build -t ameyab16/fraud-api:latest . 2>&1 | tail -8
log "Image built: ameyab16/fraud-api:latest"

# ── Step 2: Network ───────────────────────────────────────────────
info "Step 2/5 — Creating Docker network..."
docker network create monitoring 2>/dev/null || warn "Network 'monitoring' already exists"

# ── Step 3: Main stack ────────────────────────────────────────────
info "Step 3/5 — Starting Fraud API + Prometheus + Grafana + Portainer + cAdvisor..."
$COMPOSE up -d
log "Main stack started"

# ── Step 4: Jenkins ───────────────────────────────────────────────
info "Step 4/5 — Starting Jenkins..."
$COMPOSE -f jenkins/docker-compose.jenkins.yml up -d
log "Jenkins container started"

# ── Step 5: Wait for Fraud API health ────────────────────────────
info "Step 5/5 — Waiting for Fraud API to become healthy (~60-90s)..."
for i in $(seq 1 20); do
  STATUS=$(curl -sf http://localhost:5000/health 2>/dev/null | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
  if [ "$STATUS" = "healthy" ]; then
    log "Fraud API is healthy!"
    break
  fi
  echo "  Attempt $i/20 — waiting 10s..."
  sleep 10
done
[ "$STATUS" != "healthy" ] && warn "API still starting — check: docker logs fraud-api"

# ── Wait for Jenkins password (longer wait for WSL2) ─────────────
info "Waiting for Jenkins initialAdminPassword (up to 2 minutes for WSL2)..."
JENKINS_PASS=""
for i in $(seq 1 24); do
  JENKINS_PASS=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "")
  if [ -n "$JENKINS_PASS" ]; then
    log "Jenkins password ready!"
    break
  fi
  echo "  Jenkins initializing... ($i/24, ~$((i*5))s elapsed)"
  sleep 5
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   ALL SERVICES ARE LIVE                     ║"
echo "╠══════════════════════════════════╦═══════════════════════════╣"
echo "║  Fraud Detection Dashboard       ║  http://localhost:5000    ║"
echo "║  Prometheus Metrics              ║  http://localhost:9090    ║"
echo "║  Grafana  (admin/admin)          ║  http://localhost:3000    ║"
echo "║  Portainer Docker UI             ║  http://localhost:9000    ║"
echo "║  Jenkins CI/CD                   ║  http://localhost:8080    ║"
echo "║  cAdvisor Container Stats        ║  http://localhost:8088    ║"
echo "╚══════════════════════════════════╩═══════════════════════════╝"
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  🔑 JENKINS INITIAL ADMIN PASSWORD:"
echo ""
if [ -n "$JENKINS_PASS" ]; then
  echo "     $JENKINS_PASS"
  echo ""
  echo "  → Open http://localhost:8080 and paste the above password"
else
  echo "  Jenkins is still initializing. Run this after ~1 more minute:"
  echo ""
  echo "     docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
  echo ""
  echo "  → Then open http://localhost:8080 and paste it"
fi
echo "══════════════════════════════════════════════════════════════"
echo ""
log "Deployment complete!"
